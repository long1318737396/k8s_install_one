nfs_path=/data/k8s/nfs
docker_data_root=/data/kubernetes/docker
etcd_data=/data/kubernetes/etcd
containerd_data="/data/kubernetes/containerd"
bin_dir=/usr/local/bin



set -x
kubeadm reset --force
ipvsadm -C

systemctl stop docker
systemctl disable docker
systemctl stop containerd
systemctl disable containerd
systemctl stop kubelet
systemctl disable kubelet




ip link delete cilium_host
ip link delete cilium_net
ip link delete cilium_vxlan
ip link delete kube-ipvs0
ip link delete docker0

rm -rf /etc/buildkit/buildkitd.toml
rm -rf /etc/nerdctl/nerdctl.toml
rm -rf /usr/local/bin/docker-compose

rm -rf /etc/systemd/system/{buildkit.service,containerd.service,stargz-snapshotter.service}
rm -rf /opt/cni/bin/
rm -rf /etc/containerd/
rm -rf /etc/docker

rm -rf /usr/local/bin/docker*
rm -rf /usr/local/bin/kube*
rm -rf /usr/local/bin/crictl
rm -rf /usr/local/bin/etcd*
#rm -rf ${nfs_path}
rm -rf ${docker_data_root}
rm -rf ${etcd_data}
rm -rf ${containerd_data}
rm -rf ${bin_dir}
rm -rf /var/lib/kubelet

package=(
    bin/buildctl
    bin/buildg
    bin/buildkitd
    bin/bypass4netns
    bin/bypass4netnsd
    bin/containerd
    bin/containerd-fuse-overlayfs-grpc
    bin/containerd-rootless-setuptool.sh
    bin/containerd-rootless.sh
    bin/containerd-shim-runc-v2
    bin/containerd-stargz-grpc
    bin/ctd-decoder
    bin/ctr
    bin/ctr-enc
    bin/ctr-remote
    bin/fuse-overlayfs
    bin/ipfs
    bin/nerdctl
    bin/rootlessctl
    bin/rootlesskit
    bin/runc
    bin/slirp4netns
    bin/tini
)
for i in ${package[@]}
  do
     rm -rf /usr/local/$i
done