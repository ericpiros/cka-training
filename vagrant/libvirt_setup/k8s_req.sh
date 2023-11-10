#!/bin/bash
#
echo "Turning off swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Enabling overlay and br_netfilter"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "Setting IP settings"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "Installing containerd"
sudo apt update && sudo apt install -y containerd

sudo mkdir -p /etc/containerd

sudo containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

echo "Adding K8S repo"
sudo mkdir -p /etc/apt/keyrings

sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

# Note that sometime around June 2023 the gpg key above stopped working. As a result you would not be able to
# run an apt update since the certificate is invalid. To get around this I have set the repo to trusted.
# Note that there are now new repo links and gpg keys in the officual kubeadm documentation located
# here: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
echo "deb [trusted=yes] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "Installing kubeadm, kubectl and kubelet"
sudo apt update && sudo apt install -y kubelet=1.26.0-00 kubeadm=1.26.0-00 kubectl=1.26.0-00

sudo apt-mark hold kubelet kubeadm kubectl
