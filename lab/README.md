# The lab

The templates' patterns on one machine with k3d, each with a check. Linux or
macOS with Docker, k3d and kubectl.

```console
$ make bundle up verify
PASS  the cluster node is Ready
PASS  the network has no route out
PASS  the node cannot reach the internet
PASS  a pod from the bundle runs
PASS  a pod cannot reach the internet
PASS  an image outside the bundle is not pulled
PASS  the enclave registry holds exactly the bundle
PASS  a bundled image runs, pulled through the enclave registry
PASS  an unsigned image is refused at admission
PASS  an unsigned init container is refused at admission
PASS  the bundled vulnerability database is accepted
PASS  a database past its maximum age is refused
PASS  the gate refused an image with fixable critical vulnerabilities
PASS  every image has a scan report that matches its admission
$ make down
```

Its registry speaks plain http, so the gate signs in cosign's classic format.
A TLS registry with the referrers API, as in the templates, reads the current
one. Choices and their cost: [DECISIONS.md](DECISIONS.md).
