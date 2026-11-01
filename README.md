# k8s-airgap-templates

Templates for an air-gapped Kubernetes platform. Each one says where it goes,
what to replace and how far it was tested.

| Template | |
|---|---|
| [transfer](templates/transfer) | Seal a bundle on the connected side, open it at the gate |
| [rke2](templates/rke2) | RKE2 with the CIS profile and SELinux, step by step. Tested on AlmaLinux 9 without a route out |
| [harbor](templates/harbor) | Harbor as the enclave registry, with an offline scanner |
| [admission](templates/admission) | Kyverno admits only images the gate signed |

[lab/](lab) runs the patterns on one machine and checks each one.
