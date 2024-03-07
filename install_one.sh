#!/bin/bash
set -x
mkdir -p /data/software
cd /data/software
#-----------变量配置--------------
nfs_path=/data/k8s/nfs
nerdctl_full_version=1.7.4
docker_version=25.0.3
k8s_version=v1.29.2
docker_compose_version='v2.24.6'
CRICTL_VERSION="v1.29.0"
ARCH="amd64"
DOWNLOAD_DIR="/usr/local/bin"
RELEASE_VERSION="v0.15.1"
helm_version='3.14.1'
local_ip=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}' | awk 'NR==1{print}')
#---------------------------------

hostnamectl set-hostname master1
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
  )

  for i in ${packages[@]};do
      yum install $i  --skip-broken -y
  done
else 
    systemctl stop firewalld
    systemctl disable firewalld
    packages=(
    wget
    vim
    conntrack
    socat
    ipvsadm
    ipset
    telnet
    bind-utils
    nfs-utils
    unzip
    bash-completion
    tcpdump
    mtr
    nftables
    iproute-tc
  )

  for i in ${packages[@]};do
      yum install $i  --skip-broken -y
  done
fi
#---------------------------------

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
  systemctl enable rpcbind --now
  systemctl enable nfs-server
  systemctl start nfs-server
fi
showmount -e localhost
#--------安装k8s相关组件----------

wget --no-check-certificate https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubelet
wget --no-check-certificate https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubectl
wget --no-check-certificate https://dl.k8s.io/release/${k8s_version}/bin/linux/amd64/kubeadm
/bin/cp kube* /usr/local/bin/
chmod +x /usr/local/bin/kube*
wget https://github.com/containerd/nerdctl/releases/download/v${nerdctl_full_version}/nerdctl-full-${nerdctl_full_version}-linux-amd64.tar.gz
tar zxvf nerdctl-full-${nerdctl_full_version}-linux-amd64.tar.gz -C /usr/local/
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
mkdir -p /etc/containerd/
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup\ =\ false/SystemdCgroup\ =\ true/g' /etc/containerd/config.toml
systemctl restart containerd 
if [ $? -ne 0 ];then
  echo "containerd service restart failed"
  exit 1
fi




wget https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-linux-x86_64
/bin/cp docker-compose-linux-x86_64 /usr/local/bin/docker-compose
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
if [ $? -ne 0 ];then
  echo "docker service start failed"
  exit 1
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



sudo mkdir -p "$DOWNLOAD_DIR"

curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" |tar -C $DOWNLOAD_DIR -xz

#RELEASE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"


#sudo curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}



curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service
sudo mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
wget https://get.helm.sh/helm-v${helm_version}-linux-amd64.tar.gz
tar -zxvf helm-v${helm_version}-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/

systemctl enable --now kubelet
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(helm completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc

kubeadm config print init-defaults > kubeadm-init.yaml
kubeadm config print join-defaults > kubeadm-join.yaml

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




tee kubeadm-${k8s_version}-init.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
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
---
apiServer:
  timeoutForControlPlane: 4m0s
  extraArgs:
    default-not-ready-toleration-seconds: "300"
    default-unreachable-toleration-seconds: "300"
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager:
  extraArgs:
    node-cidr-mask-size-ipv4: "24"
  certSANs:
    - vip.cluster.local
    - 127.0.0.1
  extraVolumes:
  - name: timezone
    hostPath: /etc/localtime
    mountPath: /etc/localtime
    readOnly: true
dns: {}
etcd:
  local:
    dataDir: /data/etcd
    extraArgs:
      quota-backend-bytes: "32768000000"
      auto-compaction-mode: periodic
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: 1.29.2
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
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
clusterDNS:
- 10.96.0.10
cgroupDriver: systemd
EOF

kubeadm init --config kubeadm-${k8s_version}-init.yaml --upload-certs

if [ $? -ne 0 ];then
  echo "failed"
  exit 1
else
  mkdir -p $HOME/.kube
  sudo /bin/cp  /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi

kubectl taint node master node-role.kubernetes.io/control-plane:NoSchedule-

helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium --namespace=kube-system  --version 1.15.1 \
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
  --set hubble.metrics.enabled="{dns:query;ignoreAAAA,drop,tcp,flow,icmp,http}" \
  --set ingressController.enabled=true \
  --set debug.enabled=true \
  --set operator.replicas=1 \
  --set bpf.masquerade=true \
  --set autoDirectNodeRoutes=true

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

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/experimental-install.yaml

helm upgrade --install nfs-subdir-external-provisioner ./nfs-subdir-external-provisioner --namespace=environment --create-namespace \
    --set nfs.server="${local_ip}" \
    --set nfs.path="${nfs_path}" \
    --set storageClass.name=nfs-client \
    --set-string nfs.mountOptions={"soft,timeo=600,intr,retry=5,retrans=2,proto=tcp,vers=3"} \
    --set storageClass.defaultClass=true