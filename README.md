# stuttgart-things/deploy-upgrade-rke

deploy rancher kubernetes engine  2 + configuration

## DEV

</details>

<details><summary>TEST w/ MOLECULE</summary>

```bash
# UPDATE INVENTORY + PLATFORMS NAME
task setup-venv
source ./.venv/bin/activate
task setup-molecule
scenario=rke2 task run-molecule
# scenario=k3s task run-molecule
```

</details>

## USAGE OPTION #1 - USING THE COLLECTION

### COLLECTION INSTALLATION

[CHECK RELEASES](https://github.com/stuttgart-things/deploy-configure-rke/releases)

```bash
# EXAMPLE COLLECTION RELEASE
VERSION=1.29.4
ansible-galaxy collection install -f \
https://github.com/stuttgart-things/deploy-configure-rke/releases/download/${VERSION}/sthings-deploy_rke-${VERSION}.tar.gz
```

<details><summary>INSTALL SINGLE-NODE CLUSTER</summary>

```bash
# CREATE INVENTORY
cat <<EOF > rke2.yaml
---
initial_master_node:
  hosts:
    10.100.136.150
additional_master_nodes:
workers:
EOF

# PLAYBOOK CALL
CLUSTER_NAME=rke2
mkdir ~/.kube/

ansible-playbook sthings.deploy_rke.rke2 \
-i rke2.yaml -vv \
-e rke2_fetched_kubeconfig_path=~/.kube/${CLUSTER_NAME} \
-e cluster_setup=singlenode \
-vv
```

</details>

<details><summary>INSTALL MULTI-NODE CLUSTER</summary>

```bash
# CREATE INVENTORY
cat <<EOF > rke2.yaml
initial_master_node:
  hosts:
    10.100.136.150
additional_master_nodes:
  hosts:
    10.100.136.151
    10.100.136.152
workers:
EOF

# PLAYBOOK CALL
CLUSTER_NAME=rke2
mkdir ~/.kube/${CLUSTER_NAME}

ansible-playbook sthings.deploy_rke.rke2 \
-i rke2.yaml -vv \
-e rke2_fetched_kubeconfig_path=~/.kube/${CLUSTER_NAME} \
-e cluster_setup=multinode \
-vv
```

</details>

<details><summary>UNINSTALL</summary>

```bash
# CREATE INVENTORY
cat <<EOF > rke2.yaml
initial_master_node:
  hosts:
    10.100.136.150
additional_master_nodes:
  hosts:
    10.100.136.151
    10.100.136.152
workers:
EOF

# PLAYBOOK CALL
CLUSTER_NAME=rke2
mkdir ~/.kube/${CLUSTER_NAME}

ansible-playbook sthings.deploy_rke.rke2 \
-i rke2.yaml -vv \
-e rke2_fetched_kubeconfig_path=~/.kube/${CLUSTER_NAME} \
-e cluster_setup=multinode \
-e rke_state: absent \
-vv
```

</details>


## USAGE OPTION #2 - USING STANDALONE ROLES + COLLECTIONS</summary>


<details><summary>INSTALL REQUIREMENTS</summary>

```
cat <<EOF > ./requirements.yaml
roles:
- src: https://github.com/stuttgart-things/deploy-configure-rke.git
  scm: git
- src: https://github.com/stuttgart-things/configure-rke-node.git
  scm: git
- src: https://github.com/stuttgart-things/install-requirements.git
  scm: git
- src: https://github.com/stuttgart-things/install-configure-docker.git
  scm: git
- src: https://github.com/stuttgart-things/create-os-user.git
  scm: git
- src: https://github.com/stuttgart-things/download-install-binary.git
  scm: git

collections:
- name: community.crypto
  version: 2.15.1
- name: community.general
  version: 7.3.0
- name: ansible.posix
  version: 1.5.2
- name: kubernetes.core
  version: 2.4.0
EOF

ansible-galaxy install -r ./requirements.yaml -f
```

</details>

<details><summary>EXAMPLE INVENTORY</summary>

```bash
cat <<EOF > ./inv
# MULTINODE-CLUSTER
[initial_master_node]
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
[additional_master_nodes]
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

# SINGLENODE-CLUSTER
[initial_master_node]
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
[additional_master_nodes]
EOF
```
</details>

</details>

<details><summary>EXAMPLE RKE2 PLAYBOOK</summary>

```bash
cat <<EOF > inventory.yaml
---
all:
  vars:
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
  children:
    initial_master_node:
      hosts:
        10.31.103.33:
    additional_master_nodes:
      hosts:
        10.31.103.28:
        10.31.103.35:
    workers:
      hosts:
        10.31.103.29:
EOF
```


```bash
cat <<EOF > ./play.yaml
---
- name: Converge
  hosts: all
  gather_facts: true
  become: true

  vars:
    rke_state: present #absent
    rke_version: 2
    rke2_k8s_version: 1.33.4
    prepare_rancher_ha_nodes: true #false
    rke2_airgapped_installation: true
    rke2_release_kind: rke2r1 # rke2r2
    cluster_setup: multinode
    disableKubeProxy: true
    disable_rke2_components:
      - rke2-ingress-nginx
      - rke2-snapshot-controller
      - rke2-snapshot-controller-crd
      - rke2-snapshot-validation-webhook
      #- rke2-metrics-server
    rke2_cni: none
    install_cilium: true

    fetched_kubeconfig_path: rke2-cluster.yaml
    rke2_registry_mirrors:
      - name: "docker.io"
        endpoints:
          #- "https://docker.harbor.example.com"
          - "https://registry-1.docker.io"

    manifests:
      lb_pool:
        manifest: |
          apiVersion: cilium.io/v2alpha1
          kind: CiliumLoadBalancerIPPool
          metadata:
            name: first-pool
          spec:
            blocks:
              - start: 10.100.136.227
                stop: 10.100.136.228

      announcement_policy:
        manifest: |
          ---
          apiVersion: cilium.io/v2alpha1
          kind: CiliumL2AnnouncementPolicy
          metadata:
            name: default-l2-announcement-policy
            namespace: kube-system
          spec:
            externalIPs: true
            loadBalancerIPs: true

  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i inv play.yaml -vv
```

</details>

<details><summary>EXAMPLE RKE2 + CUSTOM CONTAINERD + PROXY PLAYBOOK</summary>

```bash
cat <<EOF > ./play.yaml
- hosts: all
  become: true
  vars:
    containerdRootPath: /net/rngvm00556/fs0
    rke_version: 2
    rke2_airgapped_installation: true
    rke2_k8s_version: 1.26.0
    rke2_release_kind: rke2r2 #rke2r1
    cluster_setup: singlenode
    rke2_airgapped_installation: false
    enable_ingress_controller: false
    install_containerd: true
    rke2_configure_proxy: true
    rke2_proxy_config: |
      HOME=/root
      export HTTP_PROXY="http://127.0.0.1:3128"
      # export..
    containerd_proxy_config: |
      Environment="HTTP_PROXY=http://127.0.0.1:3128/"
      Environment="HTTPS_PROXY=http://127.0.0.1:3128/"
      # Environment..
  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i inv play.yaml -vv
```

</details>


<details><summary>EXAMPLE K3S PLAYBOOK</summary>

```bash
cat <<EOF > ./play.yaml
- hosts: all
  become: true

  vars:
    install_k3s: true
    k3s_state: present #absent
    k3s_k8s_version: 1.36.5
    k3s_release_kind: k3s1
    cluster_setup: singlenode
    install_cillium: true

  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i inv play.yaml -vv
```

</details>

<details><summary>EXAMPLE K3S AIRGAPPED PLAYBOOK</summary>

```bash
cat <<EOF > ./play.yaml
- hosts: all
  become: true

  vars:
    install_k3s: true
    k3s_state: present #absent
    k3s_k8s_version: 1.36.5
    k3s_release_kind: k3s1
    cluster_setup: singlenode
    install_cillium: true

    # --- air-gapped images (independent of the binary path) -----------------
    # Pre-seed the images archive into /var/lib/rancher/k3s/agent/images/.
    # IMAGES ONLY: the k3s binary + install script are still pulled normally.
    k3s_airgapped_installation: true
    # Point the archive at your mirror (e.g. a public S3/MinIO object):
    # k3s_airgapped_image_url: "https://your-host/k3s-airgap-images-amd64.tar.zst"
    # k3s_airgapped_archive: k3s-airgap-images-amd64.tar.zst
    # k3s_airgapped_install_dir: /var/lib/rancher/k3s/agent/images/
    # k3s_airgapped_checksum: "sha256:..."          # optional, verifies the archive

    # --- offline binary (optional, independent of images) -------------------
    # Set true to ALSO stage the k3s binary and run the install script with
    # INSTALL_K3S_SKIP_DOWNLOAD=true (no upstream binary pull). Leave false for
    # an images-only air-gap where the host still has egress for the binary.
    # k3s_airgapped_skip_download: true
    # k3s_airgapped_binary_url: "https://your-host/k3s"
    # k3s_airgapped_binary_dest: /usr/local/bin/k3s
    # k3s_airgapped_binary_checksum: "sha256:..."   # optional, verifies the binary
    # k3s_installscript_url: "https://your-host/k3s-install.sh"  # for zero egress

    # --- registry pull-through mirror (writes /etc/rancher/k3s/registries.yaml) ---
    k3s_registry_mirrors:
      - name: "docker.io"
        endpoints:
          - "https://docker.harbor.example.com"
          - "https://registry-1.docker.io"   # fallback
    # k3s_registry_configs:            # optional auth / TLS per registry host
    #   "docker.harbor.example.com":
    #     username: "robot\$puller"
    #     password: "<secret>"
    #     tls:
    #       insecure_skip_verify: false

    # SELinux toggles (default false). On air-gapped, SELinux-enforcing
    # RHEL-family hosts set both true so a missing k3s-selinux policy does not
    # abort the offline install (requires k3s_airgapped_skip_download):
    # k3s_skip_selinux_rpm: true   # never reach the package manager for k3s-selinux
    # k3s_selinux_warn: true       # missing SELinux policy -> warning instead of fatal

  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i inv play.yaml -vv
```

</details>

<details><summary>CILIUM AIR-GAPPED IMAGES</summary>

Cilium here is installed via **cilium-cli**, which pulls its images directly from
`quay.io`. On an edge / offline device those won't resolve, so the role can
pre-load the Cilium images from a tar into containerd before install/upgrade and
pin the pull policy so pods start from the local store. This is **independent**
of the k3s/rke2 binary and `*_airgapped_installation` image paths — cilium-cli
images are not covered by those.

**Variables** (`defaults/main.yaml`):

```yaml
# Pull policy on agent/operator/envoy via the upgrade values file. Default
# "Always" keeps online behaviour; set "Never" (strict) or "IfNotPresent" on edge.
cilium_image_pull_policy: Always

# Toggle the image pre-load. Off by default (online pull).
cilium_airgapped_images: false
# HTTPS source for the images tar (required when enabled). Mirrors rke2_airgapped_image_url.
cilium_airgapped_image_url: ""
# Where the tar is downloaded on every node before import.
cilium_airgapped_install_dir: /var/lib/rancher/cilium-images
cilium_airgapped_archive: cilium-images.tar
cilium_airgapped_archive_path: "{{ cilium_airgapped_install_dir }}/{{ cilium_airgapped_archive }}"
# Optional integrity check, fails loudly on truncation. Mirrors rke2_airgapped_checksum.
# cilium_airgapped_checksum: "sha256:..."
# ctr invocation for the import: "k3s ctr" on k3s, rke2's ctr binary on rke2 (auto).
cilium_ctr_cmd: "{{ 'k3s ctr' if install_k3s | bool else rke2_bin_dir ~ 'ctr' }}"
```

When enabled, on **every node** (the agent is a DaemonSet) the role downloads
the tar, then imports it into containerd's `k8s.io` namespace with
`ctr images import --digests` before install/upgrade. Cilium has no single global
pull-policy key, so the policy is set per component (agent/operator/envoy) in
`templates/cilium-config.yaml.j2`. Note: only the `cilium upgrade -f` pass reads
that file — the initial `cilium install` uses cilium-cli's default
(`IfNotPresent`), which already uses a pre-loaded image without pulling.

**Build the archive** — `hack/export-cilium-images.sh` exports the running
Cilium images (with digests) straight from a node that already has them, no
internet needed:

```bash
# on a node already running Cilium (k3s default; override CTR/KUBECONFIG for rke2):
sudo ./hack/export-cilium-images.sh                # -> cilium-images.tar + .sha256
sudo CTR="/var/lib/rancher/rke2/bin/ctr" ./hack/export-cilium-images.sh   # rke2

# manual equivalent:
mapfile -t IMAGES < <(k3s ctr -n k8s.io images ls -q | grep -i cilium | grep -v '^sha256:' | sort -u)
k3s ctr -n k8s.io images export cilium-images.tar "${IMAGES[@]}"
sha256sum cilium-images.tar | tee cilium-images.tar.sha256
```

Cilium image refs are digest-pinned (`<name>@sha256:...`), so the script lists
them from containerd's store rather than the pod spec — the pod's combined
`tag@sha256:...` form is not a stored reference and `ctr export` rejects it.
Importing with `--digests` recreates those digest refs so kubelet resolves the
pinned reference under `pullPolicy: Never`.

Publish the tar to your mirror and enable on the edge nodes:

```yaml
cilium_airgapped_images: true
cilium_airgapped_image_url: "https://your-host/cilium-images.tar"
cilium_image_pull_policy: Never
# cilium_airgapped_checksum: "sha256:<from cilium-images.tar.sha256>"
```

For RKE2 edge nodes, also set `rke2_cni: none` so cilium-cli (not RKE2's bundled
CNI) manages Cilium.

</details>

<details><summary>CILIUM VERSION (cilium-cli vs. Cilium) AND GATEWAY API CRDs</summary>

`cilium_version` is the **cilium-cli** version. `cilium install` / `cilium upgrade`
deploy whatever Cilium release that CLI build defaults to, so bumping the CLI
also moves Cilium on the next run:

| cilium-cli | default Cilium (`cilium version --client`) |
|------------|--------------------------------------------|
| 0.19.4     | 1.19.3                                     |
| 0.19.7     | 1.19.5 (role default)                      |
| 0.20.1     | 1.20.1                                     |

Pin Cilium independently with `cilium_chart_version`. It is passed as `--version`
to both install and upgrade (the upgrade needs it too, or it would move Cilium
back to the CLI default). Empty means the CLI default.

The Gateway API CRDs (`standard-install.yaml` of `cilium_gateway_api_crds_version`)
must match the Cilium minor:

| Cilium        | Gateway API CRDs | note |
|---------------|------------------|------|
| 1.19.1 - 1.19.x | v1.4.1 (role default) | TLSRoute experimental, not in standard |
| 1.20.x        | v1.6.1 | hard minimum; TLSRoute moved to v1 |

The CRDs are applied **server-side** (`--server-side --force-conflicts
--field-manager=deploy-configure-rke`). CRDs that an older role version applied
client-side are taken over and upgraded in place. A server-side `kubectl diff`
runs first, so an in-sync cluster reports `ok`, not `changed`.

Moving to v1.6.x is **one-way**. It installs the ValidatingAdmissionPolicy
`safe-upgrades.gateway.networking.k8s.io`, which rejects CRDs older than v1.5.0.
If you used TLSRoute `v1alpha2` objects (experimental channel), read the Cilium 1.20
upgrade notes before switching: the v1.6 standard TLSRoute no longer serves v1alpha2.

The defaults stay on Cilium 1.19 + v1.4.1, so existing clusters that don't pin
these vars only get a patch upgrade on their next run. Opt in to 1.20 per cluster
(Cilium 1.20 is the first line whose docs list k8s 1.35/1.36 as tested):

```yaml
cilium_version: 0.20.1
cilium_chart_version: "1.20.2"            # quote it
cilium_gateway_api_crds_version: v1.6.1
```

</details>

<details><summary>K3S DATASTORE: ETCD OR SQLITE</summary>

`k3s_cluster_init` (default `true`) feeds `k3s_config.cluster_init`, which renders
as `cluster-init:` in the k3s config:

- `true`: embedded etcd. Required to add more servers later.
- `false`: sqlite/kine. Lighter on CPU, RAM and disk writes. Meant for single-node
  edge boxes. Cannot grow into an HA cluster.

Both a bool and the string form work (`-e k3s_cluster_init=false`, or the
space-separated parameter string). Choose it before the **first** install:
changing it on an existing node does not migrate the datastore. A changed
k3s config file does trigger the install script, and with it a k3s restart.

</details>

<details><summary>KUBECONFIG SERVER AND CILIUM k8sServiceHost: FQDN, NOT THE BUILD-TIME IP</summary>

A DHCP-built node can come back from a reboot with another IP. Everything pinned
to the old one then breaks (stuttgart-things/stuttgart-things#4211). Its DNS
name follows the lease.

- **kubeconfig `server:`** (the node's file, the fetched one, and what gets
  published from it): the initial master's `ansible_fqdn`, once a probe from that
  node shows it resolves and the API presents a certificate for it, signed by
  the cluster CA (`api_server_ca_path`). Otherwise the IP, as before. The run
  says which one it took, and why.
- **Cilium `k8sServiceHost`**: `127.0.0.1` with `cluster_setup: singlenode`.
  Agent and operator run in the host network, so nothing is tied to a lease. With
  more nodes, the kubeconfig host. A re-run on an existing cluster moves it over
  through `cilium upgrade`.

```yaml
kubeconfig_server_host: api.my-cluster.example.com  # skip the probe, use this name
cilium_api_server_ip: 10.31.103.22                  # override Cilium's host
```

Not covered: etcd and the join URL of further nodes still use the IP. A
control-plane VM built from DHCP still wants a reservation.

</details>

<details><summary>CILIUM GATEWAY API: ALPN FOR gRPC</summary>

With `cilium_enable_gateway_api: true` the role also renders

```yaml
cilium_gateway_api_enable_alpn: true          # gatewayAPI.enableAlpn
cilium_gateway_api_enable_app_protocol: true  # gatewayAPI.enableAppProtocol
```

Without `enableAlpn` the Gateway's HTTPS listeners negotiate **no ALPN**. gRPC
clients built with grpc-go >= 1.67 then abort the TLS handshake:

```
credentials: cannot check peer: missing selected ALPN property
```

so a `GRPCRoute` is unusable from any current Go client. Older clients (e.g.
grpcurl built on grpc 1.61) do not check ALPN and keep working, which hides the
problem. `enableAppProtocol` makes Envoy honour a backend Service port's
`appProtocol: kubernetes.io/h2c`.

Check a listener:

```bash
echo | openssl s_client -connect <host>:443 -servername <host> -alpn h2 2>/dev/null | grep -i alpn
# ALPN protocol: h2        <- ok
# No ALPN negotiated       <- enableAlpn is off
```

Takes effect on the `cilium upgrade -f` pass of the next playbook run; agent,
operator and envoy roll out again.

</details>

<details><summary>RKE2 KUBE-APISERVER: EXTRA ARGS, MOUNTS, OIDC (STRUCTURED AUTHENTICATION)</summary>

Server nodes only (not `workers`), rke2 only. All empty by default: the
rendered `config.yaml` stays as it was.

```yaml
# extra flags, without the leading dashes -> kube-apiserver-arg
rke2_kube_apiserver_args:
  - audit-log-maxage=30
# extra host paths -> kube-apiserver-extra-mount ("<host>:<container>[:ro]")
rke2_kube_apiserver_extra_mounts:
  - /etc/rancher/rke2/audit:/etc/rancher/rke2/audit:ro
```

`rke2_authentication_config` writes an `AuthenticationConfiguration` (the
object below `apiVersion`/`kind`) to
`/etc/rancher/rke2/authn/authentication-config.yaml` on every server node
(mode 0600), mounts the directory read-only into the apiserver and adds
`--authentication-config`. Example: OIDC logins from ZITADEL, the project roles
as groups:

```yaml
rke2_authentication_config:
  jwt:
    - issuer:
        url: https://zitadel.example.com            # exactly as in the discovery document
        audiences:
          - "<client id>"                           # the ID token's aud
        certificateAuthority: |                     # optional: CA of a private issuer
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----
      claimMappings:
        username:
          claim: email                              # email_verified must not be false
          prefix: "zitadel:"
        groups:
          # keys of the roles claim; with expression, the prefix goes into it
          expression: 'dyn(claims[?"urn:zitadel:iam:org:project:roles"].orValue({})).map(r, "zitadel:" + r)'
```

- `rke2_authentication_config_api_version`: `apiserver.config.k8s.io/v1`
  (Kubernetes >= 1.34); `v1beta1` for 1.30 - 1.33.
- `--authentication-config` replaces the `--oidc-*` flags; do not set both.
  Client certificates and ServiceAccount tokens keep working, so an IdP that
  is down only breaks the OIDC logins.
- The apiserver reloads the file when its content changes. Adding or removing
  the flag or the mount needs an rke2-server restart.
- Nothing is authorized by this: bind the mapped users / groups with RBAC
  (e.g. a ClusterRoleBinding for group `zitadel:<role>`).

**Validate first.** kube-apiserver refuses to start on an invalid
authentication config (e.g. a CEL expression that does not compile), and the
same file goes to every server. Check it with the kube-apiserver binary of the
cluster version before the run -- it fails within a second on a bad config and
otherwise only waits for etcd:

```bash
curl -sfLO https://dl.k8s.io/v1.35.1/bin/linux/amd64/kube-apiserver && chmod +x kube-apiserver
openssl req -x509 -newkey rsa:2048 -nodes -keyout k.pem -out c.pem -subj /CN=t 2>/dev/null
timeout 10 ./kube-apiserver --authentication-config=authn.yaml --etcd-servers=http://127.0.0.1:1 \
  --service-account-issuer=x --service-account-key-file=c.pem \
  --service-account-signing-key-file=k.pem --cert-dir=. 2>&1 | grep -i "invalid authentication"
```

Claim values are typed `any` in CEL: wrap a claim in `dyn()` before `.map()`
or other macros over it. The binary only catches compile errors: `"<claim>"
in claims` compiles but fails at every login (`no such overload`, `claims` is
a lazy map), and `has()` takes no claim name with colons -- use
`claims[?"<claim>"].orValue(<default>)`. Runtime errors show up in the
apiserver log as `error evaluating ... claim expression`. A change of the
authentication config alone needs no restart: the apiserver reloads the file
(`reloaded authentication config`) and keeps the old one if it rejects it.

**Restart.** A normal run restarts rke2-server on every node at the same time
(`restart_rke2_already_running: true`) -- with a broken config that is every
apiserver down. For an in-place change, let the handler do it instead -- one
server at a time, the next only once this one is back (rke2-server active
again and `/readyz`), and the run stops at the first node that does not come
back:

```bash
ansible-playbook -i inventory play.yaml \
  -e restart_rke2_already_running=false \
  -e rke2_restart_on_config_change=true
```

The handler restarts only servers whose `config.yaml` or authentication config
changed (`rke2_restart_ready_retries` x `rke2_restart_ready_delay`, default
30 x 10s per server). If one does not come back, its config is in place but
the remaining servers are untouched: fix or revert the file there and restart
rke2-server on that node.

Check on a server node:

```bash
grep -A3 kube-apiserver-arg /etc/rancher/rke2/config.yaml
/var/lib/rancher/rke2/bin/crictl -r /run/k3s/containerd/containerd.sock ps --name kube-apiserver
# with an ID token of the issuer:
kubectl --token "$ID_TOKEN" auth whoami
```

</details>

<details><summary>EXAMPLE K3S PLAYBOOK w/ ADDONS</summary>

```bash
cat <<EOF > ./play.yaml
- hosts: all
  gather_facts: true
  become: true

  vars:
    install_k3s: true
    k3s_state: present #absent
    k3s_k8s_version: 1.36.5
    k3s_release_kind: k3s1
    cluster_setup: singlenode
    install_cillium: true
    deploy_helm_charts: true
    helm_repositories:
      ingress-nginx:
        url: https://kubernetes.github.io/ingress-nginx
      cert-manager:
        url: https://charts.jetstack.io

    helm_releases:
      ingress-nginx:
        ref: ingress-nginx/ingress-nginx
        version: 4.11.3
        namespace: ingress-nginx
        ignore: false
        wait: true
        helm_values: |
          controller:
            hostNetwork: true
            service:
              type: ClusterIP

      cert-manager:
        ref: cert-manager/cert-manager
        version: v1.16.1
        namespace: cert-manager
        ignore: false
        wait: true
        helm_values: |
          crds:
            enabled: true

    additional_helm_manifests:
      cluster_issuer:
        manifest: |
          apiVersion: cert-manager.io/v1
          kind: ClusterIssuer
          metadata:
            name: ca-issuer
          spec:
            ca:
              secretName: root-ca

  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i inv play.yaml -vv
```

</details>





<details><summary>EXAMPLE EXECUTION</summary>

```bash
ansible-playbook -i rke2 play.yaml -vv
```

</details>

</details>


Author Information
------------------
```
Patrick Hermann, stuttgart-things 05/2023
Christian Mueller, stuttgart-things 05/2023
```

## License
<details><summary>LICENSE</summary>

Copyright 2020 patrick hermann.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
</details>
