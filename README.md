# stuttgart-things/deploy-upgrade-rke

## EXAMPLE INVENTORY

```
[initial_master_node]
{{ .ip }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
[additional_master_nodes]
{{ .ip }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
{{ .ip }} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```


```
- hosts: all
  become: true

  vars:
    rke_version: 2
    rke2_k8s_version: 1.26.0
    rke2_release_kind: rke2r2 #rke2r1
    enable_ingress_controller: false
    
  roles:
    - role: deploy-configure-rke
```


