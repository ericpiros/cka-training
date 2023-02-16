# CKA Training - Kubernetes the Hard Way docker client
This contains the docker file that will create an image that has the following installed:  
* cfssl
* cfssljson
* kubectl
The image is currently based on the [Ubuntu 22.04](https://hub.docker.com/_/ubuntu) image. Additional software installed are:  
* openssl-client
* neovim

# Issues encountered
I had network connectivity issues if my containers use the default bridge network. I later find out that this is due to me using the snap version of docker. Several post say that this can be resolved by adding an iptables entry to allow the docker user through the network, but I opted instead to replace the snap version with the docker.io deb package instead.