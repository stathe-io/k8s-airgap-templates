#!/bin/sh
# The connected side: everything the enclave will need, fetched once and
# checked against the publisher's checksum before it goes anywhere.
set -eu
. "$(dirname "$0")/../versions.env"

out="$(dirname "$0")/../bundle"
mkdir -p "$out"
cd "$out"

release="https://github.com/k3s-io/k3s/releases/download/$(echo "$K3S_VERSION" | sed 's/+/%2B/')"
curl -sfLO "$release/$K3S_AIRGAP"
curl -sfL "$release/sha256sum-$ARCH.txt" -o k3s-sha256sum.txt

# sha256sum on Linux; shasum where coreutils is not installed, as on macOS.
if command -v sha256sum >/dev/null; then sum="sha256sum"; else sum="shasum -a 256"; fi

# Refuse the bundle rather than carry an unverified file across the gap.
grep " $K3S_AIRGAP\$" k3s-sha256sum.txt | $sum -c -

# The tools that run inside the enclave travel in the bundle too, so the
# enclave side never pulls anything.
for tool in "$REGISTRY_IMAGE" "$CRANE_IMAGE"; do
  docker pull -q "$tool" >/dev/null
done
docker save "$REGISTRY_IMAGE" "$CRANE_IMAGE" -o tools.tar

# Each image as an OCI layout holding the whole index, so the digest in
# images.txt is the digest the enclave registry serves.
here=$(pwd)
mkdir -p images
grep -v '^#' "$here/../images.txt" | while read -r ref; do
  [ -n "$ref" ] || continue
  dir=$(echo "$ref" | sed -E 's#[@:].*##; s#[/.]#_#g')
  rm -rf "images/$dir"
  docker run --rm -v "$here/images:/out" "$CRANE_IMAGE" \
    pull --format=oci --platform=all "$ref" "/out/$dir"
  echo "$ref" > "images/$dir/ref"
  echo "bundled $ref"
done
