#!/bin/bash
set -x
arch=`arch`
if [ "$arch" == "x86_64" ];then
  ARCH=amd64
elif [ "$arch" == "aarch64" ];then
  ARCH=aarch64
else
  echo "this arch is not unsupport"
  exit 1
fi
mkdir -p /data/software
cd /data/software
#-----------变量配置--------------
nfs_path=/data/k8s/nfs
docker_data_root=/data/kubernetes/docker
etcd_data=/data/kubernetes/etcd
containerd_data="/data/kubernetes/containerd"
#https://github.com/containerd/nerdctl/releases
nerdctl_full_version=2.1.1
#https://mirrors.ustc.edu.cn/docker-ce/linux/static/stable/x86_64/
docker_version=28.1.1
#https://github.com/kubernetes/kubernetes/releases
k8s_version=v1.33.0
#kubernetes_server_version=1.29.2
#https://github.com/lework/skopeo-binary/releases
skopeo_version=v1.18.0
#https://github.com/cilium/hubble/releases
hubble_version=v1.17.3
#https://github.com/vmware-tanzu/velero/releases
velero_version=v1.16.1
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
pcpdump_version=0.33.2
#https://github.com/projectcalico/calico/releases
calico_version=v3.30.0
#https://github.com/kubernetes-sigs/gateway-api/releases/
gateway_api_version=v1.3.0
#https://github.com/docker/buildx/releases
docker_buildx_version="v0.23.0"


bin_dir=/usr/bin
cni_type=calico
base_url=https://ghfast.top



#-----------------安装基础软件包------------
if [ -f /etc/debian_version ]; then
  systemctl stop ufw
  systemctl disable ufw
  apt update
   packages=(
    wget
    vim
    conntrack
    socat
    ipvsadm
    ipset
    telnet
    dnsutils
    nfs-kernel-server
    nfs-common
    unzip
    bash-completion
    tcpdump
    mtr
    nftables
    iproute-tc
    iptables
    curl
    git
    lsof
    iputils-ping
    iproute2
    net-tools
  )
  for i in ${packages[@]};do
      apt install $i   -y
  done
elif [ -f /etc/redhat-release ]; then
  systemctl stop firewalld
  systemctl disable firewalld
  packages=(
    wget
    vim
    conntrack
    socat
    ipvsadm
    ipset
    nmap
    telnet
    bind-utils
    nfs-utils
    unzip
    bash-completion
    tcpdump
    mtr
    nftables
    iproute-tc
    lsof
    git 
  )

  for i in ${packages[@]};do
      yum install $i  --skip-broken -y
  done
else
  echo "this os is not support"
  exit 1
fi
#---------------------------------


# 获取具有默认路由的网卡名称
DEFAULT_INTERFACE=$(ip route show default | awk '/default/ {print $5}')
# 检查是否成功获取到网卡名称
if [ -z "$DEFAULT_INTERFACE" ]; then
  echo "无法获取具有默认路由的网卡名称"
  exit 1
fi
# 获取该网卡的 IP 地址
IP_ADDRESS=$(ip addr show $DEFAULT_INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

# 检查是否成功获取到 IP 地址
if [ -z "$IP_ADDRESS" ]; then
  echo "无法获取 IP 地址"
  exit 1
fi

local_ip=$IP_ADDRESS
# 获取旧主机名
OLD_HOSTNAME=$(hostname)
# 将 IP 地址中的点替换为破折号
HOSTNAME="k8s-$(echo $IP_ADDRESS | tr '.' '-')"
# 设置主机名
hostnamectl set-hostname "$HOSTNAME"
# 更新 /etc/hosts 文件
echo "更新 /etc/hosts 文件..."
# 备份hosts文件
cp /etc/hosts /etc/hosts.bak
# 更新 hosts 文件，保留原有内容
sed -i "s/\b${OLD_HOSTNAME}\b/${HOSTNAME}/g" /etc/hosts

# 输出新的主机名
echo "新的主机名已设置为: $HOSTNAME"

#--------安装nfs相关组件----------

mkdir -p ${nfs_path}
chmod -R 777 ${nfs_path}
echo "${nfs_path} *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee -a /etc/exports
exportfs -ra
if [ -f /etc/debian_version ]; then
  systemctl enable nfs-kernel-server
  systemctl restart nfs-kernel-server

elif [ -f /etc/redhat-release ]; then
  systemctl enable rpcbind --now
  systemctl enable nfs-server
  systemctl start nfs-server
else
  echo "this os is not support"
  exit 1
fi
showmount -e localhost

#-----大陆区下载----------------
docker_url="https://mirrors.ustc.edu.cn/docker-ce/linux/static/stable/${arch}/docker-${docker_version}.tgz"
nerdctl_full_url="https://github.com/containerd/nerdctl/releases/download/v${nerdctl_full_version}/nerdctl-full-${nerdctl_full_version}-linux-$ARCH.tar.gz"
kubernetes_server_url="https://dl.k8s.io/release/${k8s_version}/kubernetes-server-linux-${ARCH}.tar.gz"
skopeo_url="https://github.com/lework/skopeo-binary/releases/download/${skopeo_version}/skopeo-linux-${ARCH}"
cilium_url="https://github.com/cilium/cilium-cli/releases/download/${cilium_version}/cilium-linux-${ARCH}.tar.gz"
hubble_url="https://github.com/cilium/hubble/releases/download/${hubble_version}/hubble-linux-${ARCH}.tar.gz"
velero_url="https://github.com/vmware-tanzu/velero/releases/download/${velero_version}/velero-${velero_version}-linux-${ARCH}.tar.gz"
etcd_url="https://github.com/etcd-io/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-${ARCH}.tar.gz"
cfssl_url="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssl_${cfssl_version}_linux_${ARCH}"
cfssljson_url="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssljson_${cfssl_version}_linux_${ARCH}"
cfssl_certinfo="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssl-certinfo_${cfssl_version}_linux_${ARCH}"
docker_compose_url="https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-linux-${arch}"
crictl_url="https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-$ARCH.tar.gz"
ecapture_url="https://github.com/gojue/ecapture/releases/download/${ecapture_version}/ecapture-${ecapture_version}-linux-${ARCH}.tar.gz"
pcpdump_url="https://github.com/mozillazg/ptcpdump/releases/download/v${pcpdump_version}/ptcpdump_${ptcpdump_version}_linux_${ARCH}.tar.gz"
calico_url="https://github.com/projectcalico/calico/releases/download/${calico_version}/calicoctl-linux-${ARCH}"
docker_buildx_url="https://github.com/docker/buildx/releases/download/${docker_buildx_version}/buildx-${docker_buildx_version}.linux-${ARCH}"


if [ -f "docker-${docker_version}.tgz" ];then 
  echo "docker-${docker_version}.tgz is existed"
else
  curl  -k -L -C - -o docker-${docker_version}.tgz ${docker_url}
fi
if [ -f "kubernetes-server-linux-${ARCH}.tar.gz" ];then
  echo "kubernetes-server-linux-${ARCH}.tar.gz is existed"
else
  curl -sSfL -o kubernetes-server-linux-${ARCH}.tar.gz ${kubernetes_server_url}
fi
packages=(
  $nerdctl_full_url
  $crictl_url
  $etcd_url
  $cfssl_url
  $cfssljson_url
  $cfssl_certinfo
  $docker_compose_url
  $cilium_url
  $hubble_url
  $velero_url
  $skopeo_url
  $ecapture_url
  $pcpdump_url
  $calico_url
)

if [ $zone == "cn" ];then
 
  for package_url in "${packages[@]}"; do
    filename=$(basename "$package_url")
    if [ ! -f "$filename" ];then
      curl  -k -L -C - -o "$filename" ${base_url}/"$package_url"
      echo "Downloaded $filename"
    else
      echo "$filename is existed"
    fi
  done
else
  for package_url in "${packages[@]}"; do
    filename=$(basename "$package_url") 
    if [ ! -f "$filename" ];then
      curl  -k -L -C - -o "$filename" "$package_url"
      echo "Downloaded $filename"
    else
      echo "$filename is existed"
    fi
  done
fi


#--------安装containerd相关组件----------
if [ -f "cilium-linux-${ARCH}.tar.gz" ];then
  tar -zxvf cilium-linux-${ARCH}.tar.gz -C ${bin_dir}
fi
if [ -f "hubble-linux-${ARCH}.tar.gz" ];then
  tar -zxvf hubble-linux-${ARCH}.tar.gz -C ${bin_dir}
fi
if [ -f "ecapture-${ecapture_version}-linux-${ARCH}.tar.gz" ];then
  tar -zxvf ecapture-${ecapture_version}-linux-${ARCH}.tar.gz
  /bin/cp ecapture-${ecapture_version}-linux-${ARCH} ${bin_dir}/ecapture  
fi
if [ -f "ptcpdump-${pcpdump_version}-linux-${ARCH}.tar.gz" ];then
  tar -zxvf ptcpdump-${pcpdump_version}-linux-${ARCH}.tar.gz
  /bin/cp ptcpdump ${bin_dir}/ptcpdump
fi
if [ -f "calicoctl-linux-${ARCH}.tar.gz" ];then
  tar -zxvf calicoctl-linux-${ARCH}.tar.gz
  /bin/cp calicoctl-linux-${ARCH} ${bin_dir}/calicoctl
fi
if [ -f "skopeo-linux-${ARCH}.tar.gz" ];then
  tar -zxvf skopeo-linux-${ARCH}.tar.gz
  /bin/cp skopeo-linux-${ARCH} ${bin_dir}/skopeo
fi
chmod +x ${bin_dir}/{cilium,hubble,skopeo,ecapture,ptcpdump,calicoctl}

/bin/cp cfssl_${cfssl_version}_linux_${ARCH}  ${bin_dir}/cfssl
/bin/cp cfssl-certinfo_${cfssl_version}_linux_${ARCH}  ${bin_dir}/cfssl-certinfo
/bin/cp cfssljson_${cfssl_version}_linux_${ARCH}  ${bin_dir}/cfssljson

chmod +x ${bin_dir}/{cfssl,cfssl-certinfo,cfssljson}

tar -zxvf etcd-${etcd_version}-linux-${ARCH}.tar.gz -C ${bin_dir} --strip-components=1

chmod +x ${bin_dir}/etcd*

mkdir -p /usr/local/bin
tar -zxvf nerdctl-full-${nerdctl_full_version}-linux-${ARCH}.tar.gz -C /usr/local/
/bin/cp /usr/local/lib/systemd/system/*.service /etc/systemd/system/
mkdir -p /opt/cni/bin
/bin/cp /usr/local/libexec/cni/* /opt/cni/bin/
#sed -i "s@/usr/local/bin@${bin_dir}@g" /etc/systemd/system/buildkit.service
#sed -i "s@/usr/local/bin@${bin_dir}@g" /etc/systemd/system/containerd.service

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
sed -i  's|sandbox_image = "registry.k8s.io/pause:3.10"|sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.10"|g' /etc/containerd/config.toml
sed -i "s#/var/lib/containerd#$containerd_data#g" /etc/containerd/config.toml



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



systemctl restart containerd 
if [ $? -ne 0 ];then
  echo "containerd service restart failed"
  exit 1
fi

/bin/cp docker-compose-linux-x86_64 ${bin_dir}/docker-compose
chmod +x ${bin_dir}/docker-compose

#-------安装docker相关组件----------
tar -zxvf docker-${docker_version}.tgz 
/bin/cp docker/docker* ${bin_dir}/

mkdir -p /usr/lib/systemd/system
cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=${bin_dir}/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
[Install]
WantedBy=multi-user.target
EOF

mkdir /etc/docker
tee /etc/docker/daemon.json <<-'EOF'
 {
    "exec-opts": ["native.cgroupdriver=systemd"],
    "insecure-registries" : ["registry.mydomain.com:5000"],
    "log-driver": "json-file",
    "data-root": "${docker_data_root}",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    },
    "bip": "169.254.123.1/24",
    "registry-mirrors": ["https://xbrfpgqk.mirror.aliyuncs.com","https://docker.gh-proxy.com"],
    "live-restore": true
}
EOF
sed -i "s|\${docker_data_root}|$docker_data_root|g" /etc/docker/daemon.json
systemctl enable docker --now
if [ $? -ne 0 ];then
  echo "docker service start failed"
  exit 1
fi

if [ ! -f /usr/lib/docker/cli-plugins/docker-buildx ];then
   if [ "$zone" == "cn" ];then
     curl -fSL ${base_url}/${docker_buildx_url} -o /usr/lib/docker/cli-plugins/docker-buildx
   else
     curl -fSL ${docker_buildx_url} -o /usr/lib/docker/cli-plugins/docker-buildx
   fi
   chmod +x /usr/lib/docker/cli-plugins/docker-buildx
else
  echo "/usr/lib/docker/cli-plugins/docker-buildx is existed"
fi

docker completion bash > /etc/profile.d/docker.sh
#source /etc/profile.d/docker.sh 


echo "source <(crictl completion bash)" >> ~/.bashrc
#source  ~/.bashrc
echo "runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:////var/run/containerd/containerd.sock
#runtime-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
#debug: true"  > /etc/crictl.yaml


#-----系统初始化----------

sed -i 's/.*swap.*/#&/' /etc/fstab
swapoff -a && sysctl -w vm.swappiness=0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

tee /etc/modules-load.d/10-k8s-modules.conf <<EOF
sunrpc
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
ip_vs_lc
overlay
br_netfilter
nf_conntrack
nf_nat
xt_REDIRECT
xt_owner
iptable_nat
iptable_mangle
iptable_filter
ip_tables
ip_set
xt_set
ipt_set
ipt_rpfilter
ipt_REJECT
ipip
EOF
systemctl restart systemd-modules-load

tee /etc/sysctl.d/95-k8s-sysctl.conf <<EOF
vm.swappiness = 0
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.ipv4.ip_forward = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 0
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-arptables = 1
net.core.somaxconn = 32768
net.netfilter.nf_conntrack_max = 524288
fs.nr_open = 6553600
fs.file-max = 6553600
vm.max_map_count = 655360
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
vm.overcommit_memory = 1
kernel.panic = 10
kernel.panic_on_oops = 1
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 1048576
fs.inotify.max_queued_events = 1048576
fs.pipe-user-pages-soft=102400
EOF
sysctl -p /etc/sysctl.d/95-k8s-sysctl.conf


##-------安装k8s相关组件----------
tar -zxvf crictl-${crictl_version}-linux-${ARCH}.tar.gz -C ${bin_dir}
chmod +x ${bin_dir}/crictl
tar -zxvf kubernetes-server-linux-${ARCH}.tar.gz
/bin/cp kubernetes/server/bin/{kubelet,kubectl,kubeadm} $bin_dir/
chmod +x $bin_dir/{kubeadm,kubelet,kubectl}

tee /etc/systemd/system/kubelet.service <<EOF
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=${bin_dir}/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF


mkdir -p /etc/systemd/system/kubelet.service.d
tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf <<EOF
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=${bin_dir}/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
EOF

curl -sSL -o helm-v${helm_version}-linux-${ARCH}.tar.gz "https://mirrors.huaweicloud.com/helm/v${helm_version}/helm-v${helm_version}-linux-${ARCH}.tar.gz"
tar -zxvf helm-v${helm_version}-linux-${ARCH}.tar.gz
cp linux-${ARCH}/helm ${bin_dir}/

systemctl enable --now kubelet
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(helm completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc

kubeadm config print init-defaults > kubeadm-init.yaml
kubeadm config print join-defaults > kubeadm-join.yaml


tee kubeadm-${k8s_version}-init.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
certificateKey: 24dd608dcf62f3040e5ec3df4903739f02506f1b5bf1010e6167a8da9f8e569b
localAPIEndpoint:
  advertiseAddress: ${local_ip}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: master
  taints: null
skipPhases:
  - addon/nginx-proxy
---
apiServer:
  timeoutForControlPlane: 4m0s
  certSANs:
    - vip.cluster.local
    - 127.0.0.1
  extraArgs:
    - name: default-not-ready-toleration-seconds
      value: "300"
    - name: default-unreachable-toleration-seconds
      value: "300"
apiVersion: kubeadm.k8s.io/v1beta4
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager:
  extraArgs:
    - name: node-cidr-mask-size-ipv4
      value: "24"
  extraVolumes:
  - name: timezone
    hostPath: /etc/localtime
    mountPath: /etc/localtime
    readOnly: true
dns: {}
etcd:
  local:
    dataDir: ${etcd_data}
    extraArgs:
      - name: quota-backend-bytes
        value: "32768000000"
      - name: auto-compaction-mode
        value: periodic
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: ${k8s_version}
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: "10.244.0.0/16"
scheduler: 
  extraVolumes:
  - name: timezone
    hostPath: /etc/localtime
    mountPath: /etc/localtime
    readOnly: true
controlPlaneEndpoint: ${local_ip}:6443
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
---
apiVersion: kubelet.config.k8s.io/v1
kind: KubeletConfiguration
serializeImagePulls: false
containerLogMaxSize: 100Mi
containerLogMaxFiles: 10
cpuManagerPolicy: none
maxPods: 128
podPidsLimit: 16384
clusterDNS:
- 10.96.0.10
cgroupDriver: systemd
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
imageServiceEndpoint: unix:///var/run/containerd/containerd.sock
cpuManagerPolicy: None
evictionHard:
  imagefs.available: 15%
  memory.available: 300Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
systemReserved:
    cpu: 100m
    memory: 100Mi
    pid: "1000"
kubeReserved:
    cpu: 100m
    memory: 100Mi
    pid: "1000"
EOF


tee kubeadm-join-node.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken: 
    apiServerEndpoint: ${master_ip}:6443
    token: abcdef.0123456789abcdef
    unsafeSkipCAVerification: true
  timeout: 5m0s
  tlsBootstrapToken: abcdef.0123456789abcdef
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cgroup-driver: systemd
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  taints: null
EOF



if [ "$zone" == "cn" ];then
  sed -i 's|imageRepository: registry.k8s.io|imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers|g' kubeadm-${k8s_version}-init.yaml
fi

if [ "$role" == "node" ];then
  kubeadm join --config kubeadm-join-node.yaml --v 5
else
  kubeadm init --config kubeadm-${k8s_version}-init.yaml --upload-certs --v 5
fi


if [ $? -ne 0 ];then
  echo "failed"
  exit 1
else
  mkdir -p $HOME/.kube
  sudo /bin/cp  /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi

if [ "$role" == "node" ];then
  echo "this is node"
else
  echo "this is master"
  
  kubectl taint node master node-role.kubernetes.io/control-plane:NoSchedule-
  if [ "$zone" == "cn" ];then
    kubectl apply -f ${base_url}/https://github.com/kubernetes-sigs/gateway-api/releases/download/${gateway_api_version}/experimental-install.yaml
  else
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${gateway_api_version}/experimental-install.yaml
  fi
  helm repo add cilium https://helm.cilium.io/
  helm repo update
  if [ "$cni_type" == "cilium" ];then
    helm upgrade --install cilium cilium/cilium --namespace=kube-system  --version 1.17.3 \
      --set routingMode=native \
      --set kubeProxyReplacement=strict \
      --set bandwidthManager.enabled=true \
      --set ipam.mode=kubernetes \
      --set k8sServiceHost=${local_ip} \
      --set k8sServicePort=6443 \
      --set ipv4NativeRoutingCIDR=10.244.0.0/16 \
      --set operate.pprof=true \
      --set operate.prometheus.enabled=true \
      --set prometheus.enabled=true \
      --set pprof.enabled=true \
      --set nodePort.enabled=true \
      --set monitor.enabled=true \
      --set hubble.relay.enabled=true \
      --set hubble.relay.prometheus.enabled=true \
      --set hubble.relay.pprof.enabled=true \
      --set hubble.ui.enabled=true \
      --set hubble.ui.service.type=NodePort \
      --set hubble.metrics.enabled="{dns:query;ignoreAAAA,drop,tcp,flow,icmp,http}" \
      --set hubble.metrics.dashboards.enabled=true \
      --set ingressController.enabled=true \
      --set ingressController.service.type=NodePort \
      --set debug.enabled=true \
      --set operator.replicas=1 \
      --set bpf.masquerade=true \
      --set autoDirectNodeRoutes=true \
      --set gatewayAPI.enabled=true \
      --set l2announcements.enabled=true \
      --set loadBalancer.mode=dsr
  elif [ "$cni_type" == "flannel" ];then
    if [ "$zone" == "cn" ];then
      kubectl apply -f ${base_url}/https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    else
      kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    fi
  elif [ "$cni_type" == "calico" ];then
    if [ "$zone" == "cn" ];then
      kubectl apply -f ${base_url}/https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/tigera-operator.yaml
    else
      kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/tigera-operator.yaml
  fi
  if [ $? -ne 0 ];then
    echo "failed"
    exit 1
  fi


  kubectl create deployment net-tools --image long1318737396/net-tools
  kubectl expose deployment net-tools --port 80 --target-port 80 --type NodePort


  helm repo add cilium https://helm.cilium.io/
  helm repo add projectcalico https://docs.tigera.io/calico/charts
  helm repo add apollo https://charts.apolloconfig.com
  helm repo add flannel https://flannel-io.github.io/flannel/
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
  helm repo add grafana https://grafana.github.io/helm-charts
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 
  helm repo add metallb https://metallb.github.io/metallb
  helm repo add minio-operator https://operator.min.io
  helm repo add openebs https://openebs.github.io/charts

  
  curl -fsSL https://addons.kuboard.cn/kuboard/kuboard-static-pod.sh -o kuboard.sh
  bash kuboard.sh
  if [ "$zone" == "cn" ];then
    kubectl apply -f ${base_url}/https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-frr-k8s.yaml
  else
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-frr-k8s.yaml
  fi



  helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace=environment --create-namespace \
    --set nfs.server="${local_ip}" \
    --set nfs.path="${nfs_path}" \
    --set storageClass.name=nfs-client \
    --set-string nfs.mountOptions={"soft,timeo=600,intr,retry=5,retrans=2,proto=tcp,vers=3"} \
    --set storageClass.defaultClass=true


##----对k8s镜像进行替换---------
  if [ "$zone" == "cn" ];then
    kubectl set image  -n environment deployment nfs-subdir-external-provisioner nfs-subdir-external-provisioner=k8s.dockerproxy.com/sig-storage/nfs-subdir-external-provisioner:v4.0.2
    curl -s https://mirror.ghproxy.com/https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml | sed 's|registry.k8s.io|docker.gh-proxy.com|g' | kubectl apply -f -
  else 
    curl -s https://mirror.ghproxy.com/https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml  | kubectl apply -f -
  fi
fi