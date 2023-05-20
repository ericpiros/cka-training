# Role Based Access Control
Role Based Access Control ([RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)) is a method of regulating access to your Kubernetes cluster. There are several objects involved in this process and it will easier to understand by doing an example.  

## Lets Create a User  
One of the things that can become a subject of an RBAC is a user. Kubernetes does not have any mechanism to create a user on the cluster. So user management will need to be handled by a different system. For a user to gain access to your cluster, it must be able to present a valid certificate signed by the cluster's certficate authority. Kubernetes can determine the username from the common name field in the "subject" of the cert. Detailed explanation of this can be read [here](https://kubernetes.io/docs/reference/access-authn-authz/authentication/).  

## Lets Give Our Users a Valid Certificate
Lets create 2 users. We will call them "vagrant" and "vagrant_admin". This way it will match the user name in our Vagrant boxes.  
```
# This can be done either on the jumpbox or on the master node.
$ openssl genrsa -out vagrant.pem
$ openssl genrsa -out vagrant_admin.pem

$ openssl req -new -key vagrant.pem -out vagrant.csr -subj "/CN=vagrant"
$ openssl req -new -key vagrant_admin.pem -out vagrant_admin.csr -sub "/CN=vagrant_admin"
```  
Next we will ask our API server to sign the certificates. For this we will create a ['CertificateSigningRequest'](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/) object.  
```
# This must be run on where our **".csr"** file is located.
# Convert our CSR to base64 and remove all new lines.
$ cat vagrant.csr | base64 | tr -d '\n'
$ LS0tLS1CRUdJTiB...                            <-- Copy this value.

$ cat vagrant_admin.csr | base64 | tr -d '\n'
$ LS0tLS1CRUdJTiB...                            <-- Copy this value.

# We will create a CertificateSigningRequest manifest on our master node.
$ cat <<'EOF'>> vagrant_csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: csr-vagrant
spec:
  groups:
  - system:authenticated
  request: LS0tLS1CRUdJTiB...                    <-- The value we got above.
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 315569260
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF

$ cat <<'EOF'>> vagrant_admin_csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: csr-vagrant-admin
spec:
  groups:
  - system:authenticated
  request: LS0tLS1CRUdJTiB...                    <-- The value we got above.
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 315569260
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF
```
Next let us apply our CertificateSigningRequest manifests.  
```
# Apply the manifests.
$ kubectl create -f vagrant_csr.yaml
certificatesigningrequest.certificates.k8s.io/csr-vagrant created
$ kubectl create -f vagrant_admin_csr.yaml
certificatesigningrequest.certificates.k8s.io/csr-vagrant-admin created

# Confirm that our requests have been created.
$ kubectl get csr
NAME                   AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
csr-vagrant            85s   kubernetes.io/kube-apiserver-client   kubernetes-admin   10y                 Pending
csr-vagrant-admin      51s   kubernetes.io/kube-apiserver-client   kubernetes-admin   10y                 Pending
```  

As can be seen above, our certificate signing requests have been create but are in a pending state. We will need to approve our requests to completed the process.  
```
# Approve the requests.
$ kubectl certificate approve csr-vagrant
certificatesigningrequest.certificates.k8s.io/csr-vagrant approved
$ kubectl certificate approve csr-vagrant-admin
certificatesigningrequest.certificates.k8s.io/csr-vagrant-admin approved

# Confirm that the requests have been approved.
$ kubectl get csr
NAME                   AGE     SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
csr-vagrant            4m33s   kubernetes.io/kube-apiserver-client   kubernetes-admin   10y                 Approved,Issued
csr-vagrant-admin      3m59s   kubernetes.io/kube-apiserver-client   kubernetes-admin   10y                 Approved,Issued
```  

Now that we have our certificated signed by the API server, we can use these to create a kubeconfig file. First let us extract the certificates.  
```
# Extract the certificate file.
$ kubectl get csr csr-vagrant -o jsonpath='{.status.certificate}' | base64 -d > vagrant-user.crt
$ kubectl get csr csr-vagrant-admin -o jsonpath='{.status.certificate}' | base64 -d > vagrant-admin.crt

# Confirm certificate CN.
$ openssl x509 -in vagrant-user.crt --noout -subject
subject=CN = vagrant
$ openssl x509 -in vagrant-admin.crt --noout -subject
subject=CN = vagrant_admin
```  

Now we can create a kubeconfig file with our users. We will be doing the following:  
* Set the cluster details.
* Set the user credentials.
* Create a context for both vagrant and vagrant-admin.  
```
# First we need a few details of the cluster. Namely the address and name of our cluster.
$ kubectl config get-clusters
NAME
kubernetes
$ kubectl cluster-info
Kubernetes control plane is running at https://192.168.56.5:6443   <-- We will need this.
CoreDNS is running at https://192.168.56.5:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

# Create the kubeconfig file with the cluster details. We will name our kubeconfig vagrant-kubeconfig.
$ kubectl --kubeconfig vagrant-kubeconfig config set-cluster kubernetes --insecure-skip-tls-verify=true --server=https://192.168.56.5:6443
Cluster "kubernetes" set.

# Set vagrant and vagrant-admin in he kubeconfig.
$ kubectl --kubeconfig vagrant-kubeconfig config set-credentials vagrant --client-certificate=vagrant-user.crt --client-key=vagrant.pem --embed-certs=true
User "vagrant" set.
$ kubectl --kubeconfig vagrant-kubeconfig config set-credentials vagrant_admin --client-certificate=vagrant-admin.crt --client-key=vagrant_admin.pem --embed-certs=true
User "vagrant_admin" set.

# Create our vagrant and vagrant-admin context, which combines a user and cluster information.
$ kubectl --kubeconfig vagrant-kubeconfig config set-context vagrant --cluster=kubernetes --user=vagrant
Context "vagrant" created.
$ kubectl --kubeconfig vagrant-kubeconfig config set-context vagrant_admin --cluster=kubernetes --user=vagrant_admin
Context "vagrant_admin" created.

# Lets set the vagrant context as the default.
$ kubectl --kubeconfig vagrant-kubeconfig config use-context vagrant
Switched to context "vagrant".

# Check that our contexts have been set on the kubeconfig file that we created.
$ kubectl --kubeconfig ./vagrant-kubeconfig config get-contexts
CURRENT   NAME            CLUSTER      AUTHINFO        NAMESPACE
*         vagrant         kubernetes   vagrant         
          vagrant_admin   kubernetes   vagrant_admin   
$ kubectl --kubeconfig ./vagrant-kubeconfig config get-users
NAME
vagrant
vagrant_admin

# See if our vagrant user can do anything on the cluster.
$ kubectl --kubeconfig vagrant-kubeconfig get pods
Error from server (Forbidden): pods is forbidden: User "vagrant" cannot list resource "pods" in API group "" in the namespace "default"
```  

As can be seen, our user is authenticated by the fact that the API is actually responding to our kubectl calls, how as can be seen, our vagrant user (or even our vagrant-admin user) has no permissions whatsoever.  Here is where [**Roles**](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) and [**ClusterRoles**](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) come into play.  

First let us move the kubeconfig that we created to our jumpbox server.  
```
# Move the file vagrant-kubeconfig to jumpbox.
# on the master server.
$ scp ./vagrant-kubeconfig vagrant@jumpbox.local:~/config
The authenticity of host 'jumpbox.local (192.168.56.4)' can't be established.
ECDSA key fingerprint is SHA256:fXCVDKCxyMfYiK0dzRu4QZ5HJBL2tIJarOmkd52aBYc.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'jumpbox.local,192.168.56.4' (ECDSA) to the list of known hosts.
vagrant@jumpbox.local's password: 
vagrant-kubeconfig

# On Jumpbox
$ mkdir -p .kube
$ cp config .kube

# Install kubectl on Jumpbox if you have not yet already done so. kubectl is available as a snap on Ubuntu 20.04.
$ sudo snap install kubectl --classic
kubectl 1.27.2 from Canonical✓ installed

$ Confirm that kubectl is installed and can see our kubeconfig in /home/vagrant/.kube/config.
$ kubectl config get-contexts
CURRENT   NAME            CLUSTER      AUTHINFO        NAMESPACE
*         vagrant         kubernetes   vagrant         
          vagrant_admin   kubernetes   vagrant_admin 
```  

Now that kubectl is installed on our jumpbox and we have our kubeconfig set with 2 users, lets us create a Role.  

## Role and ClusterRole
Roles and ClusterRoles are pretty much the same in that they define what API commands can be performed. The only difference between them is that a Role is bound to a namespace (or namespaces) and a ClusterRole is bound cluster wide. Lets create a Role and ClusterRole that allows the same action. Lets say we want to grant our users the ability to list pods.  
```
# Create a role that can read pods. This must be done on the master server first.
$ kubectl create role pod-reader --resource=pods --verb=get --verb=list --verb=list --namespace=default
role.rbac.authorization.k8s.io/pod-reader created

# Confirm our role.
$ kubectl get role pod-reader -n default -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  creationTimestamp: "2023-05-20T06:50:51Z"
  name: pod-reader
  namespace: default
  resourceVersion: "69773"
  uid: f8efdfbc-dc4b-4479-ac3c-1854970842c5
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list

# Create our clusterrole
$ kubectl create clusterrole pod-reader-cluster --resource=pods --verb=get --verb=list --verb=watch
clusterrole.rbac.authorization.k8s.io/pod-reader-cluster created

# Confirm our clusterrole.
$ kubectl get clusterrole pod-reader-cluster -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: "2023-05-20T06:54:23Z"
  name: pod-reader-cluster
  resourceVersion: "70093"
  uid: 25666a8a-36f8-4432-85b7-a2cd1b95110e
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch
```  

As can be seen above, both look the same. The only difference is that ClusterRole does not need a namespace specified. Now just creating roles is not enough. In fact if you try doing the 'kubectl get pods' command in our jumpbox, you will get the same error. This is because we have not **binded** our role or ClusterRole to any subject. We can do this by creating a **rolebinding** or **clusterrolebinding** object. As with roles and ClusterRoles, the difference between the 2 is that you need to specify a namespace on a rolebinding, whereas you do not have to define this on clusterrolebinding.  

Let us bind our pod-reader role to the user vagrant. Then let us bind pod-reader-cluster cluster role to vagrant-admin.  
```
# Use rolebinding to attach the pod-reader role to our vagrant user.
$ create rolebinding vagrant-pod-reader --role=pod-reader --user=vagrant --namespace=default
rolebinding.rbac.authorization.k8s.io/vagrant-pod-reader created

# Confirm our role binding.
$ kubectl get rolebinding vagrant-pod-reader -n=default -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  creationTimestamp: "2023-05-20T07:03:52Z"
  name: vagrant-pod-reader
  namespace: default
  resourceVersion: "70949"
  uid: 99642350-92d3-4923-96ef-106960ae34a9
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: vagrant

# User clusterrolebinding to attach pod-reader-cluster to our vagrant-admin user.
$ kubectl create clusterrolebinding vagrant-admin-pod-reader-cluster --clusterrole=pod-reader-cluster --user=vagrant_admin
clusterrolebinding.rbac.authorization.k8s.io/vagrant-admin-pod-reader-cluster created

# Confirm our cluster role binding.
$ kubectl get clusterrolebinding vagrant-admin-pod-reader-cluster -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  creationTimestamp: "2023-05-20T07:08:36Z"
  name: vagrant-admin-pod-reader-cluster
  resourceVersion: "71376"
  uid: a7be37c6-56ad-4bcf-844d-5b87ce9ff4b9
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-reader-cluster
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: vagrant_admin
```  

As can be seen, their definitions are the same with the only difference being that rolebinding requires a namespace to be specified.  

Lets test out our roles. Lets go over to Jumpbox.  
```
# On Jumpbox.
# Lets confirm that we are using the vagrant contexts.
$ kubectl config current-context
vagrant

# Lets view our pods.
$ kubectl get pods
NAME            READY   STATUS    RESTARTS       AGE
nginx           1/1     Running   13 (52m ago)   20d
nginx2          1/1     Running   6 (52m ago)    14d
nginx3-master   1/1     Running   5 (53m ago)    11d
$ kubectl get pods -n kube-system
Error from server (Forbidden): pods is forbidden: User "vagrant" cannot list resource "pods" in API group "" in the namespace "kube-system"

# Lets switch to the vagrant-admin context.
$ kubectl config use-context vagrant_admin
Switched to context "vagrant_admin".
$ kubectl config current-context
vagrant_admin

# Lets run the same commands as above.
$ kubectl get pods
NAME            READY   STATUS    RESTARTS       AGE
nginx           1/1     Running   13 (72m ago)   20d
nginx2          1/1     Running   6 (73m ago)    14d
nginx3-master   1/1     Running   5 (73m ago)    12d
$ kubectl get pods -n kube-system
NAME                             READY   STATUS    RESTARTS       AGE
coredns-787d4945fb-h8dl9         1/1     Running   14 (74m ago)   26d
coredns-787d4945fb-v92dc         1/1     Running   14 (74m ago)   26d
etcd-master                      1/1     Running   7 (74m ago)    13d
kube-apiserver-master            1/1     Running   21 (74m ago)   24d
kube-controller-manager-master   1/1     Running   18 (74m ago)   24d
kube-proxy-42n4m                 1/1     Running   13 (74m ago)   20d
kube-proxy-7d8dk                 1/1     Running   13 (73m ago)   20d
kube-proxy-qh64n                 1/1     Running   14 (74m ago)   24d
kube-scheduler-master            1/1     Running   18 (74m ago)   24d
```  

As can be seen, our vagrant_admin user has more access than our vagrant user because of the scope of the role bound to them. Before going into details of the role and clusterrole parameters, I would like to point out 1 more thing. You can bind a clusterrole to a user using a rolebinding.  
```
# On the master server.
# Remove the pod-reader binding to our vagrant user.
$ kubectl delete rolebinding vagrant-pod-reader
rolebinding.rbac.authorization.k8s.io "vagrant-pod-reader" deleted

# On jumpbox server.
# Confirm that our binding is gone.
$ kubectl config use-context vagrant
Switched to context "vagrant".
$ kubectl get pods
Error from server (Forbidden): pods is forbidden: User "vagrant" cannot list resource "pods" in API group "" in the namespace "default"

# On master server.
# Bind pod-reader-cluster using a role to our vagrant user.
$ kubectl create rolebinding vagrant-pod-reader-cluster --clusterrole=pod-reader-cluster --user=vagrant -n=default
rolebinding.rbac.authorization.k8s.io/vagrant-pod-reader-cluster created

# Confirm our rolebinding.
$ kubectl get rolebinding vagrant-pod-reader-cluster -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  creationTimestamp: "2023-05-20T07:50:39Z"
  name: vagrant-pod-reader-cluster
  namespace: default
  resourceVersion: "75194"
  uid: c8d4a539-8d9e-42bc-9e8c-7b22db1a6db9
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-reader-cluster
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: vagrant

# On jumpbox.
# Lets test to see what pods we can see.
$ kubectl get pods
NAME            READY   STATUS    RESTARTS       AGE
nginx           1/1     Running   13 (90m ago)   20d
nginx2          1/1     Running   6 (90m ago)    14d
nginx3-master   1/1     Running   5 (91m ago)    12d

$ kubectl get pods -n kube-system
Error from server (Forbidden): pods is forbidden: User "vagrant" cannot list resource "pods" in API group "" in the namespace "kube-system"
```  

As can be seen, we binded a cluster role to our vagrant user. But since we used a rolebinding, which is bound to a namespace, it effectively limits the scope of our cluster role. This is useful for situations where you need a role that will be used by different users across different namespaces. This way you do not have to create the same role on all namespaces.  

## Role/ClusterRole Parameters