# Admission

Kyverno v1.19 admits only images signed by the import gate.

| File | Use | Tested |
|---|---|---|
| `require-gate-signature.yaml` | `kubectl apply -f`, after setting the gate's public key | Accepted by the API server. The same policy with an http exemption runs in the lab |
| `kyverno-enclave-ca.yaml` | Patch on the admission controller, commands in the file | Applied to the lab's Kyverno |

Workloads must name the enclave registry in their image references. Kyverno
fetches signatures from the registry a pod names and does not use the node's
mirror.

Run the admission controller with three replicas. The policy fails closed, so
Kyverno is part of the platform's availability.
