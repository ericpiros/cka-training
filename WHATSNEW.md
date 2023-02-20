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