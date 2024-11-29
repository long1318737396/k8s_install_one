## 一键安装
- master节点

```bash
export zone=cn
export k8s_version=v1.32.3
export cni_type=calico
curl -sSL https://gitee.com/long1318737396/k8s_install_one/raw/main/install_one.sh |bash
curl -sSL https://raw.githubusercontent.com/long1318737396/k8s_install_one/main/install_one.sh | bash
```
- node节点

```bash
hostnamectl set-hostname node1
export zone=cn
export master_ip=192.168.88.11
export role=node
curl -sSL https://gitee.com/long1318737396/k8s_install_one/raw/main/install_one.sh |bash
curl -sSL https://raw.githubusercontent.com/long1318737396/k8s_install_one/main/install_one.sh | bash
```

- 清理

```bash
curl -sSL https://gitee.com/long1318737396/k8s_install_one/raw/main/clean.sh |bash
curl -sSL https://raw.githubusercontent.com/long1318737396/k8s_install_one/main/clean.sh | bash
```