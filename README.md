# stuttgart-things/deploy-upgrade-rke

deploy rancher kubernetes engine + configuration in version 1/2 on linux based systems

## DEV

<details><summary>TASKS</summary>

```bash
task: Available tasks for this project:
* branch:           Create branch from main
* commit:           Commit + push code into branch
* pr:               Create pull request into main
* setup-venv:       Setup python virtual environment
```

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

<details><summary>EXAMPLE RKE1 PLAYBOOK</summary>

```
cat <<EOF > ./play.yaml
---
- hosts: all
  become: true

  vars:
    rke_docker_version: '=5:23.0.6-1~ubuntu.22.04~jammy'
    rke_docker_ce_version: '5:23.0.6*'
    rke_version: 1
    rke_user_name: rke
    rke_installer_version: 1.4.8
    rke_kubernetes_version: v1.26.7-rancher1-1
    project_folder: rancher-things
    rke_create_rke_user: true
    network_plugin: calico
    rke2_airgapped_installation: false

  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i inv play.yaml -vv
```

</details>

<details><summary>EXAMPLE RKE2 PLAYBOOK</summary>

```bash
cat <<EOF > ./play.yaml
---
- hosts: all
  gather_facts: true
  become: true

  vars:
    rke_state: present #absent
    rke_version: 2
    rke2_k8s_version: 1.30.4
    rke2_airgapped_installation: true
    rke2_release_kind: rke2r1 #rke2r2
    rke2_cni: cilium
    disable_rke2_components:
      - rke2-ingress-nginx
      - rke-snapshot-controller
    cluster_setup: multinode
    rke2_cni: cilium
    values_cilium: |
      ---
      eni:
        enabled: true

    helmChartConfig:
      cilium:
        name: rke2-cilium
        namespace: kube-system
        release_values: "{{ values_cilium }}"

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
    k3s_k8s_version: 1.31.1
    k3s_release_kind: k3s1
    cluster_setup: singlenode
    install_cillium: true

  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i inv play.yaml -vv
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
    k3s_k8s_version: 1.31.1
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
