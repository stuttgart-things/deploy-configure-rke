# stuttgart-things/deploy-upgrade-rke

## INSTALLATION

```
cat <<EOF > ./requirements.yaml
roles:
- src: https://github.com/stuttgart-things/deploy-configure-rke.git
  scm: git
  version: rke2r2-1.26.0
- src: https://github.com/stuttgart-things/configure-rke-node.git
  scm: git
  version: rke2r2-1.26.0
- src: https://github.com/stuttgart-things/install-requirements.git
  scm: git
  version: rke2r2-1.26.0 

collections: 
- name: community.crypto 
  version: 2.13.0 
- name: community.general 
  version: 7.0.0 
- name: ansible.posix 
  version: 1.5.2 
- name: kubernetes.core
  version: 2.4.0
EOF

ansible-galaxy install -r ./requirememts.yaml -f
```

## EXAMPLE INVENTORY

```
cat <<EOF > ./rke2
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

## EXAMPLE PLAY

```
cat <<EOF > ./play.yaml
- hosts: all
  become: true

  vars:
    rke_version: 2
    rke2_k8s_version: 1.26.0
    rke2_release_kind: rke2r2 #rke2r1
    enable_ingress_controller: false
    cluster_setup: multinode

  roles:
    - role: deploy-configure-rke
EOF

ansible-playbook -i rke2 play.yaml -vv
```

Author Information
------------------
Patrick Hermann, stuttgart-things 05/2023

## License

Copyright 2023 patrick hermann.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

