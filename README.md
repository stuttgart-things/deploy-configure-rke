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
    k3s_k8s_version: 1.36.1
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
    k3s_k8s_version: 1.36.1
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

<details><summary>EXAMPLE K3S PLAYBOOK w/ ADDONS</summary>

```bash
cat <<EOF > ./play.yaml
- hosts: all
  gather_facts: true
  become: true

  vars:
    install_k3s: true
    k3s_state: present #absent
    k3s_k8s_version: 1.36.1
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
