#!/bin/bash

HOME_DIR=`pwd`/home

docker container run --name cka --volume $HOME_DIR:/home/cka_user --rm -i --tty ckatraining