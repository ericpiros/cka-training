# CKA Training - Kubernetes the Hard Way docker client
This contains the docker file that will create an image that has the following installed:  
* cfssl - 1.6.3
* cfssljson - 1.6.3
* kubectl - 1.26.1
The binaries are located in the [dockerfile/binaries](dockerfile/binaries)folder.
The image is currently based on the [Ubuntu 22.04](https://hub.docker.com/_/ubuntu) image. Additional software installed are:  
* openssl-client
* neovim

# How to build
If you have the docker plugin for VSCode you can right click on the [DOCKERFILE](DOCKERFILE) and select **'Build image...'** to build it. Or you can run the following commands in the same folder as the DOCKERFILE:
```
docker build . -t ckatraining:latest
```  
# Running the container
There is a script in the root of this project called [client-start.sh](../client-start.sh) that will run the container for you. This will drop you into a prompt.  
Ideally you will want to mount a local folder on your machine to the **/home/cka_user** directory in the container so that any files that you create will be saved on your machine. There is **'home'** directory in this project which will be used by the client-start.sh script by default.  
Alternatively you can run this command at the root of this project:
```
$ docker container run --name cka_training --rm --volume `pwd`/home:/home/cka_user -i --tty ckatraining
```
The above command assumes that you are mounting the **'home'** folder on the root of the project and that you named your image **'ckatraining'**

# Issues encountered
I had network connectivity issues if my containers use the default bridge network. I later find out that this is due to me using the snap version of docker. Several post say that this can be resolved by adding an iptables entry to allow the docker user through the network, but I opted instead to replace the snap version with the docker.io deb package instead.