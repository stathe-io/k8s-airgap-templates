# The lab

A Kubernetes cluster with no way out, built from a bundle that was checked
before it crossed the gap. Every claim the lab makes has a check in
`verify/verify.sh`.

```sh
make bundle   # connected side: fetch and verify what the enclave needs
make up       # enclave: network, registry, import gate, k3s, admission
make verify   # prove it
make down
```

```console
$ make verify
PASS  the cluster node is Ready
PASS  the network has no route out
PASS  the node cannot reach the internet
PASS  a pod from the bundle runs
PASS  a pod cannot reach the internet
PASS  an image outside the bundle is not pulled
PASS  the enclave registry holds exactly the bundle
PASS  a bundled image runs, pulled through the enclave registry
PASS  an unsigned image is refused at admission
PASS  an unsigned init container is refused at admission
PASS  the bundled vulnerability database is accepted
PASS  a database past its maximum age is refused
PASS  the gate refused an image with fixable critical vulnerabilities
PASS  every image has a scan report that matches its admission
```

Runs on a Linux host (amd64 or arm64) with Docker, k3d and kubectl. macOS with
Docker Desktop works too. Versions are pinned in `versions.env`.

## How it works

The enclave is a Docker network created with `--internal`, so nothing on it has
a route to the internet. k3s refuses to start without a default route, so
`enclave/k3d-entrypoint-route.sh` adds one to the network's gateway, where
Docker drops the traffic.

The node starts from the k3s airgap image tarball. `connected/fetch.sh`
downloads it and checks it against the checksum k3s publishes. If it does not
match the script stops.

Images the enclave may run are listed in `images.txt`, pinned by digest. The
connected side saves each one as an OCI layout holding the whole index, so the
digest in the list is the digest the enclave serves. The registry and the tool
that loads it travel in the bundle as well. Inside, k3s mirrors every registry
to the one in the enclave and has nowhere else to go.

Loading an image into the enclave registry is the import gate. The gate scans
each image offline with the vulnerability database from the bundle. It refuses
to scan at all when that database is more than a week old. An image with a
fixable critical vulnerability is loaded but not signed. Every other image is
signed by digest with a key that never leaves the host. Kyverno admits only
images with that signature. The scan reports stay in `evidence/`. The registry also holds one image the gate did
not sign, so the refusal can be shown.

The API port is not published to the host. An internal network cannot publish
one. In a real enclave the operator works from inside it anyway.

Why it is built this way and what each choice costs is in
[DECISIONS.md](DECISIONS.md).

## Not yet

Example pipelines from `ci-baseline` running inside the
enclave. A workstation inside the enclave that runs stathe.
