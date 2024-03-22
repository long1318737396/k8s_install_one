#!/bin/bash
set -x
mkdir -p /data/software
cd /data/software
#-----------变量配置--------------
nfs_path=/data/k8s/nfs
docker_data_root=/data/docker
etcd_data=/data/etcd
nerdctl_full_version=1.7.4
docker_version=25.0.3
k8s_version=v1.29.2
kubernetes_server_version=1.29.2
skopeo_version=v1.14.2
hubble_version=v0.13.0
velero_version=v1.13.0
cilium_version=v0.15.23
docker_compose_version=v2.24.6
crictl_version=v1.29.0
cfssl_version=1.6.4
etcd_version=v3.5.12
arch=amd64
arch1=x86_64
bin_dir=/usr/local/bin
RELEASE_VERSION=v0.15.1
helm_version=3.14.1
base_url=https://mirror.ghproxy.com
local_ip=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}' | awk 'NR==1{print}')
#---------------------------------
if [ "$role" == "node" ];then
  echo "node"
else
  hostnamectl set-hostname master1
fi
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

#-----大陆区下载----------------
docker_url="https://mirrors.ustc.edu.cn/docker-ce/linux/static/stable/${arch1}/docker-${docker_version}.tgz"
nerdctl_full_url="https://github.com/containerd/nerdctl/releases/download/v${nerdctl_full_version}/nerdctl-full-${nerdctl_full_version}-linux-$arch.tar.gz"
kubernetes_server_url="https://storage.googleapis.com/kubernetes-release/release/v${kubernetes_server_version}/kubernetes-server-linux-${arch}.tar.gz"
skopeo_url="https://github.com/lework/skopeo-binary/releases/download/${skopeo_version}/skopeo-linux-${arch}"
cilium_url="https://github.com/cilium/cilium-cli/releases/download/${cilium_version}/cilium-linux-${arch}.tar.gz"
hubble_url="https://github.com/cilium/hubble/releases/download/${hubble_version}/hubble-linux-${arch}.tar.gz"
velero_url="https://github.com/vmware-tanzu/velero/releases/download/${velero_version}/velero-${velero_version}-linux-${arch}.tar.gz"
etcd_url="https://github.com/etcd-io/etcd/releases/download/${etcd_version}/etcd-${etcd_version}-linux-${arch}.tar.gz"
cfssl_url="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssl_${cfssl_version}_linux_${arch}"
cfssljson_url="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssljson_${cfssl_version}_linux_${arch}"
cfssl_certinfo="https://github.com/cloudflare/cfssl/releases/download/v${cfssl_version}/cfssl-certinfo_${cfssl_version}_linux_${arch}"
docker_compose_url="https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-linux-${arch1}"
crictl_url="https://github.com/kubernetes-sigs/cri-tools/releases/download/${crictl_version}/crictl-${crictl_version}-linux-$arch.tar.gz"

curl  -k -L -C - -o docker-${docker_version}.tgz ${docker_url}
#curl -sSfL -o kubernetes-server-linux-${arch}.tar.gz ${kubernetes_server_url}
curl  -k -L -C - -o kubernetes-server-linux-${arch}.tar.gz https://jefftommy.oss-cn-hangzhou.aliyuncs.com/software/v1.29.2/kubernetes-server-linux-amd64.tar.gz
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
)

if [ $zone == "cn" ];then
 
  for package_url in "${packages[@]}"; do
    filename=$(basename "$package_url")
    if curl  -k -L -C - -o "$filename" ${base_url}/"$package_url"; then
      echo "Downloaded $filename"
    else
      echo "Failed to download $filename"
      exit 1
    fi
  done
else
  for package_url in "${packages[@]}"; do
    filename=$(basename "$package_url")
    if curl  -k -L -C - -o "$filename" "$package_url"; then
      echo "Downloaded $filename"
    else
      echo "Failed to download $filename"
      exit 1
    fi
  done
fi


#--------安装containerd相关组件----------
tar -zxvf cilium-linux-amd64.tar.gz -C /usr/local/bin
tar -zxvf hubble-linux-amd64.tar.gz -C /usr/local/bin
/bin/cp skopeo-linux-amd64 /usr/local/bin/skopeo
chmod +x /usr/local/bin/{cilium,hubble,skopeo}

/bin/cp cfssl_1.6.4_linux_amd64  /usr/local/bin/cfssl
/bin/cp cfssl-certinfo_1.6.4_linux_amd64  /usr/local/bin/cfssl-certinfo
/bin/cp cfssljson_1.6.4_linux_amd64  /usr/local/bin/cfssljson

chmod +x /usr/local/bin/{cfssl,cfssl-certinfo,cfssljson}

tar -zxvf etcd-${etcd_version}-linux-amd64.tar.gz -C /usr/local/bin/ --strip-components=1

chmod +x /usr/local/bin/etcd*

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
sed -i  's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9"|g' /etc/containerd/config.toml

systemctl restart containerd 
if [ $? -ne 0 ];then
  echo "containerd service restart failed"
  exit 1
fi

/bin/cp docker-compose-linux-x86_64 /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

#-------安装docker相关组件----------
tar -zxvf docker-${docker_version}.tgz 
/bin/cp docker/docker* /usr/local/bin/

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
    "data-root": "${docker_data_root}",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    },
    "bip": "169.254.123.1/24",
    "registry-mirrors": ["https://xbrfpgqk.mirror.aliyuncs.com"],
    "live-restore": true
}
EOF
sed -i "s|\${docker_data_root}|$docker_data_root|g" /etc/docker/daemon.json
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



sudo mkdir -p "$bin_dir"


##-------安装k8s相关组件----------
tar -zxvf crictl-${crictl_version}-linux-$arch.tar.gz -C /usr/local/bin/
chmod +x /usr/local/bin/crictl
tar -zxvf kubernetes-server-linux-${arch}.tar.gz
/bin/cp kubernetes/server/bin/{kubelet,kubectl,kubeadm} $bin_dir/
chmod +x $bin_dir/{kubeadm,kubelet,kubectl}

tee /etc/systemd/system/kubelet.service <<EOF
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/kubelet
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
ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_CONFIG_ARGS \$KUBELET_KUBEADM_ARGS \$KUBELET_EXTRA_ARGS
EOF

curl -sSL -o helm-v${helm_version}-linux-amd64.tar.gz "https://mirrors.huaweicloud.com/helm/v${helm_version}/helm-v${helm_version}-linux-${arch}.tar.gz"
tar -zxvf helm-v${helm_version}-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/

systemctl enable --now kubelet
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(helm completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc

kubeadm config print init-defaults > kubeadm-init.yaml
kubeadm config print join-defaults > kubeadm-join.yaml


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
    dataDir: ${etcd_data}
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
containerRuntimeEndpoint: unix:///var/run/containerd/containerd.sock
imageServiceEndpoint: unix:///var/run/containerd/containerd.sock
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
  kubeadm join --config kubeadm-join-node.yaml
else
  kubeadm init --config kubeadm-${k8s_version}-init.yaml --upload-certs
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
  kubectl taint node master node-role.kubernetes.io/control-plane:NoSchedule-
  kubectl apply -f https://mirror.ghproxy.com/https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/experimental-install.yaml
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
  kubectl apply -f https://mirror.ghproxy.com/https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-frr-k8s.yaml



  helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace=environment --create-namespace \
    --set nfs.server="${local_ip}" \
    --set nfs.path="${nfs_path}" \
    --set storageClass.name=nfs-client \
    --set-string nfs.mountOptions={"soft,timeo=600,intr,retry=5,retrans=2,proto=tcp,vers=3"} \
    --set storageClass.defaultClass=true


##----对k8s镜像进行替换---------
  if [ "$zone" == "cn" ];then
    kubectl set image  -n environment deployment nfs-subdir-external-provisioner nfs-subdir-external-provisioner=k8s.dockerproxy.com/sig-storage/nfs-subdir-external-provisioner:v4.0.2
    curl -s https://mirror.ghproxy.com/https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml | sed 's|registry.k8s.io|k8s.dockerproxy.com|g' | kubectl apply -f -
  else 
    curl -s https://mirror.ghproxy.com/https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml  | kubectl apply -f -
  fi
fi