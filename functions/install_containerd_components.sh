#!/bin/bash

#--------安装containerd相关组件----------
install_containerd_components() {
  echo "Installing containerd components..."
  
  if [ ! -f "nerdctl-full-${nerdctl_full_version}-linux-${ARCH}.tar.gz" ]; then
    echo "nerdctl package not found, skipping containerd installation"
    exit 1
  fi

  mkdir -p /usr/local/bin
  tar -zxvf "nerdctl-full-${nerdctl_full_version}-linux-${ARCH}.tar.gz" -C /usr/local/
  mkdir -p /etc/systemd/system/
  /bin/cp /usr/local/lib/systemd/system/*.service /etc/systemd/system/
  mkdir -p /opt/cni/bin
  /bin/cp /usr/local/libexec/cni/* /opt/cni/bin/

  systemctl enable buildkit containerd
  systemctl start buildkit containerd 
  if [ $? -ne 0 ];then
    echo "containerd service start failed"
    exit 1
  fi

  echo "source <(nerdctl completion bash)" >> ~/.bashrc
  mkdir -p /etc/nerdctl/
  tee /etc/nerdctl/nerdctl.toml <<EOF
debug             = false
debug_full        = false
address           = "unix:///var/run/containerd/containerd.sock"
namespace         = "k8s.io"
snapshotter       = "overlayfs"
cni_path          = "/opt/cni/bin"
cni_netconfpath   = "/etc/cni/net.d"
cgroup_manager    = "systemd"
insecure_registry = true
hosts_dir         = ["/etc/containerd/certs.d"]
EOF

  mkdir -p /etc/containerd/
  containerd config default > /etc/containerd/config.toml
  sed -i 's/SystemdCgroup\ =\ false/SystemdCgroup\ =\ true/g' /etc/containerd/config.toml
  if [ "$zone" == "cn" ];then
    sed -i 's|sandbox_image = "registry.k8s.io/pause:3.9"|sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9"|g' /etc/containerd/config.toml
  else
    echo "not in china"
  fi
  sed -i "s#/var/lib/containerd#$containerd_data#g" /etc/containerd/config.toml

  # 镜像加速配置
  setup_containerd_registry_mirrors

  systemctl restart containerd 
  if [ $? -ne 0 ];then
    echo "containerd service restart failed"
    exit 1
  fi
  
  echo "Containerd components installed."
}

# 配置containerd镜像仓库加速
setup_containerd_registry_mirrors() {
  echo "Setting up containerd registry mirrors..."
  
  # docker hub镜像加速
  mkdir -p /etc/containerd/certs.d/docker.io
  cat > /etc/containerd/certs.d/docker.io/hosts.toml << EOF
server = "https://docker.io"
[host."https://docker.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]

[host."https://reg-mirror.qiniu.com"]
  capabilities = ["pull", "resolve", "push"]

[host."https://dockerhub.icu"]
  capabilities = ["pull", "resolve", "push"]
  
EOF

  # registry.k8s.io镜像加速
  mkdir -p /etc/containerd/certs.d/registry.k8s.io
  tee /etc/containerd/certs.d/registry.k8s.io/hosts.toml << 'EOF'
server = "https://registry.k8s.io"

[host."https://k8s.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # docker.elastic.co镜像加速
  mkdir -p /etc/containerd/certs.d/docker.elastic.co
  tee /etc/containerd/certs.d/docker.elastic.co/hosts.toml << 'EOF'
server = "https://docker.elastic.co"

[host."https://elastic.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # gcr.io镜像加速
  mkdir -p /etc/containerd/certs.d/gcr.io
  tee /etc/containerd/certs.d/gcr.io/hosts.toml << 'EOF'
server = "https://gcr.io"

[host."https://gcr.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # ghcr.io镜像加速
  mkdir -p /etc/containerd/certs.d/ghcr.io
  tee /etc/containerd/certs.d/ghcr.io/hosts.toml << 'EOF'
server = "https://ghcr.io"

[host."https://ghcr.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # k8s.gcr.io镜像加速
  mkdir -p /etc/containerd/certs.d/k8s.gcr.io
  tee /etc/containerd/certs.d/k8s.gcr.io/hosts.toml << 'EOF'
server = "https://k8s.gcr.io"

[host."https://k8s-gcr.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # mcr.m.daocloud.io镜像加速
  mkdir -p /etc/containerd/certs.d/mcr.microsoft.com
  tee /etc/containerd/certs.d/mcr.microsoft.com/hosts.toml << 'EOF'
server = "https://mcr.microsoft.com"

[host."https://mcr.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # nvcr.io镜像加速
  mkdir -p /etc/containerd/certs.d/nvcr.io
  tee /etc/containerd/certs.d/nvcr.io/hosts.toml << 'EOF'
server = "https://nvcr.io"

[host."https://nvcr.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # quay.io镜像加速
  mkdir -p /etc/containerd/certs.d/quay.io
  tee /etc/containerd/certs.d/quay.io/hosts.toml << 'EOF'
server = "https://quay.io"

[host."https://quay.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # registry.jujucharms.com镜像加速
  mkdir -p /etc/containerd/certs.d/registry.jujucharms.com
  tee /etc/containerd/certs.d/registry.jujucharms.com/hosts.toml << 'EOF'
server = "https://registry.jujucharms.com"

[host."https://jujucharms.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  # rocks.canonical.com镜像加速
  mkdir -p /etc/containerd/certs.d/rocks.canonical.com
  tee /etc/containerd/certs.d/rocks.canonical.com/hosts.toml << 'EOF'
server = "https://rocks.canonical.com"

[host."https://rocks-canonical.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

  #自定义仓库
  mkdir -p /etc/containerd/certs.d/registry.cn-hangzhou.aliyuncs.com
  tee /etc/containerd/certs.d/registry.cn-hangzhou.aliyuncs.com/hosts.toml << 'EOF'
server = "https://registry.cn-hangzhou.aliyuncs.com"

[host."https://registry.cn-hangzhou.aliyuncs.com"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF

  mkdir -p /etc/containerd/certs.d/registry.fangcloud.net:30500
  tee /etc/containerd/certs.d/registry.fangcloud.net:30500/hosts.toml << 'EOF'
server = "https://registry.fangcloud.net:30500"

[host."https://registry.fangcloud.net:30500"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF

  mkdir -p /etc/containerd/certs.d/internal-registry.fangcloud.net
  tee /etc/containerd/certs.d/internal-registry.fangcloud.net/hosts.toml << 'EOF'
server = "https://internal-registry.fangcloud.net"

[host."https://internal-registry.fangcloud.net"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF
  
  echo "Containerd registry mirrors configured."
}