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
# MULTINODE-CLUSTER
[initial_master_node]
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
[additional_master_nodes] 
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

# SINGLENODE-CLUSTER
# MULTINODE-CLUSTER
[initial_master_node]
{{ .fqdn }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
[additional_master_nodes]
```

## EXAMPLE PLAY

```
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
```


