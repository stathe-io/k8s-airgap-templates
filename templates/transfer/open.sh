#!/bin/sh
# Opens a bundle at the import gate. Refuses the whole bundle unless the
# manifest carries a valid signature from the transfer key, every file matches
# its hash and no file is present that the manifest does not list.
#
#   open.sh <bundle-dir> <transfer.pub>
#
# Exits non-zero on any failure. Nothing from the bundle should be used before
# this passes.
set -eu

bundle=$(cd "$1" && pwd)
pub=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
cosign=${COSIGN_IMAGE:-ghcr.io/sigstore/cosign/cosign:v3.1.4@sha256:0f06154836d2de34f887a5c273506d52ca43edaa1d9e53e6510fa78a48f69c2d}

if command -v sha256sum >/dev/null; then sum="sha256sum"; else sum="shasum -a 256"; fi

docker run --rm -v "$bundle:/b:ro" -v "$pub:/transfer.pub:ro" "$cosign" \
  verify-blob --key /transfer.pub --insecure-ignore-tlog \
  --bundle /b/MANIFEST.sha256.sigstore.json /b/MANIFEST.sha256 >/dev/null 2>&1 ||
  { echo "refused: the manifest signature does not verify" >&2; exit 1; }

cd "$bundle"
$sum -c --quiet MANIFEST.sha256 ||
  { echo "refused: a file does not match the manifest" >&2; exit 1; }

# A file the manifest does not list did not come from the transfer station.
listed=$(mktemp)
sed -E 's/^[0-9a-f]+ [ *]?//' MANIFEST.sha256 | LC_ALL=C sort > "$listed"
extra=$(find . -type f ! -name 'MANIFEST.sha256*' | sed 's#^\./##' | LC_ALL=C sort | comm -23 - "$listed")
rm -f "$listed"
if [ -n "$extra" ]; then
  echo "refused: files not in the manifest:" >&2
  echo "$extra" >&2
  exit 1
fi

echo "opened $(wc -l < MANIFEST.sha256 | tr -d ' ') files"
