#!/bin/sh
# Seals a bundle on the connected side. Writes a manifest with the SHA-256 of
# every file in the bundle and signs the manifest with the transfer key, in a
# Sigstore bundle next to it. There is no transparency log on either side of
# the gap, so the signing config names none.
#
#   seal.sh <bundle-dir> <transfer.key>
#
# COSIGN_PASSWORD holds the key's password. Needs Docker for the pinned cosign
# image, so the transfer station needs no cosign install of its own.
set -eu

bundle=$(cd "$1" && pwd)
key=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
cosign=${COSIGN_IMAGE:-ghcr.io/sigstore/cosign/cosign:v3.1.4@sha256:0f06154836d2de34f887a5c273506d52ca43edaa1d9e53e6510fa78a48f69c2d}

if command -v sha256sum >/dev/null; then sum="sha256sum"; else sum="shasum -a 256"; fi

# Every file except the manifest and its signature, in a stable order, so the
# same bundle always produces the same manifest.
cd "$bundle"
rm -f MANIFEST.sha256 MANIFEST.sha256.sigstore.json
find . -type f ! -name 'MANIFEST.sha256*' | LC_ALL=C sort | sed 's#^\./##' |
  while read -r f; do $sum "$f"; done > MANIFEST.sha256

config=$(mktemp)
echo '{"mediaType":"application/vnd.dev.sigstore.signingconfig.v0.2+json","rekorTlogConfig":{},"tsaConfig":{}}' > "$config"
docker run --rm -e COSIGN_PASSWORD -v "$bundle:/b" -v "$key:/transfer.key:ro" \
  -v "$config:/signing-config.json:ro" "$cosign" \
  sign-blob --key /transfer.key --signing-config /signing-config.json \
  --bundle /b/MANIFEST.sha256.sigstore.json --yes /b/MANIFEST.sha256 >/dev/null 2>&1
rm -f "$config"

echo "sealed $(wc -l < MANIFEST.sha256 | tr -d ' ') files"
