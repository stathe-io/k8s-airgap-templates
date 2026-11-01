# Transfer

Everything the enclave needs crosses the gap in a bundle: a folder of files.
Before it leaves, you seal it: a list of every file with its SHA-256 hash
(`MANIFEST.sha256`), signed with the transfer key. At the gate you open it: the
signature must verify, every hash must match and no file may be extra. If any
of those fails, the whole bundle is refused. Nothing in it is used.

Tested on five cases. A valid bundle opens. An altered file, an added file, an
edited manifest and a signature from another key are each refused.

## What you need

- cosign v3 on the connected side and at the gate. At the gate it comes in
  with an earlier bundle.
- `sha256sum` (part of Linux) and `bash`.
- A transfer key pair, made once (below).

## Once: make the transfer key

```sh
cosign generate-key-pair
```

This writes `cosign.key` (private, with a password you choose) and
`cosign.pub`. Rename them to `transfer.key` and `transfer.pub`.

- `transfer.key` stays on the connected side, with the person who seals.
- `transfer.pub` goes to the gate, once, through your normal change process.

Make a file `signing-config.json` next to the key, with this one line. It tells
cosign not to use a transparency log, which neither side can reach:

```json
{"mediaType":"application/vnd.dev.sigstore.signingconfig.v0.2+json","rekorTlogConfig":{},"tsaConfig":{}}
```

## Every transfer: seal, on the connected side

Put everything for this transfer in one folder, `bundle/`. Then:

```sh
cd bundle
find . -type f ! -name 'MANIFEST.sha256*' | LC_ALL=C sort | xargs sha256sum > MANIFEST.sha256
cosign sign-blob --key ../transfer.key --signing-config ../signing-config.json \
  --bundle MANIFEST.sha256.sigstore.json --yes MANIFEST.sha256
```

> Check: `MANIFEST.sha256` has one line per file. `MANIFEST.sha256.sigstore.json`
> exists. Do not change anything in the folder after this.

## Every transfer: open, at the gate

Run these three in bash, in the bundle folder. Each must pass before you use
anything from the bundle.

```bash
cosign verify-blob --key ../transfer.pub --insecure-ignore-tlog \
  --bundle MANIFEST.sha256.sigstore.json MANIFEST.sha256
```

> Check: `Verified OK`.

```bash
sha256sum -c --quiet MANIFEST.sha256
```

> Check: prints nothing.

```bash
find . -type f ! -name 'MANIFEST.sha256*' | LC_ALL=C sort |
  diff - <(awk '{print $2}' MANIFEST.sha256 | LC_ALL=C sort)
```

> Check: prints nothing.

## When something fails

Any failure means: do not use the bundle. Tell whoever sealed it and get a new
one.

| What you see | What it means |
|---|---|
| `invalid signature when validating ASN.1 encoded signature` | The manifest was changed after sealing, or it was signed with another key |
| `./a.txt: FAILED` and `computed checksum did NOT match` | That file changed on the way |
| `< ./images/extra.tar` from the third command | That file is in the bundle but not in the manifest. Someone added it |
| `FAILED open or read` from the second command, `> ./images/b.tar` from the third | That file is in the manifest but missing from the bundle |

## Keys

Two keys, kept apart. The transfer key signs bundles. The gate key signs images
after they pass the scan (see [admission](../admission)). Different people hold
them, ideally in an HSM or a KMS.
