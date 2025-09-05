#!/bin/bash

#-----------------安装基础软件包------------
install_base_packages() {
  echo "Installing base packages..."
  
  if [ -f /etc/debian_version ]; then
    echo "Detected Debian-based system"
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
      lsof
      iputils-ping
      iproute2
      net-tools
    )
    for i in "${packages[@]}";do
        echo "Installing package: $i"
        apt install "$i" -y
    done
  else 
    echo "Detected RHEL-based system"
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
      lsof
      git 
    )

    for i in "${packages[@]}";do
        echo "Installing package: $i"
        yum install "$i" --skip-broken -y
    done
  fi
  
  echo "Base packages installed."
}