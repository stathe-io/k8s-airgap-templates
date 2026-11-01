# RKE2

| File | Goes to | Tested |
|---|---|---|
| `config.yaml` | `/etc/rancher/rke2/config.yaml` | Against the RKE2 documentation only |
| `registries.yaml` | `/etc/rancher/rke2/registries.yaml` | The mirror pattern runs in the lab on k3s |
| `blackhole-route.service` | `/etc/systemd/system/` | In a Linux container without a network |

Replace `registry.enclave.example` and the CA path.

Bundle from the connected side, per version and architecture:
`rke2-images.linux-amd64.tar.zst`, `rke2.linux-amd64.tar.gz`,
`sha256sum-amd64.txt` and `install.sh` from `https://get.rke2.io`.

On each node, in this order:

```sh
sudo systemctl enable --now blackhole-route.service   # if the node has no default route
sudo useradd -r -c "etcd user" -s /sbin/nologin -M etcd -U
sudo mkdir -p /etc/rancher/rke2                        # then place config.yaml and registries.yaml
sudo INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts sh /root/rke2-artifacts/install.sh
sudo cp -f /usr/local/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
sudo systemctl restart systemd-sysctl
sudo systemctl enable --now rke2-server.service
```

On SELinux hosts, install `rke2-selinux` from local packages first. On an RPM
install the sysctl file is in `/usr/share/rke2/`.

After the first start, raise the audit level in
`/etc/rancher/rke2/audit-policy.yaml` from `None` to at least `Metadata`. The
CIS profile installs it logging nothing.

Source: RKE2 [air-gap](https://docs.rke2.io/install/airgap) and
[hardening](https://docs.rke2.io/security/hardening_guide) documentation.
