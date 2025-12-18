#!/bin/bash

# 部署CNI网络插件和其他组件
deploy_cni_and_components() {
  echo "Deploying CNI and components..."
  pwd
  tar -zxvf "cni-plugins-linux-${ARCH}-v${containernetworking_version}}.tgz" -C /opt/cni/bin/
  if [ "$role" == "node" ];then
    echo "this is node"
  else
    echo "this is master"
    
    kubectl taint node "${HOSTNAME}" node-role.kubernetes.io/control-plane:NoSchedule-
    
    if [ "$zone" == "cn" ];then
      kubectl apply -f "${base_url}/https://github.com/kubernetes-sigs/gateway-api/releases/download/${gateway_api_version}/experimental-install.yaml"
    else
      kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${gateway_api_version}/experimental-install.yaml"
    fi
    
    helm repo add cilium https://helm.cilium.io/
    helm repo update
    
    if [ "$cni_type" == "cilium" ];then
      helm upgrade --install cilium cilium/cilium --namespace=kube-system --version 1.17.3 \
        --set routingMode=native \
        --set kubeProxyReplacement=strict \
        --set bandwidthManager.enabled=true \
        --set ipam.mode=kubernetes \
        --set k8sServiceHost="${local_ip}" \
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
        kubectl apply -f "${base_url}/https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
      else
        kubectl apply -f "https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
      fi
    elif [ "$cni_type" == "calico" ];then
      if [ "$zone" == "cn" ];then
        kubectl apply -f "${base_url}/https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/calico.yaml"
      else
        kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/calico.yaml"
      fi
    else 
      echo "cni_type is not valid"
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
      kubectl apply -f "${base_url}/https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-frr-k8s.yaml"
    else
      kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-frr-k8s.yaml"
    fi

    if [ "$zone" == "cn" ];then
      kubectl apply -f "${base_url}/https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml"
    else
      kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml"
    fi

    helm upgrade --install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --namespace=environment --create-namespace \
      --set nfs.server="${local_ip}" \
      --set nfs.path="${nfs_path}" \
      --set storageClass.name=nfs-client \
      --set-string nfs.mountOptions={"soft,timeo=600,intr,retry=5,retrans=2,proto=tcp,vers=3"} \
      --set storageClass.defaultClass=true

    ##----对k8s镜像进行替换---------
    if [ "$zone" == "cn" ];then
      kubectl apply -f "${base_url}/https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml"
    else 
      kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml"
    fi
  fi
  
  echo "CNI and components deployed."
}