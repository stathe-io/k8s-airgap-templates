# Transfer

Everything the enclave runs crosses the gap in a bundle. The bundle is the
whole interface between the two sides, so it has to prove two things at the
gate. It came from the transfer station. Nothing in it changed or was added on
the way.

## What a bundle holds

| Item | Checked on the connected side against |
|---|---|
| Container images, as OCI layouts holding the whole index | The digest in the request list |
| The distribution's airgap artifacts (RKE2 images, binary, install script) | The publisher's `sha256sum-<arch>.txt` |
| The vulnerability database | Nothing it can be checked against. It is dated. The gate holds it to a maximum age |
| Helm charts, OpenTofu providers, tool binaries | The publisher's checksum or signature where one exists. A pinned hash where none does |
| `MANIFEST.sha256` | Written last: the hash of every file above |
| `MANIFEST.sha256.sigstore.json` | The signature over the manifest, with the transfer key |

The request list lives in Git. Adding an image is a reviewed change, which
answers the auditor's question of who asked for it and who approved it.

## Sealing and opening

[`templates/transfer/seal.sh`](../templates/transfer/seal.sh) writes the
manifest and signs it on the connected side.
[`templates/transfer/open.sh`](../templates/transfer/open.sh) runs at the gate
and refuses the whole bundle when:

- the manifest signature does not verify against the transfer key
- any file does not match its hash
- any file is present that the manifest does not list

Nothing from the bundle is used before `open.sh` passes. Refusing the whole
bundle rather than the files that failed is deliberate. A bundle with one
altered file is a bundle someone tampered with.

Both scripts were tested on five cases. A valid bundle opens. An altered file,
an added file, a manifest edited after sealing and a signature from another
key are each refused.

## Two keys

The transfer key signs bundles on the connected side. The gate key signs images
inside the enclave after they pass the scan. They are different keys held by
different people. A stolen transfer key gets a bundle to the gate, where the
images are still scanned. A stolen gate key lets an image skip the scan, but it
never leaves the enclave.

Both belong in an HSM or a KMS. The public half of the transfer key is
installed at the gate once, through the same reviewed process as any other
change to the enclave.

## Cadence

The enclave's knowledge of vulnerabilities is as old as its last transfer. A
fixed cadence, weekly in most cases, keeps that bounded. The gate makes it
binding by refusing a database past its maximum age. Without that check a
missed transfer goes unnoticed while every scan keeps passing.

A critical vulnerability in something that runs inside needs an extra transfer
outside the cadence. That path should exist and be rehearsed before it is
needed.

## The record

Each transfer leaves a line in a log kept inside the enclave. The date, the
manifest hash, who sealed it, who opened it and which images the gate refused.
That log and the scan reports are what an auditor asks for.
