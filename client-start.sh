#!/bin/bash

# Launch a temporary docker container with the required tools to complete the course:
# Kubernetes the hard way. See dockerfile/README.md for details.

# This will mount the 'home' directory in this project to the container. Replace if you want to use a different volume.
HOME_DIR=`pwd`/home
# Default name of the CKA Training image. Change this if you named your image differently.
CKA_IMAGE = ckatraining

docker container run --name cka --volume $HOME_DIR:/home/cka_user --rm -i --tty $CKA_IMAGE