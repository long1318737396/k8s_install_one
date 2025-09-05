#!/bin/bash

# 下载所需软件包
download_packages() {
  echo "Downloading packages..."
  
  # 基础包列表（所有运行时都需要）
  base_packages=(
    "$kubernetes_server_url"
    "$crictl_url"
    "$etcd_url"
    "$cfssl_url"
    "$cfssljson_url"
    "$cfssl_certinfo"
    "$ecapture_url"
    "$pcpdump_url"
  )

  # 根据选择的运行时添加相应的包
  if [ "${runtime}" == "containerd" ]; then
    runtime_packages=(
      "$nerdctl_full_url"
    )
  elif [ "${runtime}" == "docker" ]; then
    runtime_packages=(
      "$docker_url"
      "$docker_compose_url"
      "$docker_buildx_url"
    )
  elif [ "${runtime}" == "crio" ]; then
    runtime_packages=(
      "$crio_url"
    )
  else
    echo "Unknown runtime: ${runtime}"
    exit 1
  fi

  # 根据CNI类型添加相应的包
  cni_packages=()
  if [ "${cni_type}" == "calico" ]; then
    cni_packages+=("$calico_url")
  elif [ "${cni_type}" == "cilium" ]; then
    cni_packages+=(
      "$cilium_url"
      "$hubble_url"
    )
  fi

  # 合并基础包、运行时特定包和CNI包
  packages=("${base_packages[@]}" "${runtime_packages[@]}" "${cni_packages[@]}")

  if [ "$zone" == "cn" ];then
    echo "Downloading packages from China mirror..."
    for package_url in "${packages[@]}"; do
      filename=$(basename "$package_url")
      if [ ! -f "$filename" ];then
        echo "Downloading $filename..."
        wget -O "$filename" "${base_url}/$package_url"
        echo "Downloaded $filename"
      else
        echo "$filename is existed"
      fi
    done
  else
    echo "Downloading packages..."
    for package_url in "${packages[@]}"; do
      filename=$(basename "$package_url") 
      if [ ! -f "$filename" ];then
        echo "Downloading $filename..."
        wget -O "$filename" "$package_url"
        echo "Downloaded $filename"
      else
        echo "$filename is existed"
      fi
    done
  fi
  
  echo "Package downloads completed."
}