# Upgrading Kubernetes Through Kubeadm
The following general steps can be used to upgrade a Kubernetes cluster using kubeadm:  
* Upgrade the control plane first:
  * Drain 1 Control Plane node.
  * Unhold the kubeadm package.
  * Upgrade kubeadm through the package manager.
  * Run kubeadm upgrade plan v< Kubernetes Version >.
  * Run kubeadm upgrade apply v< Kubernetes version >.
  * Unhold the kubectl and kubelet packages.
  * Upgrade kubectl and kubelet through the package manager.
  * Restart the kubelet service.
  * Uncordon the upgraded node.
  * Repeat the steps on the Control Plane nodes.
* Ugrade the worker nodes:
  * Drain 1 worker node.
  * Unhold the kubeadm package.
  * Upgrade kubeadm through the package manager.
  * Run kubeadm upgrade plan v< Kubernetes Version >.
  * Run kubeadm upgrade node v< Kubernetes version >.
  * Unhold the kubectl and kubelet packages.
  * Upgrade kubectl and kubelet through the package manager.
  * Restart the kubelet service.
  * Uncordon the upgraded node.
  * Repeat the steps on the worker nodes.

# Upgrading kubeadm
Ideally before running any of the steps below, you should have read the release notes or ran 'kubeadm upgrade plan' and took note of the changes that will be made. We would be particularly interested in taking note of the API group changes that need to be made to your Kubernetes resources before proceeding with the upgrade.  
First we unhold the kubeadm package since we held it back during installation. Then upgrade it using our package manager. 
```
# Unhold the kubeadm package.
$ sudo apt-mark unhold kubeadm
Canceled hold on kubeadm.

# Upgrade kubeadm.
$ sudo apt upgrade -y kubeadm=1.26.4-00
```

# Drain the node to be upgraded
This will ensure that no new pods get scheduled on the node that we are upgrading and will also remove any pods that are currently on the node. Using the drain command will also cordon it off.  
```
# Drain the nodes
$ kubectl drain master --ignore-daemonsets

# Confirm that the node that we drained has been cordoned.
$ kubectl get nodes
AME     STATUS                     ROLES           AGE     VERSION
master   Ready,SchedulingDisabled   control-plane   3d14h   v1.26.0
node1    NotReady                   <none>          3d14h   v1.26.0
node2    NotReady                   <none>          3d14h   v1.26.0
```

There maybe situations where the drain will fail due to pods using emptyDir, you use the '--delete-emptydir-data' and '--force' to force the deletion of the emptyDir.

# Running kubeadm upgrade plan and kubeadm upgrade apply
Once kubeadm has been upgraded on our control plane server, the next step is to run `kubeadm upgrade plan v< version number >. This will perform several actions:  
* Check the health of the custer.
* Check the cluster configuration.
* Check for unsupported CoreDNS plugins.
* Validate if an upgrade can be done on the CoreDNS release.
* Creates and runs a job called "upgrade-health-check" in kube-system.
* Checks versions that are available.
* Checks for components that must be manually upgraded after the upgrade apply process.
* Lists any API groups that may need to be changed before the upgrade.
Ideally you should run this command to confirm if there any changes you may need to make to your plugins or manifests before upgrading.  
Once you have confirmed that it is possible to upgrade your cluster, you can then run 'kubeadm upgrade apply v1.26.4'.  You will be prompted if you want to procced with the upgrade.
```
# Start the upgrade process.
$ sudo kubeadm upgrade apply v1.26.4 -v 5
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.26.4"
[upgrade/versions] Cluster version: v1.26.0
[upgrade/versions] kubeadm version: v1.26.4
[upgrade] Are you sure you want to proceed? [y/N]: y <-- You will be prompted here.
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.26.4" (timeout: 5m0s)...
[upgrade/etcd] Upgrading to TLS for etcd
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Current and new manifests of etcd are equal, skipping upgrade
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests2450737155"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Renewing apiserver-etcd-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-04-26-07-
02-30/kube-apiserver.yaml" 
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing 
controller-manager.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-
04-26-07-02-30/kube-controller-manager.yaml" 
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2023-04-26-07-
02-30/kube-scheduler.yaml"                   
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 1 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.26.4". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```  
As can be seen in the output, the same pre-flight checks as 'kubeadm upgrade plan' is done before the components are upgrade.  

# Upgrading the kubelet and kubectl packages
We now need to upgrade kubelet on the node. Kubectl allows for a +/-1 version skew, this means that if we have version 1.26.0 of kubectl, we can connect to a Kubernetes cluster that has a version of 1.25.0 or 1.27.0. Since we are upgrading the components, let us upgrade kubectl to the same point version as well.  
```
# Unhold the kubelet and kubectl packages.
$ sudo apt-mark unhold kubelet kubectl
Canceled hold on kubelet.
Canceled hold on kubectl.

# Upgrade kubelet and kubectl
$ sudo apt upgrade -y kubelet=1.26.4-00 kubectl=1.26.4-00

# Confirm our kubelet and kubectl version
$ sudo kubelet --version
$ kubectl version
```  

# Restart the kubelet and Uncordon the node
We will next restart the kubelet service to reload it to run the new version.
```
# Reload systemd daemon configurations.
$ sudo systemctl daemon-reload

# Restart the kubelet service.
$ sudo systemctl restart kubelet

# Confirm that kubelet is running.
$ sudo systemctl status kubelet
```
Next we uncordon the node that we have upgraded so that it can now start scheduling pods.  
```
# Uncordon our node
$ kubectl uncordon master
node/master uncordoned

# Confirm that our node is ready to accept pods.
$ kubectl get nodes
NAME     STATUS     ROLES           AGE     VERSION
master   Ready      control-plane   3d15h   v1.26.4
node1    NotReady   <none>          3d15h   v1.26.0
node2    NotReady   <none>          3d15h   v1.26.0
```
As seem above we have successfuly upgrade our control plane node to 1.26.4.  Now let us place the versions on hold again so that they do not get upgraded when a system update is run.  
```
# Hold the kubeadm, kubelet and kubectl packages.
$ sudo apt-mark hold kubeadm kubelet kubectl
kubeadm set on hold.
kubelet set on hold.
kubectl set on hold.
```

# Upgrading Our Worker Nodes
We will perform the same steps as above with the upgrade on the control plane, the only difference is that we will use 'kubeadm upgrade node' on the node.
```
# On the master node.
$ kubectl drain node1 --ignore-daemonsets --force

# Confirm that node1 has been cordoned.
$ kubectl get nodes
NAME     STATUS                        ROLES           AGE     VERSION
master   Ready                         control-plane   6d15h   v1.26.4
node1    NotReady,SchedulingDisabled   <none>          6d15h   v1.26.0
node2    NotReady                      <none>          6d15h   v1.26.0

# On node1.
$ sudo apt-mark unhold kubeadm
Canceled hold on kubeadm.

# Upgrade kubeadm on node1.
$ sudo apt upgrade -y kubeadm=1.26.4-00

# Upgrade the node.
$ sudo kubeadm upgrade node
[upgrade] Reading configuration from the cluster...
[upgrade] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks
[preflight] Skipping prepull. Not a control plane node.
[upgrade] Skipping phase. Not a control plane node.
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade] The configuration for this node was successfully updated!
[upgrade] Now you should go ahead and upgrade the kubelet package using your package manager.

# Unhold and upgrade kubelet and kubectl.
$ sudo apt-mark unhold kubelet kubectl
Canceled hold on kubelet.
Canceled hold on kubectl.

$ sudo upgrade -y kubelet=1.26.4-00 kubectl=1.26.4-00

# Confirm the versions.
$ sudo kubelet --version

$ kubectl version

# Hold the kubeadm, kubelet and kubectl pacakages.
$ sudo apt-mark hold kubeadm kubelet kubectl

# Restart kubelet.
$ sudo systemctl daemon-reload
$ sudo systemctl restart kubelet

# Confirm kubelet is running.
$ sudo systemctl status kubelet

# Back on master node, uncordon node1.
$ kubectl uncordon node1
node/node1 uncordoned  

# Confirm that node1 has been upgraded.
$ kubectl get nodes
NAME     STATUS   ROLES           AGE     VERSION
master   Ready    control-plane   6d16h   v1.26.4
node1    Ready    <none>          6d16h   v1.26.4 <-- Version number upgraded.
node2    Ready    <none>          6d15h   v1.26.0
```
Now we just repeat the same steps on node2.