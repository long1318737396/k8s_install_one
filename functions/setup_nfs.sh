#!/bin/bash

#--------安装nfs相关组件----------
setup_nfs() {
  echo "Setting up NFS..."
  echo "this is node"
  mkdir -p "${nfs_path}"
  chmod -R 777 "${nfs_path}"
  echo "${nfs_path} *(rw,sync,no_root_squash,no_subtree_check)" | sudo tee /etc/exports
  exportfs -ra
  
  if [ -f /etc/debian_version ]; then
    systemctl enable nfs-kernel-server
    systemctl restart nfs-kernel-server
    showmount -e localhost
  else
    systemctl enable rpcbind --now
    systemctl enable nfs-server
    systemctl start nfs-server
    showmount -e localhost
  fi
  
  echo "NFS setup completed."
}