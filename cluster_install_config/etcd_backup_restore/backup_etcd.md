# Backup and Restore ETCD

## Useful Info
This [kodecloud community FAQ](https://github.com/kodekloudhub/community-faq/blob/main/docs/etcd-faq.md) is a must read before you tackle backup and restoration of the ETCD cluster. I would suggest reading it before going through my notes below.

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
$ ./etcd-v3.4.25-linux-amd64/etcdctl version <-- notice that there is no "--" in front of the version flag.
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
etcd-master                      1/1     Running   9 (23m ago)   13d <-- This is the pod that we want.
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

We can get all this information either by taking a look at the *manifest*, or describing the etcd-master pod.
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
<-- Output Truncated -->
```

## Checking the Contents of ETCD
Now we can check what values are stored in our ETCD database.
```
# I have installed the etcd-client packakge so I have version 3.2 running.
# Get a list of all contents of our ETCD database. We will need to use "sudo" as our certificates are in a directory that only root has access to.
$ sudo ETCDCTL_API=3 etcdctl get / --prefix --keys-only \
 --cacert /etc/kubernetes/pki/etcd/ca.crt \
 --cert /etc/kubernetes/pki/etcd/server.crt \
 --key /etc/kubernetes/pki/etcd/server.key \
 --endpoints https://192.168.56.5:2379   <-- we can also use the https://127.0.0.1:2379 endpoint if we are running this command on the master node.

<-- Output Truncated -->
/registry/services/endpoints/kube-system/kube-dns

/registry/services/specs/default/kubernetes

/registry/services/specs/default/nginx

/registry/services/specs/kube-system/kube-dns

# Check the contents of our nginx service.
$ sudo ETCDCTL_API=3 etcdctl get /registry/services/specs/default/nginx \
 --cacert /etc/kubernetes/pki/etcd/ca.crt \
 --cert /etc/kubernetes/pki/etcd/server.crt \
 --key /etc/kubernetes/pki/etcd/server.key \
 --endpoints https://192.168.56.5:2379 
```  

So we can see that our ETCD cluster has a list of all resources in our cluster set as a key-value pair.  

## Backing Up Our ETCD Database
To start backing up our ETCD database we can use the "etcdctl snapshot save" command as outlined [here](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster). There are a few things to take note of before we run the command:
* Ensure that we are using API version 3.
* We will need to pass the --cacert, --cert and --key flags to authenticate to the database.
* For --endpoints, we can use https://127.0.0.1:2379 if we are running the command on the master node. If you are running this on the jumpbox or any other node, you will need to use the https://192.168.56.5:2379 endpoint.
* If you do not specify the full path of the backup file, the snapshot will be created on your current working directory.  

With those in mind lets back up our ETCD database on the master server. If you want to run the backup on another server, remember to copy the certificates under "/etc/kubernetes/pki/etcd" to the server you want to run the backup on.  
```
# Backup the current ETCD database to a file called etcd_backup.db.
$ sudo ETCDCTL_API=3 etcdctl snapshot save etcd_backup.db \
 --cacert /etc/kubernetes/pki/etcd/ca.crt \
 --cert /etc/kubernetes/pki/etcd/server.crt \
 --key /etc/kubernetes/pki/etcd/server.key \
 --endpoints https://192.168.56.5:2379 
Snapshot saved at etcd_backup.db

# Confirm that the snapshot had been created.
$ ls -l
total 3164
-rw-r--r-- 1 root    root    3227680 May  6 03:37 etcd_backup.db <-- take note of the file ownership.
-rw-rw-r-- 1 vagrant vagrant    4482 Apr 22 15:58 kube-flannel.yml

# Create a backup in a directory called "backup" in the current working directory.
$ mkdir -p backup
$ sudo ETCDCTL_API=3 etcdctl snapshot save backup/etcd_backup.db \
 --cacert /etc/kubernetes/pki/etcd/ca.crt \
 --cert /etc/kubernetes/pki/etcd/server.crt \
 --key /etc/kubernetes/pki/etcd/server.key \
 --endpoints https://192.168.56.5:2379 
Snapshot saved at backup/etcd_backup.db

$ ls -l backup/
total 3272
-rw-r--r-- 1 root root 3346464 May  6 03:40 etcd_backup.db
```  

We can verify the state of the backup by running the "etcdctl snapshop status" command. Note that since we are inspecting the snapshot, we do not need to pass the authentication flags (--cacert, --cert and --key) and endpoints flag to the command. Do note that since the owner of the file is "root" we will need to use sudo on our command or else we will get a permission denied error when running the command.  
```
# Verify status of the snapshot.
$ sudo ETCDCTL_API=3 etcdctl snapshot status backup/etcd_backup.db --write-out=table
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 968d895b |    37913 |       1019 |     3.3 MB | <-- take note of the number of keys and revision in this snapshot.
+----------+----------+------------+------------+
```  

Now lets spin up another pod and do another back up and see if the "REVISION" goes up and the "TOTAL KEYS" change.
```
# Spin up a new pod.
$ kubectl run nginx2 --image=nginx
pod/nginx2 created

# Confirm that it is up and running.
$ kubectl get pods
NAME     READY   STATUS    RESTARTS      AGE
nginx    1/1     Running   5 (19m ago)   6d19h
nginx2   1/1     Running   0             34s    <-- here it is.

# Create a new backup.
$ sudo ETCDCTL_API=3 etcdctl snapshot save backup/etcd_backup_latest.db \
 --cacert /etc/kubernetes/pki/etcd/ca.crt \
 --cert /etc/kubernetes/pki/etcd/server.crt \
 --key /etc/kubernetes/pki/etcd/server.key \
 --endpoints https://192.168.56.5:2379 
Snapshot saved at backup/etcd_backup_latest.db

# Confirm that it has been created.
$ ls -l backup/
 total 6544
-rw-r--r-- 1 root root 3346464 May  6 03:43 etcd_backup.db
-rw-r--r-- 1 root root 3346464 May  6 03:50 etcd_backup_latest.db <-- this is our new backup.

# Get the status and compare the number of keys in this version of the backup.
$ sudo ETCDCTL_API=3 etcdctl snapshot status backup/etcd_backup_latest.db --write-out=table
+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| c1bd4b5e |    38796 |       1004 |     3.3 MB | <-- revision numnber and total keys have change.
+----------+----------+------------+------------+
```

So we now have 2 backup states. In the first snapshot we do not have a pod name nginx2 running. On the 2nd snapshot we have it present. To restore a snapshot, we only need 1 "db" file and use the "etcdctl snapshot restore" command. Now it is important to note that restoring a snapshot creates a new data directory, basically we are creating a new version of the DB. This is the case with most DB snapshot restoration. As such when we are restoring the snapshot, there are 2 ways we can do it. First we can delete the current data directory and restore to that location (by default the etcd data directory is /var/lib/etcd). Second, we can restore to a different directory and modify our etcd manifest to use the new data directory.  

Lets first try restoring to the default /var/lib/etcd directory. First lets take know of the ownership of the /var/lib/etcd directory,
```
# Let confirm the owner of the /var/lib/etcd directory'
$ sudo ls -l /var/lib | grep etcd
drwx------  3 root      root      4096 May  6 03:28 etcd

# Lets confirm what pods are in the default namespace.
$ kubectl get pods
NAME     READY   STATUS    RESTARTS       AGE
nginx    1/1     Running   5 (113m ago)   6d21h
nginx2   1/1     Running   0              94m

# First we need to remove th /var/lib/etcd directory as the restore will fail if the directory exists.
$ sudo rm -rf /var/lib/etcd

# Next lets restore to the version that does not have the nginx2 pod (the snapshot name etcd_backup.db). We use sudo since the target directory is owned by root.
$ sudo ETCDCTL_API=3 etcdctl snapshot restore backup/etcd_backup.db --data-dir=/var/lib/etcd --skip-hash-check
2023-05-06 06:09:23.559768 I | mvcc: restore compact to 37297
2023-05-06 06:09:23.570436 I | etcdserver/membership: added member 8e9e05c52164694d [http://localhost:2380] to cluster cdf818194e3a8c32

# Check our pods to see if nginx2 is present.
$ kubectl get pods
NAME    READY   STATUS    RESTARTS       AGE
nginx   1/1     Running   5 (169m ago)   6d21h

```

Note that since we did not stop the etcd service, there might be situations where restoring will fail as the directory gets recreated. If this happens, just delete the directory again and run the restore. You can also stop the etcd service (by removing etcd.yaml in /etc/kubernetes/manifests) before deleting the /var/lib/etcd directory. Doing this will bring our Kubernetes cluster down (if this we production and we only have 1 etcd service running, then we will have an outage). Note that after restoring data, it can take 60 seconds before everthing becomes stable.  

Next let us try to restore to a different location. This is a better solution when restoring rather than deleting the current data directory as you can revert back to the old version if needed.
```
# Check what pods are running in the default namespace.
$ kubectl get pods
NAME    READY   STATUS    RESTARTS        AGE
nginx   1/1     Running   6 (3m28s ago)   7d5h

# Restore backup/etcd_backup_latest.db to /var/lib/etcd_latest
$ sudo ETCDCTL_API=3 etcdctl snapshot restore backup/etcd_backup_latest.db --data-dir=/var/lib/etcd_latest --skip-hash-check
2023-05-06 14:22:24.077780 I | mvcc: restore compact to 38197
2023-05-06 14:22:24.099335 I | etcdserver/membership: added member 8e9e05c52164694d [http://localhost:2380] to cluster cdf818194e3a8c32

# Lets check if the directory /var/lib/etcd_latest
$ sudo ls -l /var/lib/etcd_latest
total 4
drwx------ 4 root root 4096 May  6 14:22 member

# Now we have tell our ETCD container to use the new data directory. The file we need to edit is /etc/kubernetes/manifests/etcd.yaml
$ sudo cat /etc/kubernetes/manifests/etcd.yaml | grep volumes -A 8
  volumes:
  - hostPath:
      path: /etc/kubernetes/pki/etcd
      type: DirectoryOrCreate
    name: etcd-certs
  - hostPath:
      path: /var/lib/etcd <-- change this to /var/lib/etcd_latest
      type: DirectoryOrCreate
    name: etcd-data

# After editing and saving etcd.yaml, lets wait a minute before checking our pods in the default namespace.
$ kubectl get pods
NAME     READY   STATUS    RESTARTS      AGE
nginx    1/1     Running   5 (11h ago)   7d6h
nginx2   1/1     Running   0             10h  <-- the nginx2 pod is back.
```

Here we have successfully backed up and restored our ETCD server.