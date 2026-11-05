# k8s-airgap-templates

Templates for a Kubernetes platform, air-gapped or not. Each one says where it
goes, what to replace and how far it was tested. Copy what you need.

| Template | |
|---|---|
| [network](templates/network) | Close a namespace, then open only what you name. Tested, including what stays blocked |
| [pod-security](templates/pod-security) | Refuse privileged and root pods with three labels. Tested on v1.35 |
| [policies](templates/policies) | Digests, no `latest` and memory limits, from Audit to Deny. Tested with Kyverno v1.19 |
| [transfer](templates/transfer) | Seal a bundle on the connected side, open it at the gate. Tested on five cases |
| [rke2](templates/rke2) | RKE2 with the CIS profile and SELinux, step by step. Tested on AlmaLinux 9 without a route out |
| [harbor](templates/harbor) | Harbor as the enclave registry, with an offline scanner. Not yet installed in a test |
| [admission](templates/admission) | Kyverno admits only images the gate signed. Tested in the lab |

[lab/](lab) runs the patterns on one machine and checks each one.

Apache 2.0. See [LICENSE](LICENSE).
