#!/bin/bash

#-----大陆区下载----------------
setup_download_urls() {
  echo "Setting up download URLs..."
  
  docker_url="https://download.docker.com/linux/static/stable/${arch}/docker-${docker_version}.tgz"
  nerdctl_full_url="https://github.com/containerd/nerdctl/releases/download/v${nerdctl_full_version}/nerdctl-full-${nerdctl_full_version}-linux-$ARCH.tar.gz"
  kubernetes_server_url="https://dl.k8s.io/release/${k8s_version}/kubernetes-server-linux-${ARCH}.tar.gz"
  skopeo_url="https://github.com/lework/skopeo-binary/releases/download/${skopeo_version}/skopeo-linux-${ARCH}"
  cilium_url="https://github.com/cilium/cilium-cli/releases/download/${cilium_cli_version}/cilium-linux-${ARCH}.tar.gz"
  hubble_url="https://github.com/cilium/hubble/releases/download/${hubble_version}/hubble-linux-${ARCH}.tar.gz"
  velero_url="https://github.com/vmware-tanzu/velero/releases/download/${velero_version}/velero-${velero_version}-linux-${ARCH}.tar.gz"
  etcd_url="https://github.com/etcd-io/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-${ARCH}.tar.gz"
  cfssl_url="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssl_${cfssl_version}_linux_${ARCH}"
  cfssljson_url="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssljson_${cfssl_version}_linux_${ARCH}"
  cfssl_certinfo="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssl-certinfo_${cfssl_version}_linux_${ARCH}"
  docker_compose_url="https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-linux-${arch}"
  crictl_url="https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-$ARCH.tar.gz"
  ecapture_url="https://github.com/gojue/ecapture/releases/download/${ecapture_version}/ecapture-${ecapture_version}-linux-${ARCH}.tar.gz"
  pcpdump_url="https://github.com/mozillazg/ptcpdump/releases/download/v${ptcpdump_version}/ptcpdump_${ptcpdump_version}_linux_${ARCH}.tar.gz"
  calico_url="https://github.com/projectcalico/calico/releases/download/${calico_version}/calicoctl-linux-${ARCH}"
  docker_buildx_url="https://github.com/docker/buildx/releases/download/${docker_buildx_version}/buildx-${docker_buildx_version}.linux-${ARCH}"
  crio_url="https://storage.googleapis.com/cri-o/artifacts/cri-o.${ARCH}.v${crio_version}.tar.gz"
  cri_docker_url="https://github.com/Mirantis/cri-dockerd/releases/download/v${cri_docker_version}/cri-dockerd-${cri_docker_version}.${ARCH}.tgz"
  
  echo "Download URLs setup completed."
}