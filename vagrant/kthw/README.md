# CKA Training - ACG Kubernetes The Hard Way Vagrant Client
This will spin up an Ubuntu 20.04 client with the tools necessary to complete the ACG version of the Kubernetes The Hard Way course. In particular this will include the following software:  
* cfssl 1.2.0
* cfssljson 1.2.0
* kubectl 1.10.2
* openssh-client  

# Requirements and usage
You will need to have Vagrant installed to spin this up. On this folder run:  
```
$ vagrant up
```
If you wish to pause the VM you can run:
```
$ vagrant suspend
```
If you want to delete the VM you can run:
```
$ vagrant destroy
```

# Synced folder
A folder called kthw will be created on the local host and mounted to /home/vagrant/kthw on the VM. This where I would recommend you place all of the certificates and kubeconfig files that will be generated during the course. The contents of the folder will not be deleted even if you run a 'vagrant destroy' so this will be usefull if you wish to use some of the cerficates or kubeconfig files outside of the client, or on another client.