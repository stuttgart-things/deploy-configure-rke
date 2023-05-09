# stuttgart-things/deploy-upgrade-rke

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


