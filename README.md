# Kubernetes 一键安装脚本

## 项目介绍

本项目提供了一键安装 Kubernetes 集群的脚本，支持多种运行时（containerd、docker、cri-o）和多种网络插件（Cilium、Flannel、Calico）。

## 目录结构


## 一键安装
- master节点

```bash
export zone=cn
export k8s_version=v1.35.0
export cni_type=calico
export runtime=containerd
git clone --branch=release-1.35 https://github.com/long1318737396/k8s_install_one.git && cd k8s_install_one && bash main.sh
```
- node节点

```bash
hostnamectl set-hostname node1
export zone=cn
export master_ip=192.168.88.11
export role=node
curl -sSL https://raw.githubusercontent.com/long1318737396/k8s_install_one/refs/tags/${k8s_version}/install_one.sh |bash
```

- 清理

```bash
curl -sSL https://raw.githubusercontent.com/long1318737396/k8s_install_one/refs/tags/${k8s_version}/clean.sh
```
