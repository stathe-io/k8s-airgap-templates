# Network

By default every pod can reach every other pod. These files close a namespace,
then open only what you name. Follow the steps in order. Each ends with a check.

| File | What it is |
|---|---|
| [default-deny.yaml](default-deny.yaml) | Closes the namespace, both directions |
| [allow-dns.yaml](allow-dns.yaml) | Opens the cluster DNS, nothing else |
| [allow-from-namespace.yaml](allow-from-namespace.yaml) | Opens one path. Copy it per path |

Helps with: Regulation (EU) 2024/2690 annex 6.7 and 6.8. It covers traffic inside
one cluster, not your zones or anything outside it.

Tested on k3s v1.35 with its built-in policy enforcement: steps 1 to 4 ran,
including the blocked cases. The result depends on your network plugin.

## What you need

- A network plugin that enforces NetworkPolicy. Without one, these files apply
  cleanly and do nothing. Step 2 is what proves it.
- A test namespace first. Closing a namespace in production stops whatever you
  did not know about.

## Steps

**1. Fill in the namespace.** Replace REPLACE in the three files.

**2. Close it.**

```sh
kubectl apply -f default-deny.yaml -f allow-dns.yaml
```

Then, from a pod in another namespace:

```sh
kubectl exec POD -- wget -T3 -qO- http://SERVICE.NAMESPACE.svc.cluster.local:PORT
```

> Check: the command times out. If it still answers, your plugin does not enforce
> NetworkPolicy. Stop here.

**3. Check DNS still works.** From a pod in the closed namespace:

```sh
kubectl exec POD -- nslookup kubernetes.default.svc.cluster.local
```

> Check: it returns an address.

**4. Open what is needed.** Copy `allow-from-namespace.yaml` per path, fill it in
and apply it.

> Check: the wget from step 2 answers from the namespace you allowed, and still
> times out from any other.

## When something fails

| What you see | What it means | What to do |
|---|---|---|
| Step 2 still answers | The plugin does not enforce policies | Use a plugin that does, or enable it |
| Name lookups fail in the namespace | `allow-dns.yaml` is missing, or DNS runs with other labels | Check `kubectl -n kube-system get pods --show-labels` |
| A job stopped working after step 2 | It needed a path nobody knew about | Add a file for it. This is the reason for the test namespace |
