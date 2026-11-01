# Transfer

A bundle crosses the gap with a manifest of SHA-256 hashes, signed with the
transfer key. The gate refuses the whole bundle on any mismatch.

Replace `transfer.key`, `transfer.pub` and `bundle/`. Tested on five cases: a
valid bundle opens, an altered file, an added file, an edited manifest and a
signature from another key are refused.

## Seal, on the connected side

```sh
cd bundle
find . -type f ! -name 'MANIFEST.sha256*' | LC_ALL=C sort | xargs sha256sum > MANIFEST.sha256
cosign sign-blob --key ../transfer.key --signing-config ../signing-config.json \
  --bundle MANIFEST.sha256.sigstore.json --yes MANIFEST.sha256
```

`signing-config.json` names no transparency log, which neither side can reach:

```json
{"mediaType":"application/vnd.dev.sigstore.signingconfig.v0.2+json","rekorTlogConfig":{},"tsaConfig":{}}
```

## Open, at the gate

All three must pass before anything in the bundle is used. Run in bash.

```bash
cd bundle
cosign verify-blob --key ../transfer.pub --insecure-ignore-tlog \
  --bundle MANIFEST.sha256.sigstore.json MANIFEST.sha256
sha256sum -c --quiet MANIFEST.sha256
find . -type f ! -name 'MANIFEST.sha256*' | LC_ALL=C sort |
  diff - <(awk '{print $2}' MANIFEST.sha256 | LC_ALL=C sort)
```

The last line prints nothing when the bundle holds exactly what the manifest
lists.

## Keys

The transfer key signs bundles. The gate key signs images after the scan. Keep
them apart, with different holders, in an HSM or a KMS.
