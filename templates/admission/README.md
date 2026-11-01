# Admission

Kyverno checks every new pod. A pod starts only if all its images carry the
import gate's signature. Follow the steps in order. Each ends with a check.

| File | What it is |
|---|---|
| [require-gate-signature.yaml](require-gate-signature.yaml) | The policy |
| [kyverno-enclave-ca.yaml](kyverno-enclave-ca.yaml) | Makes Kyverno trust the enclave CA |

Tested in the lab with Kyverno v1.19.2. Steps 1, 2, 4 and 5 ran as written,
with the lab's registry name and one extra policy line for its plain-http
registry. Step 3 was applied separately. With a TLS registry, Kyverno read
signatures in cosign's current format.

## What you need

- The Kyverno v1.19.2 `install.yaml` and its five images in the enclave
  registry, under `kyverno/`. They come in with the transfer.
- The gate's public key, `cosign.pub`.
- The enclave CA certificate.
- Every workload names the enclave registry in its image, for example
  `registry.enclave.example:5000/app@sha256:...`. Kyverno fetches the signature
  from the registry the pod names.

## Steps

**1. Install Kyverno, with its images from the enclave registry.**

```sh
sed 's#reg.kyverno.io/#registry.enclave.example:5000/#g' install.yaml |
  kubectl apply --server-side -f -
kubectl -n kyverno rollout status deployment kyverno-admission-controller
```

> Check: `successfully rolled out`.

**2. Run three replicas.** The policy refuses pods when Kyverno cannot answer,
so one replica going down would stop deployments.

```sh
kubectl -n kyverno scale deployment kyverno-admission-controller --replicas=3
```

> Check: `kubectl -n kyverno get deployment kyverno-admission-controller`
> shows `3/3`.

**3. Trust the enclave CA.** Commands are at the top of
[kyverno-enclave-ca.yaml](kyverno-enclave-ca.yaml).

> Check: the rollout ends with `successfully rolled out`.

**4. Apply the policy.** Paste the contents of `cosign.pub` into
`require-gate-signature.yaml` where it says REPLACE, keeping the indentation.

```sh
kubectl apply -f require-gate-signature.yaml
kubectl get imagevalidatingpolicy
```

> Check: `require-gate-signature` with READY `true`.

**5. Prove it works.** One image that went through the gate, one that did not:

```sh
kubectl run signed --image=registry.enclave.example:5000/app@sha256:... --dry-run=server
kubectl run unsigned --image=registry.enclave.example:5000/other@sha256:... --dry-run=server
```

> Check: the first says `created (server dry run)`. The second is denied with
> `image is not signed by the import gate`.

## When something fails

| What you see | What it means | What to do |
|---|---|---|
| `image is not signed by the import gate` | The image did not pass the gate, or was signed with another key | Send it through the gate. Check that the policy holds the gate's key |
| Every image refused. The Kyverno log says `http: server gave HTTP response to HTTPS client` | The registry has no TLS | Give the registry a certificate from the enclave CA |
| Every image refused, signed ones too. `cosign verify` says they are signed | Kyverno cannot read the signature from the registry | Step 3. Check that the pod names the enclave registry |
| `is not verified: no policy performed a signature or attestation check` | Someone changed the expression and an image is no longer checked | Restore the expression from this template |

Kyverno's log: `kubectl -n kyverno logs deployment/kyverno-admission-controller`.
