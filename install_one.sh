mkdir -p /data/software
cd /data/software
version=1.7.4
docker_version=25.0.3
k8s_version=v1.29.2
yum install -y wget 
apt install -y wget
wget --no-check-certificate https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubelet
wget --no-check-certificate https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubectl
wget --no-check-certificate https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubeadm
cp kube* /usr/local/bin/
chmod +x /usr/local/bin/kube*
wget https://github.com/containerd/nerdctl/releases/download/v$version/nerdctl-full-$version-linux-amd64.tar.gz
tar zxvf nerdctl-full-$version-linux-amd64.tar.gz -C /usr/local/
cp /usr/local/lib/systemd/system/*.service /etc/systemd/system/
systemctl enable buildkit containerd 
systemctl start buildkit containerd 
#systemctl status buildkit containerd
echo "source <(nerdctl completion bash)" >> ~/.bashrc
source  ~/.bashrc
mkdir -p /etc/containerd/
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup\ =\ false/SystemdCgroup\ =\ true/g' /etc/containerd/config.toml
systemctl restart containerd 
mkdir -p /opt/cni/bin
cp /usr/local/libexec/cni/* /opt/cni/bin/


wget https://github.com/docker/compose/releases/download/v2.23.2/docker-compose-linux-x86_64
cp docker-compose-linux-x86_64 /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose


wget https://download.docker.com/linux/static/stable/x86_64/docker-${docker_version}.tgz

tar -zxvf docker-${docker_version}.tgz 
cp docker/docker* /usr/local/bin/

sudo cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
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
    "data-root": "/data/docker",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    },
    "bip": "169.254.123.1/24",
    "registry-mirrors": ["https://xbrfpgqk.mirror.aliyuncs.com"],
    "live-restore": true
}
EOF

systemctl enable docker --now
docker completion bash > /etc/profile.d/docker.sh
#source /etc/profile.d/docker.sh 


echo "source <(crictl completion bash)" >> ~/.bashrc
#source  ~/.bashrc
echo "runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:////var/run/containerd/containerd.sock
#runtime-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
#debug: true"  > /etc/crictl.yaml



sed -i 's/.*swap.*/#&/' /etc/fstab
swapoff -a && sysctl -w vm.swappiness=0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
systemctl stop firewalld
systemctl disable firewalld
systemctl stop ufw
systemctl disable ufw

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
# 最大限度使用物理内存
vm.swappiness = 0

# 决定检查一次相邻层记录的有效性的周期。当相邻层记录失效时，将在给它发送数据前，再解析一次。缺省值是60秒。
net.ipv4.neigh.default.gc_stale_time = 120

# see details in https://help.aliyun.com/knowledge_detail/39428.html
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# see details in https://help.aliyun.com/knowledge_detail/41334.html
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2

# 容器要想访问外部网络，需要本地系统的转发支持
net.ipv4.ip_forward = 1

# 访问业务域名时而会出现无法访问或连接超时的情况
# refer to https://www.ziji.work/kubernetes/kubernetes_cannot_accesspod_port.html

net.ipv4.tcp_tw_recycle = 0

net.ipv4.tcp_tw_reuse = 0

# bridge-nf 使得 netfilter 可以对 Linux 网桥上的 IPv4/ARP/IPv6 包过滤。
# 比如，设置net.bridge.bridge-nf-call-iptables＝1后，二层的网桥在转发包时也会被 iptables 的 FORWARD 规则所过滤。
# refer to https://www.qikqiak.com/k8strain/k8s-basic/install/
# 是否在 iptables 链中过滤 IPv4 包
net.bridge.bridge-nf-call-iptables = 1
# 是否在 ip6tables 链中过滤 IPv6 包
net.bridge.bridge-nf-call-ip6tables = 1
# 是否在 arptables 的 FORWARD 中过滤网桥的 ARP 包
net.bridge.bridge-nf-call-arptables = 1

# 定义了系统中每一个端口最大的监听队列的长度,这是个全局的参数,默认值为128
net.core.somaxconn = 32768

# 服务器在访问量很大时，出现网络连接丢包的问题
# 比较现代的系统（Ubuntu 16+, CentOS 7+）里，64 位，16G 内存的机器，
# max 通常默认为 524288，
# bucket 为 131072（在sunrpc.conf文件中修改）。
# 随着内存大小翻倍这 2 个值也翻倍。
# refer to https://testerhome.com/topics/15824
net.netfilter.nf_conntrack_max = 524288

# 单个进程可分配的最大文件数
fs.nr_open = 6553600
# Linux系统级别限制所有用户进程能打开的文件描述符总数
fs.file-max = 6553600

# 每个进程内存拥有的VMA(虚拟内存区域)的数量。虚拟内存区域是一个连续的虚拟地址空间区域。在进程的生命
# 周期中，每当程序尝试在内存中映射文件，链接到共享内存段，或者分配堆空间的时候，这些区域将被创建。
# 进程加载的动态库、分配的内存、mmap的内存都会增加VMA的数量。通常一个进程会有小于1K个VMA，如果进程有
# 特殊逻辑，可能会超过该限制。
# 调优这个值将限制进程可拥有VMA的数量。限制一个进程拥有VMA的总数可能导致应用程序出错，因为当进程达到
# 了VMA上线但又只能释放少量的内存给其他的内核进程使用时，操作系统会抛出内存不足的错误。如果你的操作系
# 统在NORMAL区域仅占用少量的内存，那么调低这个值可以帮助释放内存给内核用。
# refer to https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
# 可以使用命令 cat /proc/${pid}/maps 来查看指定进程拥有的VMA。
vm.max_map_count = 655360

# 修复ipvs模式下长连接timeout问题 小于900即可
# refer to https://github.com/moby/moby/issues/31208 
# ipvsadm -l --timout

net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10


# refer to https://github.com/Azure/aks-engine/blob/d6f4929a659241ea33d8fd4d9fc86d0e27b0cb07/parts/k8s/cloud-init/artifacts/sysctl-d-60-CIS.conf
# refer to https://github.com/kubernetes/kubernetes/blob/75d45bdfc9eeda15fb550e00da662c12d7d37985/pkg/kubelet/cm/container_manager_linux.go#L359-L397
vm.overcommit_memory = 1
kernel.panic = 10
kernel.panic_on_oops = 1

# refer to https://github.com/Azure/AKS/issues/772
fs.inotify.max_user_watches = 1048576

# 指定每个真实用户 ID 可以创建的 inotify 实例数量上限
# 指定 inotify 实例可以排队事件数量的上限
fs.inotify.max_user_instances = 1048576
fs.inotify.max_queued_events = 1048576
fs.pipe-user-pages-soft=102400
EOF
sysctl -p /etc/sysctl.d/95-k8s-sysctl.conf
yum install conntrack socat ipvsadm ipset git telnet bind-utils nmap nfs-utils  bash-completion -y
apt update && apt install iptables conntrack socat ipvsadm ipset git telnet dnsutils nfs-kernel-server bash-completion -y

DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"
CRICTL_VERSION="v1.29.0"
ARCH="amd64"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" |tar -C $DOWNLOAD_DIR -xz

#RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
ARCH="amd64"

#sudo curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}


RELEASE_VERSION="v0.15.1"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
wget https://get.helm.sh/helm-v3.12.3-linux-amd64.tar.gz
tar -zxvf helm-v3.12.3-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/

systemctl enable --now kubelet
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(helm completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc

kubeadm config print init-defaults > kubeadm-init.yaml
kubeadm config print join-defaults > kubeadm-join.yaml
curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o calicoctl
chmod +x calicoctl 
cp calicoctl /usr/local/bin/
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin

HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}