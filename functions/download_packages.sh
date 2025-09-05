#!/bin/bash

# 下载所需软件包
download_packages() {
  echo "Downloading packages..."
  
  packages=(
    "$docker_url"
    "$kubernetes_server_url"
    "$nerdctl_full_url"
    "$crictl_url"
    "$etcd_url"
    "$cfssl_url"
    "$cfssljson_url"
    "$cfssl_certinfo"
    "$docker_compose_url"
    "$ecapture_url"
    "$cilium_url"
    "$hubble_url"
    "$velero_url"
    "$skopeo_url"
    "$ecapture_url"
    "$pcpdump_url"
    "$calico_url"
    "$docker_buildx_url"
    "$crio_url"
    "$cri_docker_url"
 
  )

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