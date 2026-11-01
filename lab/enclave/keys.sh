#!/bin/sh
# Creates the import gate's key pair once. An empty password keeps the lab
# unattended; a real gate keeps this key in an HSM or a KMS.
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../versions.env"
keys="$here/../keys"
[ -f "$keys/cosign.key" ] && exit 0
mkdir -p "$keys"
docker run --rm -e COSIGN_PASSWORD= -v "$keys:/k" -w /k "$COSIGN_IMAGE" generate-key-pair >/dev/null
echo "created keys/cosign.key and keys/cosign.pub"
