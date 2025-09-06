#!/bin/bash

##-------安装k8s相关组件----------
install_k8s_components() {
  echo "Installing Kubernetes components..."
  
  if [ -f "crictl-${crictl_version}-linux-${ARCH}.tar.gz" ]; then
    tar -zxvf "crictl-${crictl_version}-linux-${ARCH}.tar.gz" -C "${bin_dir}"
    chmod +x "${bin_dir}/crictl"
    echo "source <(crictl completion bash)" >> ~/.bashrc
  fi

  echo "runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:////var/run/containerd/containerd.sock
#runtime-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
#debug: true" > /etc/crictl.yaml

  if [ -f "kubernetes-server-linux-${ARCH}.tar.gz" ]; then
    tar -zxvf "kubernetes-server-linux-${ARCH}.tar.gz"
    /bin/cp kubernetes/server/bin/{kubelet,kubectl,kubeadm} "$bin_dir/"
    chmod +x  $bin_dir/{kubeadm,kubelet,kubectl}
  fi

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

  systemctl enable --now kubelet
  echo "source <(kubectl completion bash)" >> ~/.bashrc
  tar -zxvf helm-v${helm_version}-linux-${ARCH}.tar.gz
  cp linux-${ARCH}/helm ${bin_dir}/
  echo "source <(helm completion bash)" >> ~/.bashrc
  echo "source <(kubeadm completion bash)" >> ~/.bashrc

  kubeadm config print init-defaults > kubeadm-init.yaml
  kubeadm config print join-defaults > kubeadm-join.yaml

  generate_kubeadm_config
  
  echo "Kubernetes components installed."
}

# 生成kubeadm配置文件
generate_kubeadm_config() {
  echo "Generating kubeadm config..."
  
  tee "kubeadm-${k8s_version}-init.yaml" <<EOF
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
EOF

  if [ "${runtime}" == "containerd" ];then
    echo "  criSocket: unix:///var/run/containerd/containerd.sock" >> "kubeadm-${k8s_version}-init.yaml"
  elif [ "${runtime}" == "docker" ];then
    echo "  criSocket: /var/run/cri-docker.sock" >> "kubeadm-${k8s_version}-init.yaml"
  elif [ "${runtime}" == "crio" ];then
    echo "  criSocket: /var/run/crio/crio.sock" >> "kubeadm-${k8s_version}-init.yaml"
  fi

  tee -a "kubeadm-${k8s_version}-init.yaml" <<EOF
  imagePullPolicy: IfNotPresent
  name: ${HOSTNAME}
  taints: null
#skipPhases:
#  - addon/kube-proxy
timeouts:
  controlPlaneComponentHealthCheck: 4m0s
  discovery: 5m0s
  etcdAPICall: 2m0s
  kubeletHealthCheck: 4m0s
  kubernetesAPICall: 1m0s
  tlsBootstrap: 5m0s
  upgradeManifests: 5m0s
---
apiServer:
  certSANs:
    - vip.cluster.local
    - 127.0.0.1
    - ${local_ip}
  extraArgs:
    - name: default-not-ready-toleration-seconds
      value: "300"
    - name: default-unreachable-toleration-seconds
      value: "300"
apiVersion: kubeadm.k8s.io/v1beta4
certificatesDir: /etc/kubernetes/pki
caCertificateValidityPeriod: 876000h0m0s
certificateValidityPeriod: 876000h0m0s
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
  serviceSubnet: ${serviceSubnet}
  podSubnet: ${podSubnet}
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
serializeImagePulls: false
containerLogMaxSize: 100Mi
containerLogMaxFiles: 10
maxPods: 128
podPidsLimit: 16384
cgroupDriver: systemd
cpuManagerPolicy: none
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
apiVersion: kubeadm.k8s.io/v1beta4
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken: 
    apiServerEndpoint: \${master_ip}:6443
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
    sed -i 's|imageRepository: registry.k8s.io|imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers|g' "kubeadm-${k8s_version}-init.yaml"
  fi
  
  echo "Kubeadm config generated."
}