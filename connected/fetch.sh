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
curl -sfL "$release/sha256sum-arm64.txt" -o k3s-sha256sum.txt

# Refuse the bundle rather than carry an unverified file across the gap.
grep " $K3S_AIRGAP\$" k3s-sha256sum.txt | shasum -a 256 -c -
