#!/bin/bash

# 设置网络和主机名
setup_network_hostname() {
  echo "Setting up network and hostname..."
  
  # 获取具有默认路由的网卡名称
  DEFAULT_INTERFACE=$(ip route show default | awk '/default/ {print $5}')
  # 检查是否成功获取到网卡名称
  if [ -z "$DEFAULT_INTERFACE" ]; then
    echo "无法获取具有默认路由的网卡名称"
    exit 1
  fi
  
  # 获取该网卡的 IP 地址
  IP_ADDRESS=$(ip addr show "$DEFAULT_INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

  # 检查是否成功获取到 IP 地址
  if [ -z "$IP_ADDRESS" ]; then
    echo "无法获取 IP 地址"
    exit 1
  fi

  local_ip=$IP_ADDRESS
  # 获取旧主机名
  OLD_HOSTNAME=$(hostname)
  # 将 IP 地址中的点替换为破折号
  HOSTNAME="k8s-$(echo "$IP_ADDRESS" | tr '.' '-')"
  # 设置主机名
  hostnamectl set-hostname "$HOSTNAME"
  # 更新 /etc/hosts 文件
  echo "更新 /etc/hosts 文件..."
  # 备份hosts文件
  cp /etc/hosts /etc/hosts.bak
  # 更新 hosts 文件，保留原有内容
  sed -i "s/\b${OLD_HOSTNAME}\b/${HOSTNAME}/g" /etc/hosts

  # 输出新的主机名
  echo "新的主机名已设置为: $HOSTNAME"
}