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

# 命令行参数解析
install_docker_flag=false
install_containerd_flag=false
install_crio_flag=false
install_k8s_flag=false

show_help() {
    cat << EOF
Usage: $0 [options]

Options:
  --install-docker       Install Docker only
  --install-containerd   Install Containerd only
  --install-crio         Install CRI-O only
  --install-k8s          Install Kubernetes components and initialize cluster
  -h, --help             Show this help message and exit

Examples:
  $0 --install-docker
  $0 --install-containerd
  $0 --install-crio
  $0 --install-k8s
  $0                     Run full installation (default behavior)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-docker)
                install_docker_flag=true
                shift
                ;;
            --install-containerd)
                install_containerd_flag=true
                shift
                ;;
            --install-crio)
                install_crio_flag=true
                shift
                ;;
            --install-k8s)
                install_k8s_flag=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 0
                ;;
        esac
    done
}

# 分步执行函数
run_full_installation() {
  init_workdir
  install_base_packages
  setup_network_hostname
  setup_nfs
  setup_download_urls
  download_packages
  install_runtime
  init_system
  install_k8s_components
  init_k8s_cluster
  deploy_cni_and_components
}

install_runtime() {
  if [ "${runtime}" == "containerd" ];then
    install_containerd_components
  elif [ "${runtime}" == "docker" ];then
    install_docker
  elif [ "${runtime}" == "crio" ];then
    install_crio
  fi
}

run_docker_installation() {
  init_workdir
  install_base_packages
  setup_download_urls
  download_packages
  install_docker
  init_system
}

run_containerd_installation() {
  init_workdir
  install_base_packages
  setup_download_urls
  download_packages
  install_containerd_components
  init_system
}

run_crio_installation() {
  init_workdir
  install_base_packages
  setup_download_urls
  download_packages
  install_crio
  init_system
}

run_k8s_installation() {
  setup_network_hostname
  setup_nfs
  init_system
  install_k8s_components
  init_k8s_cluster
  deploy_cni_and_components
}

# 主函数
main() {
  parse_args "$@"
  
  if $install_docker_flag; then
    runtime="docker"
    run_docker_installation
  elif $install_containerd_flag; then
    runtime="containerd"
    run_containerd_installation
  elif $install_crio_flag; then
    runtime="crio"
    run_crio_installation
  elif $install_k8s_flag; then
    run_k8s_installation
  else
    # 默认完整安装流程
    run_full_installation
  fi
}

# 执行主函数
main "$@"