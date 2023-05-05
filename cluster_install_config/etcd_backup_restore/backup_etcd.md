# Backup ETCD

## Pre-requisites
Before we begin, lets get a few things setup. First we will need to have ETCD utilities installed on either our jumpbox or the master server. There are several ways to do this:  
* Through the package manager.
```
# Install etcdctl through the package manager.
$ sudo apt update
$ sudo apt install -y etcd-client

# Confirm that etcdctl is installed.
$ etcdctl --version
etcdctl version: 3.2.26
API version: 2 <-- Take note of the API version.
```
* By downloading the binaries from their [github](https://github.com/etcd-io/etcd/releases/) page.
```
# Download from their github page. This assumes that you have a directory called "downloads" in your home directory.
$ curl -L https://github.com/etcd-io/etcd/releases/download/v3.4.25/etcd-v3.4.25-linux-amd64.tar.gz -o downloads/etcd-v3.4.25-linux-amd64.tar.gz

# Extract the contents of the zip file.
$ tar -zxvf downloads/etcd-v3.4.25-linux-amd64.tar.gz

# This should have extracted the contents into your home directory. We are only interested in etcdctl so we can test that it works.
$ ./etcd-v3.4.25-linux-amd64/etcdctl version <-- notice that there is "--" in front of the version flag.
etcdctl version: 3.4.25
API version: 3.4 <-- notice that it defaults to API version 3.4
# From here you can copy etcdctl to /usr/bin or to some other location that is on your path.
```
* By running "kubectl exec" (this only works if you used kubeadm to install your cluster, or you are running ETCD as a container).
```
# First lets determine which pod ETCD is in.
$ kubectl get pods -n kube-system
NAME                             READY   STATUS    RESTARTS      AGE
coredns-787d4945fb-h8dl9         1/1     Running   5 (23m ago)   11d
coredns-787d4945fb-v92dc         1/1     Running   5 (23m ago)   11d
etcd-master                      1/1     Running   9 (23m ago)   13d <-- This is what we want
kube-apiserver-master            1/1     Running   5 (23m ago)   9d
kube-controller-manager-master   1/1     Running   5 (23m ago)   9d
kube-proxy-42n4m                 1/1     Running   4 (23m ago)   6d11h
kube-proxy-7d8dk                 1/1     Running   4 (22m ago)   6d11h
kube-proxy-qh64n                 1/1     Running   5 (23m ago)   9d
kube-scheduler-master            1/1     Running   5 (23m ago)   9d

# Run etcdctl through kubectl exec.
$ kubectl exec etcd-master -n kube-system -- etcdctl version
etcdctl version: 3.5.6
API version: 3.5 <-- This one is also set to API version 3
```
Now that we have "etcdctl" installed, let take a look at what information is stored inside our etcd. To do this, we need to take note of several things:
* The client endpoint.
* The CA Cert.
* The etcd certificate.
* The etcd key.  

We can get all this information either by taking a look at the manifest, or describing the etcd-master pod.
```
# Get the endpoing, cacert, cert and key values.
$ sudo cat /etc/kubernetes/manifests/etcd.yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubeadm.kubernetes.io/etcd.advertise-client-urls: https://192.168.56.5:2379
  creationTimestamp: null
  labels:
    component: etcd
    tier: control-plane
  name: etcd
  namespace: kube-system
spec:
  containers:
  - command:
    - etcd
    - --advertise-client-urls=https://192.168.56.5:2379
    - --cert-file=/etc/kubernetes/pki/etcd/server.crt                      <-- this is the ETCD cert file.
    - --client-cert-auth=true                                              <-- this is the reason why we need the cacert flag.
    - --data-dir=/var/lib/etcd
    - --experimental-initial-corrupt-check=true
    - --experimental-watch-progress-notify-interval=5s
    - --initial-advertise-peer-urls=https://192.168.56.5:2380
    - --initial-cluster=master=https://192.168.56.5:2380
    - --key-file=/etc/kubernetes/pki/etcd/server.key                        <-- this is the ETCD key file.
    - --listen-client-urls=https://127.0.0.1:2379,https://192.168.56.5:2379 <-- these are our endpoints.
    - --listen-metrics-urls=http://127.0.0.1:2381
    - --listen-peer-urls=https://192.168.56.5:2380
    - --name=master
    - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
    - --peer-client-cert-auth=true
    - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
    - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
    - --snapshot-count=10000
    - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt                     <-- This is the cacert file.
    image: registry.k8s.io/etcd:3.5.6-0
    imagePullPolicy: IfNotPresent
...
```

## Checking the Contents of ETCD
Now we can check what values are stored in our ETCD database.
```
# I have installed the etcd-client packakge so I have version 3.2 running.
# Get a list of all contents of our ETCD database. We will need to use "sudo" as our certificates are in a directory that only root has access to.
$ sudo ETCDCTL_API=3 etcdctl --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key --endpoints https://192.168.56.5:2379 get / --prefix --keys-only
...
/registry/services/endpoints/kube-system/kube-dns

/registry/services/specs/default/kubernetes

/registry/services/specs/default/nginx

/registry/services/specs/kube-system/kube-dns

# Check the contents of our nginx service.
$ sudo ETCDCTL_API=3 etcdctl --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key --endpoints https://192.168.56.5:2379 get /registry/services/specs/default/nginx
```
So we can see that our ETCD cluster has a list of all resources in our cluster set as a key-value pair.  

## Backing Up Our ETCD Database
To start backing up our ETCD database we can use the "etcdctl snapshot save" command as outlined [here](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster). There are a few things to take note of before we run the command:
* Ensure that we are using API version 3.
* We will need to pass the --cacert, --cert and --key flags to authenticate to the database.
* For --endpoints, we can use https://127.0.0.1:2379 if we are running the command on the master node. If you are running this on the jumpbox or any other node, you will need to use the https://192.168.56.5:2379 endpoint.
* If you do not specify the full path of the backup file, the snapshot will be created on your current working directory.