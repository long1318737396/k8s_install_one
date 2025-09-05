#!/bin/bash
set -x

# 全局变量定义
arch=`arch`
if [ "$arch" == "x86_64" ];then
  ARCH=amd64
elif [ "$arch" == "aarch64" ];then
  ARCH=arm64
else
  echo "this arch is not unsupport"
  exit 1
fi

#-----------变量配置--------------
runtime="containerd"
bin_dir=/usr/bin
cni_type=calico
base_url=https://ghfast.top
serviceSubnet="10.96.0.0/12"
podSubnet="10.244.0.0/16"
nfs_path=/data/k8s/nfs
docker_data_root=/data/kubernetes/docker
etcd_data=/data/kubernetes/etcd
containerd_data="/data/kubernetes/containerd"
#https://github.com/containerd/nerdctl/releases
nerdctl_full_version=2.1.4
#https://mirrors.ustc.edu.cn/docker-ce/linux/static/stable/x86_64/
docker_version=28.1.1
#https://github.com/kubernetes/kubernetes/releases
k8s_version=v1.34.0
#kubernetes_server_version=1.29.2
#https://github.com/lework/skopeo-binary/releases
skopeo_version=v1.18.0
#https://github.com/cilium/hubble/releases
hubble_version=v1.17.3
#https://github.com/vmware-tanzu/velero/releases
velero_version=v1.16.0
#https://github.com/cilium/cilium/releases
cilium_version=v1.17.4
#https://github.com/cilium/cilium-cli/releases
cilium_cli_version=v0.18.3
#https://github.com/docker/compose/releases
docker_compose_version=v2.36.0
#https://github.com/kubernetes-sigs/cri-tools/releases
crictl_version=v1.33.0
#https://github.com/cloudflare/cfssl/releases
cfssl_version=1.6.5
#https://github.com/etcd-io/etcd/releases
etcd_version=v3.6.0
#https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
#https://github.com/helm/helm/releases
helm_version=3.17.3
#https://github.com/gojue/ecapture/releases
ecapture_version=v1.0.2
#https://github.com/mozillazg/ptcpdump/releases
ptcpdump_version=0.33.2
#https://github.com/projectcalico/calico/releases
calico_version=v3.30.0
#https://github.com/kubernetes-sigs/gateway-api/releases/
gateway_api_version=v1.3.0
#https://github.com/docker/buildx/releases
docker_buildx_version="v0.23.0"
#https://github.com/cri-o/cri-o/releases#downloads
crio_version=1.33.4
cri_docker_version=0.3.20


# 导入其他脚本文件
source ./functions/init_workdir.sh
source ./functions/install_base_packages.sh
source ./functions/setup_network_hostname.sh
source ./functions/setup_nfs.sh
source ./functions/setup_download_urls.sh
source ./functions/download_packages.sh
source ./functions/install_crio.sh
source ./functions/install_containerd_components.sh
source ./functions/install_docker.sh
source ./functions/init_system.sh
source ./functions/install_k8s_components.sh
source ./functions/init_k8s_cluster.sh
source ./functions/deploy_cni_and_components.sh

# 主函数
main() {
  init_workdir
  install_base_packages
  setup_network_hostname
  setup_nfs
  setup_download_urls
  download_packages
  if [ "${runtime}" == "containerd" ];then
    install_containerd_components
  elif [ "${runtime}" == "docker" ];then
    install_docker
  elif [ "${runtime}" == "crio" ];then
    install_crio
  fi
  init_system
  install_k8s_components
  init_k8s_cluster
  deploy_cni_and_components
}

# 执行主函数
main