# Policies

Three Kyverno policies that keep images and limits honest. They start in Audit,
so you see what would be refused before anything is.

| File | What it refuses |
|---|---|
| [disallow-latest.yaml](disallow-latest.yaml) | `latest`, or no tag at all |
| [require-digest.yaml](require-digest.yaml) | Any image not pinned by digest |
| [require-memory-limit.yaml](require-memory-limit.yaml) | A container with no memory limit |

Helps with: Regulation (EU) 2024/2690 annex 6.3 and 6.4. A policy in Audit
refuses nothing, so say which mode it runs in when you cite it.

Tested with Kyverno v1.19.2 on k3s v1.35: every step ran, including refused pods,
init containers and Deployments.

## What you need

Kyverno, see [admission](../admission). Start with `disallow-latest` if
`require-digest` is too big a step today: it allows pinned tags.

## Steps

**1. Apply them in Audit.**

```sh
kubectl apply -f .
kubectl get validatingpolicy
```

> Check: three policies, READY `true`.

**2. Read the report.** It can take a few minutes to fill.

```sh
kubectl get policyreport -A
```

> Check: one line per pod, with PASS and FAIL. Each FAIL is a conversation to have
> before step 3, not after.

**3. Deny, one policy at a time, when its FAIL is at zero.** In the file, change
`validationActions: [Audit]` to `[Deny]` and apply it.

> Check: `kubectl run t --image=busybox:latest --dry-run=server` is refused with
> the policy's message.

## When something fails

| What you see | What it means | What to do |
|---|---|---|
| `kubectl create deployment` is refused | Kyverno checks Deployments too | This is the policy working. Fix the image or the limits |
| `policyreport` stays empty | The reports controller is not running, or needs a moment | `kubectl -n kyverno get pods` |
| A platform image is refused | Its namespace is not excluded | Add it to `values` in the policy, and keep that list short |
