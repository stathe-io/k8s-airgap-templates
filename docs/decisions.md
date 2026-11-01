# Decisions

Short records of choices that are not obvious from the code, with what they
cost.

## The enclave is an internal Docker network with a dead-end route

An `--internal` network gives containers no route out, which is the property
the lab is about. k3s will not start without a default route, so each node gets
one to the network's gateway, where Docker drops the traffic.

Cost: the API port cannot be published to the host. Commands reach the cluster
through the server node, as an operator inside the enclave would.

## Images cross as OCI layouts holding the whole index

`images.txt` pins each image by its index digest. The bundle carries the whole
index with every platform in it, so the digest in the list is the digest the
enclave registry serves and a pod can use the original reference.

Cost: size. The nginx example is 155 MB as a full index against 20 MB
for linux/amd64 alone. Copying a single platform would change the digest and break
the pin.

## Kubernetes v1.35, not the newest k3s

The k3s stable channel is on v1.36. Kyverno v1.19 is tested up to Kubernetes
v1.35. Admission control is the part of this lab that has to be right, so the
cluster stays inside that range. v1.35 still receives patches.

Cost: one minor version behind stable. Revisit when Kyverno's tested range
includes v1.36.

## The import gate signs, inside the enclave

Images are signed when they are loaded into the enclave registry, with a key
that stays on the host running the gate. The signature says the image came in
through the gate. Signing on the connected side would need a registry there to
sign against.

Cost: the gate's private key is the root of trust. The lab keeps it in
`keys/` with an empty password so it runs unattended. A real gate keeps it in
an HSM or a KMS.

## Workloads name the enclave registry

A pod names `registry:5000/...`, not the image's original registry. The node
would pull either way through the k3s mirror, but admission fetches the
signature from the registry the pod names. Kyverno does not use the node's
mirror. Rewriting references to the internal registry is also what an
air-gapped platform does at import.

Cost: manifests from upstream need their image references rewritten, as
`enclave/up.sh` does for Kyverno's own manifest.

## Cosign's classic signature format

cosign v3 writes its newer bundle format by default. Kyverno v1.19 found no
signature in that format in this registry (distribution 2.8, which has no OCI
1.1 referrers API), with `ClusterPolicy` and with `ImageValidatingPolicy`. The
gate signs with `--new-bundle-format=false`, which Kyverno reads.

Cost: the classic format is the older path. Revisit with a registry that
serves the referrers API.

## ImageValidatingPolicy, not ClusterPolicy

Kyverno v1.19 marks `kyverno.io/v1` `ClusterPolicy` deprecated in favour of the
CEL-based policy types. The lab uses `ImageValidatingPolicy`.

## Kyverno's manifest is pinned by our own hash

The Kyverno release publishes no checksum for `install.yaml`. `versions.env`
holds the hash of the copy first fetched. The fetch stops if it changes.
That is trust on first use, which is weaker than a published checksum and is
stated here for that reason.
