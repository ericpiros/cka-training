# 02-014-2023
* Initial version of this repository.
* Copied over the vagrant file that I am using to spin up 3 local VirtualBox servers.
* Updated README.md on the purpose of this document.
* Added a copy of the 126 CKA curriculum.

# 02-15-2023
* Added dockerfile that will create a client container with the required tools to proceed with the training.

# 02-17-2023
* Modified client docker image to use Ubuntu image.
* Created client-start script to start up my cka container and mount a local home folder.
* Downloaded the correct cfssl binary.  

# 02-20-2023
* Modified client-start.sh to set the home directory and image name as variables. Also added comments to the script to explain what can be changed.  
* Added 'How to build' and 'How to run' sections in the README.md for the DOCKERFILE.

# 03-09-2023
* Removed space on variable assignment on the client dockerfile.
* Downgraded kubectl version to 1.10.2 to match the k8s server version in the ACG Kubernetes The Hard Way course.
* Re-arranged the contents of the vagrant directory.
* Added a Vagrant config to spin up an Ubuntu client for the ACG Kubernetes The Hard Way course.

# 04-20-2023  
* Finished initial version of kubeadm install.
* Finalized Vagrantfile for kubeadm install instructions.

# 04-29-2023
* Finished initial version kubeadm upgrade.

# 05-05-2023
* Finished initial version of ETCD backup and restore.  

# 05-22-2023
* Finished initial version RBAC.
* Added libvirt version of vagrant setup.

# 06-10-2023
* Modified libvert version of HA cluster Vagrant file to not include secondary interfaces.
* Added disclaimer to HA section.
* Initial version of HA section.

# 11-10-2023
* Passed the CKA exam.
* Updated the libvirt vgrant files to make them more uniform.
* Updated k8s_req.sh to account for the expired gpg key on the K8S 1.26 install. New gpg keys and repos are now available on the official k8s documentation site.  

# 11-12-2023
* Updated HA cluster notes on how to check for ETCD members.