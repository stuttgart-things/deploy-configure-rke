# stuttgart-things/deploy-upgrade-rke

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

```
cat <<EOF > ./rke2 # or k3s
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
---
- hosts: all
  become: true

  vars:
    rke_docker_version: '=5:23.0.6-1~ubuntu.22.04~jammy'
    rke_docker_ce_version: '5:23.0.6*'
    rke_version: 1
    rke_installer_version: 1.4.8
    rke_kubernetes_version: v1.26.7-rancher1-1
    project_folder: rancher-things
    path_to_private_key: "/home/sthings/{{ project_folder }}/rke_rsa"
    rke_create_rke_user: true
    network_plugin: calico
    rke2_airgapped_installation: false

  roles:
    - role: deploy-configure-rke
```

</details>

<details><summary>EXAMPLE RKE2 PLAYBOOK</summary>

```
cat <<EOF > ./play.yaml
- hosts: all
  become: true

  vars:
    rke_version: 2
    rke2_k8s_version: 1.26.0
    rke2_airgapped_installation: true
    rke2_release_kind: rke2r2 # rke2r1
    disable_rke2_components: 
      - rke2-ingress-nginx
      - rke-snapshot-controller
    cluster_setup: multinode
    install_containerd: false # bring your own containerd
    containerdRootPath: /var/lib/containerd/ # directory must not exist
  
  roles:
    - role: deploy-configure-rke
EOF
  
ansible-playbook -i rke2 #k3s play.yaml -vv
```
</details>

<details><summary>EXAMPLE RKE2 + CUSTOM CONTAINERD + PROXY PLAYBOOK</summary>

  ```
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

ansible-playbook -i rke2 play.yaml -vv
```
</details>

  
<details><summary>EXAMPLE K3S PLAYBOOK</summary>

```
cat <<EOF > ./play.yaml
- hosts: all
  become: true

  vars:
    install_k3s: true
    k3s_state: present
    k3s_k8s_version: 1.21.1
    k3s_release_kind: k3s1
    k3s_parameters:
      - "--write-kubeconfig-mode 644"  
    cluster_setup: multinode
    install_containerd: false # bring your own containerd
    containerdRootPath: /var/lib/containerd/ # only if install_containerd true
  
  roles:
    - role: deploy-configure-rke
EOF
  
ansible-playbook -i k3s play.yaml -vv
```
</details>

<details><summary>EXAMPLE EXECUTION</summary>

```
ansible-playbook -i rke2 play.yaml -vv
```
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

