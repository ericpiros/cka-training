# Configmaps
Configmaps can be used to store data in key-value pairs. These can then be consumed by pods as either environment variables or as configuration files in a volume.  

Configmaps are namespace bound. They can be created through the 'kubectl create configmap' command or through a manifest file.  
```
# Creating a a configmap through kubectl create
$ kubectl create configmap sample-config --from-literal=sample-key=sample-value
configmap/sample-config created

# Checking the value in our created configmap
$ kubectl get configmap sample-config --output=yaml
apiVersion: v1
data:
  sample-key: sample-value
kind: ConfigMap
metadata:
  creationTimestamp: "2023-11-18T23:28:23Z"
  name: sample-config
  namespace: default
  resourceVersion: "41029"
  uid: 7862a704-b1d4-460a-8d75-745b5db3b75b
```  
The example above creates a single value configmap. The manifest below also creates the same output.
```
# YAML manifest for configmap.
apiVersion: v1
data:
  sample-key: sample-value
kind: ConfigMap
metadata:
  name: sample-config
data:
  sample-key: sample-value
```
Note that we can also create a multi-line value for configmap which can look like a configuration file.
```
# Sample multi-line configmap.
$ vim multi-line-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-line-configmap
data:
  multi-line-config: | # <--- Take note of the pipe 
    config1=value1
    config2=value2
    config3=value3

$ kubectl create -f multi-line-configmap.yaml
configmap/multi-line-configmap created

# Checking the value in our configmap.
$ kubectl get configmap multi-line-configmap --output=yaml
apiVersion: v1
data:
  multi-line-config: |
    config1=value1
    config2=value2
    config3=value3
kind: ConfigMap
metadata:
  creationTimestamp: "2023-11-18T23:47:05Z"
  name: multi-line-configmap
  namespace: default
  resourceVersion: "44290"
  uid: de92e1e1-b151-41f6-ad0e-275930d43304
```
  