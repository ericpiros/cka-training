# Installation of Kubernetes
One of the curriculum topics included in the exam is to install a basic cluster using kubeadm. Using kubeadm to stand up a cluster is covered [here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) and we can follow the instructions outlined there to stand up a basic cluster.  

# Cluster Setup
We will be setting up a 3 node cluster which will have 1 master node and 2 worker nodes. I have created a [Vagrantfile](../../vagrant/virtualbox_setup/Vagrantfile) which will stand up 4 Ubuntu 20.04 VMs. Note that this requires that you have the following installed on your machine:  
* [Vagrant](https://developer.hashicorp.com/vagrant/downloads)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)  

Each VM is labeled accordingly:
* **Jumpbox** - the jumpbox server we can use to log into the other 3 servers. This is optional since we can directly use 'vagrant ssh' to log into the other servers.
* **Master** - the master node where we will install out control plane.
* **Node1/Node2** - the K8S worker nodes.  
More details on how to use the Vagrantfile can be found in the appropriate [readme](../../vagrant/virtualbox_setup/README.md) file.  

# Cluster Notes
Before we start with the configuration, take note that in the environment that I am using here, each VM will have 2 network interface cards. The first one is the standard VirtualBox NAT interface, which will have an IP address of 10.0.2.15. The second interface card is the default VirtualBox Local network, which will be in the 192.168.56.0/24 CIDR network.  If you are using the same network CIDR as the VirtualBox local network, you may need to create your own VirtualBox local network and adjust the Vagrantfile setting and kubeadm init commands accordingly.  
Because of the dual NIC situation on the VMs, we will need to add a parameter on our kubeadm init command later to make sure that the Kubernetes API listens on the correct network.  

# Host File Prep
We will need to ensure that the node names we have are resolveable. Since we do not have a DNS server where our hosts can register we will modify our hosts file to include the node names. On all 3 VMs (master, node1 and node2) ensure that the following entries are present in '/etc/hosts':  
```
192.168.56.5  master  master
192.168.56.11 node1   node1
192.168.56.12 node2   node2
```  
Take note that the values above are taken from the values in our Vagranfile. If you have modified yours, enter the values that you set in your '/etc/hosts'.

# Initial Setup
We will need to install a container runtime which will be used to manage containers for Kubernetes. Kubernetes supports several container runtimes as outlined [here](https://kubernetes.io/docs/setup/production-environment/container-runtimes/). We will be using [containerd](https://containerd.io/) as our runtime as it is readily availble in the Ubuntu repository.  
No matter which run time you choose, we will need to set up a few kernel modules and sysctl parameters to support the various Network Plugins that can be used.  
## Kernel Modules
* overlay
* netfilter
```
# Ensure that the modules get loaded on reboot
$ cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load the modules
$ sudo modprobe overlay
$ sudo modprobe br_netfilter

# Confirm that the modules are loaded
$ lsmod | grep br_netfilter
$ lsmod | grep overlay
```  
## sysctl Parameters
* net.bridge.bridge-nf-call-iptables  = 1
* net.bridge.bridge-nf-call-ip6tables = 1
* net.ipv4.ip_forward                 = 1 
```
# sysctl params required by setup, params persist across reboots
$ cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
$ sudo sysctl --system

# Check if the parameters are set
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```
These instructions need to be done on the following VMs: 
* Master
* Node1
* Node2

# Turning Off Swap
Swap needs to be turned off for kubelet to work properly. There is a discussion about trying to get kubelet to work with Swap enabled that you can read on [here](https://github.com/kubernetes/kubernetes/issues/53533).  
```
# Turn off swap
$ sudo swapoff -a

# And then to disable swap on startup in /etc/fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Check that Swap is off:
$ free
``` 
The second command will comment out the swap configuration line in /etc/fstab so that it stays disabled after reboots:
```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/ubuntu-vg/ubuntu-lv during curtin installation
/dev/disk/by-id/dm-uuid-LVM-Ca1uwAMAqC3gRhiIaJvSUOenzOKwkEP8eIuR8UblTBCexq0grl4M8Fc8Jyb3cudy / ext4 defaults 0 1
# /boot was on /dev/sda2 during curtin installation
/dev/disk/by-uuid/05435722-8e7e-40aa-b5d2-5184c0b6689d /boot ext4 defaults 0 1
# The line below is what will be removed.
/swap.img       none    swap    sw      0       0 <-- Comment this line out.
#VAGRANT-BEGIN
# The contents below are automatically generated by Vagrant. Do not modify.
vagrant /vagrant vboxsf uid=1000,gid=1000,_netdev 0 0
#VAGRANT-END
``` 

# Installing containerd
Since we are running Ubuntu, installing containerd is pretty straight forward:
```
$ sudo apt update
$ sudo apt install -y containerd
```
Take note that since we are going to install Kubernetes 1.26, we will require containerd version 1.6.0 and higher as mentioned in [this](https://kubernetes.io/blog/2022/12/09/kubernetes-v1-26-release/) announcement. If you are using an older version of Ubuntu, you may want to check what version is included in the repository. As of 4/15/2023, version 1.6.12 is availble on Ubuntu 20.04.
## Configuring containerd
We will need to create a configuration file for containerd. We can output the default config by passing the 'config default' parameter to containerd.  The config should be placed in '/etc/containerd/config.toml'.  
```
# Create the containerd directory
$ sudo mkdir -p /etc/containerd

# Generate the default config
$ sudo containerd config default | sudo tee /etc/containerd/config.toml

# Restart containerd to pick up the new settings
$ sudo systemctl restart containerd

# Check that containerd is running
$ sudo systemctl status containerd
```

# Installing Kubeadm, Kubelet and Kubectl
Now we can start working on installing the tools that we will need to spin up the cluster. First lets add the Kubernetes repository:  
```
# If it is not yet installed, let us install curl, apt-transport-httpos and ca-certificates
$ sudo apt update
$ sudo apt install -y apt-transport-https ca-certificates curl

# Create the keyrings directory
$ sudo mkdir -p /etc/apt/keyrings

# Download the Google Cloud public key
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

# Add the Kubernetes repository:
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet and kubectl
$ sudo apt update
$ sudo apt install -y kubeadm=1.26.0-00 kubectl=1.26.0-00 kubelet=1.26.0-00

# Hold the above installed packages so that they do not get accidentally upgraded when I run a apt upgrade.
$ sudo apt-mark hold kubeadm kubectl kubelet

# Check that they are installed properly
$ kubectl version
$ sudo kubeadm --version
$ sudo systemctl status kubelet
```

# Configuring the Worker Nodes
The commands listed above need to be done on the worker nodes as well. If you wish to speed through the worker node pre-work, I have created a shell script that runs the commands above [here](../../vagrant/virtualbox_setup/k8s_req.sh). If you have cloned this repository, the script will be available in the '/vagrant' directory on all VMs.
```
# Copy the script to the home folder
$ sudo cp /vagrant/k8s_req.sh
$ sudo chmoid +x k8s_req.sh
$ ./k8s_req.sh
``` 
Once you installed and configured the worker nodes, we can start bootstrapping our control plane.  

# Bootstrapping the Control Plane
This [page](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) contains instruction on setting up a simple Kubernetes cluster. Technically we only need to run 'kubeadm init' to get started, however there are several kubeadm init [parameters](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/) that are worth configuring for my environment:  
## kubeadm init parameters
* **--apiserver-advertise-address** - by default kubeadm will set the API server IP to what is set to the default gateway on your server. This is not ideal for my setup as the default gateway on my VMs points to the VirtualBox NAT network. So I will need to specify the IP address of the Master server (192.168.56.5 on the Vagrantfile) to ensure that it advertises the correct IP address.
 * **--kubernetes-version** - by default kubeadm will install the latest version of kubernetes. I will set it to the base version of 1.26.0 so that I can practice upgrading it on a later date.
 * **--pod-network-cidr** - the range of IP addresses for the pod network. Take note of this value as we may need later when we install our CNI plugin. We will set this to 10.244.0.0/16 since we planning on using flannel as our network plugin.
```
# Create the cluster
$ sudo kubeadm init --apiserver-advertise-address 192.168.56.5 --kubernetes-version 1.26.0 --pod-network-cidr 10.244.0.0/16 -v 5
```  
The command above needs to be run on the Master VM.  
I am setting the verbosity of the output to 5 so that we can track what kubeadm will be doing.
## Using a Configuration File
Alternatively you can create a kubeadm init configuration file and pass it to kubeadm init using the '--config' parameter. This feature, as of 4/15/2023, is marked as beta, so it may change on a later date. You can get a template and the various options you can set on this [page](https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta3/). You can also run 'kubeadm config print init-defaults' to quickly create a config file template to edit. You will only need the 'ClusterConfiguration' section to setup a cluster. Converting our parameters above my config file would look like this:
```
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "192.168.56.5"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
networking:
  podSubnet: "10.244.0.0/16"
kubernetesVersion: "v1.26.0"
clusterName: "my-k8s-cluster"
```
I have this available here: [my-k8s-cluster.yaml](../../vagrant/virtualbox_setup/my-k8s-cluster.yaml).  To run this I will use:  
```
# Create my cluster using a kubeadm config file
$ sudo kubeadm init --config ./my-k8s-cluster.yaml -v 5
```  
## Post kubeadm init commands
After the control plane has initialize, kubeadm gives us some handy suggestions on how to proceed next. First we want to create kube config file so that we can run kubectl on the Master node to be able to check out cluster.
```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```  
This copies the admin.conf kube config file in the /etc/kubernetes directory into our .kube/config file. With that set we can run a 'kubectl get nodes' to see the status of our nodes in our cluster:
```
vagrant@master:~$ mkdir -p $HOME/.kube
vagrant@master:~$   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
vagrant@master:~$   sudo chown $(id -u):$(id -g) $HOME/.kube/config
vagrant@master:~$ kubectl get nodes
NAME     STATUS     ROLES           AGE     VERSION
master   NotReady   control-plane   7m49s   v1.26.0
```  
As we can see our control plane node is up, but in the NotReady state. This is normal as it will not be in the ready state until we install a network plugin.  
The kubeadm init command also shows us how to join our nodes to our clusters. So lets do that.

# Joining the Worker Nodes
We can use the 'kubeadm join' command to join our worker nodes:
```
$ sudo kubeadm join 192.168.56.5:6443 --token <token> \
                --discovery-token-ca-cert-hash \
                 <discovery ca cert hash>
```
Now if incase you decide to add another worker node at a later date, you can view the join command again by typing:
```
$ sudo kubeadm token create --print-join-command
```
Needless to say, the join commands need to be run on the worker nodes. Once joined we can run 'kubectl get nodes' again to confirm that the worker nodes have joined the cluster successfully.
```
vagrant@master:~$ kubectl get nodes
NAME     STATUS     ROLES           AGE   VERSION
master   NotReady   control-plane   14m   v1.26.0
node1    NotReady   <none>          19s   v1.26.0
node2    NotReady   <none>          23s   v1.26.0
```  
Now we can complete the installation by installing a network plugin.  

# Installing a Network Plugin
We will need to install a Container Network Interface (CNI) plugin so that our pods can communicate with each other.  Coredns will also not start up until a CNI plugin is installed:
```
# coredns is pending until we install a CNI
vagrant@jumpbox:~$ kubectl get pods --namespace kube-system | grep coredns
coredns-787d4945fb-c8ktd         0/1     Pending   0             13h
coredns-787d4945fb-zxmlq         0/1     Pending   0             13h
```
There are several plugins available and a list can be found [here](https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy). However, if we look at the CKA/CKAD Environment section in the [Handbook](https://docs.linuxfoundation.org/tc-docs/certification/tips-cka-and-ckad), we can see that the exam environment will mostly have [flannel](https://github.com/flannel-io/flannel) and [calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart) as their CNI.  
Since flannel is installed on more environments, we will go with flannel in this training.  
## Installing Flannel
Based on Flannel's github page, this plugin is more focused on the network aspect of the CNI and does not provide network policy capabilites. For that we will need to use calico.  
To install flannel, we only need to download the latest manifest file and run 'kubectl apply -f < flannel manifest >. One consideration to take is that by default flannel expects the pod CIDR to be 10.244.0.0/16, which we already set.  

Before installing flannel, there is 1 more thing we need to consider in our environment. Since our Vagrant boxes have 2 network interfaces, this will cause a problem with flannel. This is because flannel will select the first interface on the host. We will need to specify the --iface=eth1 to the daemonset parameter to avoid any issues. This is documented in the [Troubleshooting](https://github.com/flannel-io/flannel/blob/master/Documentation/troubleshooting.md) section of their github page under the section 'Vagrant'
```
# Download flannel manifest
$ wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Edit kube-flannel.yml again and go to the DaemonSet section
piVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: flannel
    k8s-app: flannel
    tier: node
  name: kube-flannel-ds
  namespace: kube-flannel
spec:
  selector:
    matchLabels:
      app: flannel
      k8s-app: flannel
  template:
    metadata:
      labels:
        app: flannel
        k8s-app: flannel
        tier: node
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
      containers:
      - args:
        - --ip-masq
        - --kube-subnet-mgr
  -->   - --iface=eth1 <-- Insert this line
        command:
        - /opt/bin/flanneld

# Apply the flannel manifest
$ kubectl apply -f kube-flannel.yml

# Wait for coredns and the flannel pods to come up
$ kubectl get pods --namespace kube-system -w

# Once all pods are up, lets check the status of our nodes
$ kubectl get nodes
```

# Testing the Cluster
We should now have a functioning Kubernetes cluster. Lets spin up a few pods and see if we have basic functionality and connectivity.  
```
# Spin up an nginx pod in the default namespace.
$ kubectl run nginx --image=nginx

# Confirm that our pod is up and get the IP address.
$ kubectl get pods -o wide
NAME    READY   STATUS    RESTARTS      AGE     IP                                           NODE    NOMINATED NODE   READINESS GATES
nginx   1/1     Running   1 (28m ago)   2d16h   10.244.1.3 <-- take note of this IP address  node1   <none>           <none>

# Spin up a temporary busybox pod to test pod connectivity.
$ kubectl run busybox --image=radial/busyboxplus:curl -i --tty --rm -- /bin/sh
If you don't see a command prompt, try pressing enter.
[ root@busybox:/ ]$ curl 10.244.1.3
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

# Lets try creating a service of the type NodePort and try exposing out nginx outside of our VMs.
$ kubectl expose pod nginx --port=80 --type=NodePort -n default
service/nginx exposed

# Check what port was assigned to our service
$ kubectl get services
AME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                           AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP                                          2d16h
nginx        NodePort    10.108.83.141   <none>        80:31164/TCP <-- take note of the 2nd TCP port   44s
```  
Now open a browser and type in the address of our master node with the port shown in the 'kubectl get services' command above. In our example it would be 'http://192.168.56.5:31164'  


# Issues Encountered
These are some of the things I encountered while learning to install Kubernetes through kubeadm:  
## PodCIDR setting not set on node  
The following error will appear in the logs if a node does not have the PodCIDR setting set:
```
E0422 15:32:46.190369       1 main.go:334] Error registering network: failed to acquire lease: node "node1" pod cidr not assigned
```
I learned that this can happen when you pass a '/24' CIDR to the '--pod-network-cidr' parameter of 'kubeadm init'. This is discussed [here](https://github.com/kubernetes/kubeadm/issues/2327).  
There are 2 possible fixes for this issue:  
* Patch the podCIDR setting on the nodes.  
```
$ kubectl patch node <node name> -p '{"spec":{"podCIDR":"<pod CIDR value>"}}'
```
* Use a /16 CIDR during the 'kubeadm init' phase.  
Of the 2 solutions, the 2nd one is the preferred solution. If you do decide to keep the /24 CIDR, you will need to issue the 'kubectl patch' on each node that you will add to your cluster.
