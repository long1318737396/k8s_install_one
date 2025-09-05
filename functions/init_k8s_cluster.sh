#!/bin/bash

# 初始化k8s集群
init_k8s_cluster() {
  echo "Initializing Kubernetes cluster..."
  
  if [ "$role" == "node" ];then
    kubeadm join --config kubeadm-join-node.yaml --v 5
  else
    kubeadm init --config "kubeadm-${k8s_version}-init.yaml" --upload-certs --v 5
  fi

  if [ $? -ne 0 ];then
    echo "Kubernetes cluster initialization failed"
    exit 1
  else
    if [ "$role" == "node" ];then
      echo "Node joined the cluster"
    else
      mkdir -p $HOME/.kube
      sudo /bin/cp /etc/kubernetes/admin.conf $HOME/.kube/config
      sudo chown $(id -u):$(id -g) $HOME/.kube/config
      echo "Kubernetes control plane initialized"
    fi
  fi
  
  echo "Kubernetes cluster initialization completed."
}