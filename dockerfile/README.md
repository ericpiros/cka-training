# CKA Training - Kubernetes the Hard Way docker client
This contains the docker file that will create an image that has the following installed:  
* cfssl
* cfssljson
* kubectl
The image is currently based on the [kroniak/ssh-client](https://hub.docker.com/r/kroniak/ssh-client/) image. This itself is based on Alpine linux 3.15 with the openssh-client and bash installed.

# Why use a prebuilt image?
As much as I would like to create my own client from scratch and base it on Ubuntu (to make all my client and server be the same version), I quickly learned that installing the ssh-client on the [official Ubuntu image](https://hub.docker.com/_/ubuntu) is not as straight forward as I first thought. I am getting errors when running apt-get update and I do not have time to troubleshoot this at this point.  
I will probably revisit this in the future when I get more time.