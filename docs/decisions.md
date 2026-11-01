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
