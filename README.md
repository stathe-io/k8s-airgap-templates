# secure-lab

How to build a Kubernetes platform with no route out and get software into it
in a way you can prove. A guide, templates for real clusters and a lab that
runs the patterns end to end.

## The guide

| | |
|---|---|
| [Architecture](docs/architecture.md) | The three zones, the import gate and where each component sits |
| [Transfer](docs/transfer.md) | What crosses the gap, how a bundle is sealed and opened, the two keys and the cadence |

## Templates

| | |
|---|---|
| [templates/transfer](templates/transfer) | `seal.sh` signs a manifest over every file in a bundle. `open.sh` refuses the whole bundle on any mismatch |
| [templates/rke2](templates/rke2) | RKE2 with the CIS profile, the enclave registry as the only source and a default route to nowhere |

Each template says how far it was tested. Some ran in the lab, some in a
container, some only against the documentation.

## The lab

[lab/](lab) builds the patterns on one machine with k3d and proves each claim
with a check. A cluster on a network with no route out, a registry filled only
from the bundle and an import gate that scans and signs. Admission runs only
what the gate signed.

```console
$ cd lab && make bundle up verify
...
PASS  the node cannot reach the internet
...
PASS  an image outside the bundle is not pulled
...
PASS  an unsigned image is refused at admission
...
PASS  the gate refused an image with fixable critical vulnerabilities
...
```

The lab is a proving ground. The guide and the templates are what you would
build a real enclave from.
