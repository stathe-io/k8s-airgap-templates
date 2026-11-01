# RKE2

A hardened Kubernetes node (CIS profile, SELinux) inside a network with no
route out. Follow the steps in order. Each ends with a check. Run everything
on the node as root.

| File | Goes to |
|---|---|
| [config.yaml](config.yaml) | `/etc/rancher/rke2/config.yaml` |
| [registries.yaml](registries.yaml) | `/etc/rancher/rke2/registries.yaml` |
| [blackhole-route.service](blackhole-route.service) | `/etc/systemd/system/` |

Tested on AlmaLinux 9.8 (arm64, SELinux enforcing) with RKE2 v1.35.9 and no
network route out. Not tested: `system-default-registry`, because the test node
loaded its system images from the tarball.

## Before you start: what to bring in

Fetch these on the connected side for one RKE2 version and architecture, check
them and bring them in with the transfer (see [transfer](../transfer)):

- `rke2-images.linux-amd64.tar.zst` (about 1 GB)
- `rke2.linux-amd64.tar.gz`
- `sha256sum-amd64.txt`
- `install.sh`, from `https://get.rke2.io`
- `rke2-selinux-<version>.el9.noarch.rpm`, from the
  [rke2-selinux releases](https://github.com/rancher/rke2-selinux/releases).
  Take a release with `stable` in its name.

Use `arm64` instead of `amd64` on ARM servers.

## Steps

**1. Put the files in place.**

```sh
mkdir -p /root/rke2-artifacts
cp install.sh rke2-images.linux-amd64.tar.zst rke2.linux-amd64.tar.gz sha256sum-amd64.txt /root/rke2-artifacts/
cd /root/rke2-artifacts && grep -E ' (rke2-images.linux-amd64.tar.zst|rke2.linux-amd64.tar.gz)$' sha256sum-amd64.txt | sha256sum -c -
```

> Check: both files say `OK`.

**2. Give the node a default route if it has none.** Run `ip route show
default`. If it prints nothing:

```sh
cp blackhole-route.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now blackhole-route.service
```

> Check: `ip route show default` prints `default via 203.0.113.255 dev
> blackhole0`. `curl -m 5 https://1.1.1.1` still fails.

**3. Note the node's address.** `ip -4 addr show eth0` (your interface name
may differ). The address after `inet`, without `/24`, goes into `node-ip` in
`config.yaml`.

**4. Install the SELinux policy.** `container-selinux` comes from your
distribution's local package mirror. `rke2-selinux` from the bundle:

```sh
dnf install -y container-selinux
dnf install -y --disablerepo='*' ./rke2-selinux-0.24-1.el9.noarch.rpm
```

> Check: `rpm -q rke2-selinux` prints the version. `getenforce` prints
> `Enforcing`.

**5. Create the etcd user and the configuration.**

```sh
useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
mkdir -p /etc/rancher/rke2
cp config.yaml registries.yaml /etc/rancher/rke2/
```

Edit `/etc/rancher/rke2/config.yaml` and fill in every line marked REPLACE.
Put the enclave CA certificate where `registries.yaml` expects it.

> Check: `grep node-ip /etc/rancher/rke2/config.yaml` shows the address from
> step 3. Set it now: changing it after the first start breaks etcd.

**6. Install RKE2 and apply the kernel settings.**

```sh
INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts sh /root/rke2-artifacts/install.sh
cp -f /usr/local/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
systemctl restart systemd-sysctl
```

> Check: the installer ends with `applying correct SELinux contexts to RKE2
> files`, without an error.

**7. Start.**

```sh
systemctl enable --now rke2-server.service
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml PATH=$PATH:/var/lib/rancher/rke2/bin
kubectl get nodes -o wide
```

> Check: within a few minutes the node is `Ready` and `INTERNAL-IP` is the
> address from step 3. `kubectl get pods -A` shows everything `Running` or
> `Completed`.

**8. Turn on the audit log.** The CIS profile installs a policy that logs
nothing. In `/etc/rancher/rke2/audit-policy.yaml` change `level: None` to
`level: Metadata`, then `systemctl restart rke2-server`.

> Check: `/var/lib/rancher/rke2/server/logs/audit.log` grows when you run
> `kubectl get ns`.

**9. Confirm the hardening.** A privileged pod must be refused:

```sh
kubectl run test --image=registry.k8s.io/pause:3.10 --dry-run=server \
  --overrides='{"spec":{"containers":[{"name":"test","image":"registry.k8s.io/pause:3.10","securityContext":{"privileged":true}}]}}'
```

> Check: `forbidden: violates PodSecurity "restricted:latest"`.

## When something fails

| What you see | What it means | What to do |
|---|---|---|
| `download sha256 does not match` from `install.sh` | A file is damaged, often because the disk ran full while copying | Free space, copy again, repeat step 1 |
| `INTERNAL-IP` is `203.0.113.254` | `node-ip` was not set | Set it, then reinstall: uninstall, step 4, step 5, step 6 |
| `this server is not a member of the etcd cluster` in `journalctl -u rke2-server` | `node-ip` changed after the first start | Uninstall and start again from step 4 |
| No containers start. `/var/lib/rancher/rke2/agent/containerd/containerd.log` shows `proc/self/attr/keycreate: invalid argument` | `rke2-selinux` is missing. `rke2-uninstall.sh` removes it | Step 4 again, then `systemctl restart rke2-server` |
| A workload is `forbidden: violates PodSecurity "restricted:latest"` | The CIS profile works. The workload asks for more than restricted allows | Fix the workload: non-root user, no privilege, a seccomp profile |

To start over: `/usr/local/bin/rke2-uninstall.sh`, then repeat from step 4.

Source: RKE2 [air-gap](https://docs.rke2.io/install/airgap) and
[hardening](https://docs.rke2.io/security/hardening_guide) documentation.
