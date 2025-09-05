#!/bin/bash

#-------安装crio相关组件---------
install_crio() {
  echo "Installing CRI-O..."
  
  if [ -f "cri-o.${ARCH}.v${crio_version}.tar.gz" ];then
    tar -zxvf "cri-o.${ARCH}.v${crio_version}.tar.gz"
    cd cri-o || exit 1
    bash install
    systemctl daemon-reload
    systemctl enable --now crio
    if [ $? -ne 0 ];then
      echo "crio service start failed"
      exit 1
    fi
    cd ..
  else
    echo "CRI-O package not found, skipping installation"
    exit 1
  fi
  
  echo "CRI-O installed."
}