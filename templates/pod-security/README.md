# Pod Security

Kubernetes can refuse privileged and root pods by itself, per namespace, with
three labels. Nothing to install, so it works the same in an enclave.

| File | What it is |
|---|---|
| [namespace.yaml](namespace.yaml) | A namespace that enforces `baseline` and warns about `restricted` |
| [restricted-pod.yaml](restricted-pod.yaml) | The fields a workload needs to pass `restricted` |

Helps with: Regulation (EU) 2024/2690 annex 6.3. It covers pods, not hosts.

Tested on Kubernetes v1.35: every step ran, including the refused pods.

## Steps

**1. Apply the namespace.** Replace REPLACE, then:

```sh
kubectl apply -f namespace.yaml
```

> Check: a privileged pod is refused with `violates PodSecurity "baseline`. A pod
> that merely runs as root is created, with a warning about `restricted`.

**2. Fix what the warnings name.** Copy the two `securityContext` blocks from
`restricted-pod.yaml` into your workloads. Then ask what would still fail,
without changing anything:

```sh
kubectl label --dry-run=server --overwrite ns NAME pod-security.kubernetes.io/enforce=restricted
```

> Check: no warnings. Each one names a pod that would stop being allowed.

**3. Enforce.**

```sh
kubectl label --overwrite ns NAME pod-security.kubernetes.io/enforce=restricted
```

> Check: `restricted-pod.yaml` applies. A pod without those blocks is refused.

## When something fails

| What you see | What it means | What to do |
|---|---|---|
| A Deployment shows 0 ready and no pods | Its pods are refused. The error is on the ReplicaSet | `kubectl describe rs` |
| `runAsNonRoot` and the container will not start | The image has a user name, or runs as root | Set a numeric `runAsUser`, or use an image built for it |
| A platform component needs more | Some agents need host access | Give it its own namespace at `privileged`, and write down why |
