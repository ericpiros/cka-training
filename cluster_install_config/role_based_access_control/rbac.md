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
Lets look at a role manifest and look at the parameters:  
```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: <Name>
rules:
- apiGroups:
  - <API Groups>
  resourceNames:
  - <Resource Names>
  resources:
  - <Resources> 
  verbs:
  - <Verbs>
  ```  

  These are the parameters we can set:  
  * API Group - the Kubernetes APIs are grouped to make it possible to easily extend it. There is the "core" group with REST path /api/v1. On the manifest file, this is identified as "" (an empty double quotes). You can find a list of API groups [here](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.27/#-strong-api-groups-strong-).  
  Another possible way of seeing the API group of a resource you want is inspecting the output of a kubectl command with verbosity set to 9:  
  ```
  # Check pod creation POST URL:
  $ kubectl run test-pod --image=nginx -v 9
  <--- Ouput truncated --->
  I0520 14:37:49.006860    9753 round_trippers.go:553] POST https://192.168.56.5:6443/api/v1/namespaces/default/pods?fieldManager=kubectl-run 201 Created in 16 milliseconds

  # Check role creation POST URL:
  $ kubectl create role test-role --resource=pods --verb=get -v 9
  <--- Output truncated --->
  I0520 14:39:15.263613   10139 round_trippers.go:553] POST https://192.168.56.5:6443/apis/rbac.authorization.k8s.io/v1/namespaces/default/roles?fieldManager=kubectl-create&fieldValidation=Strict 201 Created in 14 milliseconds
  ```  
  Lets look at the URL that was posted, in particular we are interested in the part after the API server address.  
  On the pod creation command it is /api/v1, this means that pod is in the "core" API group. Meanwhile for the creation of the role, it is /apis/rbac.authorization.k8s.io/v1. This means that the role API is in the rbac.authorization.k8s.io group. We can verify this by creating a template with "role" as the resource:  
  ```
  # Create a role with 'role' as the resource.
  $ kubectl create role test-role --resource=role --verb=get --dry-run=client -o=yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    creationTimestamp: null
    name: test-role
  rules:
  - apiGroups:
    - rbac.authorization.k8s.io  <-- note the API group.
    resources:
    - roles
    verbs:
    - get
  ```  

  * Resources - this the list of resources that you wish to enable access to. You can get list of resources on the API documentation shown above, or you can run the command:  
  ```
  # List API resources available on your cluster.
  $ kubectl api-resources
  NAME                              SHORTNAMES   APIVERSION                             NAMESPACED   KIND
  bindings                                       v1                                     true         Binding
  componentstatuses                 cs           v1                                     false        ComponentStatus
  configmaps                        cm           v1                                     true         ConfigMap
  endpoints                         ep           v1                                     true         Endpoints
  <--- Output truncated --->
  ```  

  * Verb - the REST API verbs you wish to grant on the resources you have listed. These are the actions you want your user/service account to be able to do on the resource. Kubernetes supports the standard HTTP verbs and adds it own:  
    * GET
    * POST
    * PUT
    * PATCH
    * DELETE
    * watch
    * list
  
  * Resource Names - allows you to limit the actions to an individual instance of a resource.

### Test the Resource Name parameter  
Lets try out the resource-name parameter:  
```
# On the master server.
# remove our rolebinding on the vagrant user.
$ kubectl delete rolebinding vagrant-pod-reader-cluster
rolebinding.rbac.authorization.k8s.io "vagrant-pod-reader-cluster" deleted

# lets get a list of pods in our default namespace.
$ kubectl get pods
NAME            READY   STATUS    RESTARTS       AGE
nginx           1/1     Running   14 (63m ago)   21d
nginx2          1/1     Running   7 (63m ago)    14d
nginx3-master   1/1     Running   6 (64m ago)    12d

# Now lets create a role that limits a user to pods named 'nginx'.
$ kubectl create role nginx-pod-all --resource=pods --verb=* --resource-name=nginx --namespace=default
role.rbac.authorization.k8s.io/nginx-pod-all created
$ kubectl get role nginx-pod-all -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  creationTimestamp: "2023-05-20T15:33:46Z"
  name: nginx-pod-all
  namespace: default
  resourceVersion: "84710"
  uid: 2f432ede-ca7c-4361-afe6-d6382c760579
rules:
- apiGroups:
  - ""
  resourceNames:
  - ngin*
  resources:
  - pods
  verbs:
  - '*'


# Now lets bind this to our vagrant user.
$ kubectl create rolebinding vagrant-nginx-pod-all --role=nginx-pod-all --user=vagrant
rolebinding.rbac.authorization.k8s.io/vagrant-nginx-pod-all created
$ kubectl get rolebinding vagrant-nginx-pod-all -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  creationTimestamp: "2023-05-20T15:24:07Z"
  name: vagrant-nginx-pod-all
  namespace: default
  resourceVersion: "83832"
  uid: b38e83d5-b860-473a-876f-c40ae84a5218
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: nginx-pod-all
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: vagrant

# Now on Jumpbox.
# Lets set the context to vagrant.
$ kubectl config use-context vagrant
Switched to context "vagrant".

# List all the pods in the default namespace.
$ kubectl get pods
Error from server (Forbidden): pods is forbidden: User "vagrant" cannot list resource "pods" in API group "" in the namespace "default"

# We know that there is a pod name nginx, lets be more specific.
$ kubectl get pods nginx
NAME    READY   STATUS    RESTARTS       AGE
nginx   1/1     Running   14 (95m ago)   21d

# We actually gave more access to vagrant to the nginx pod. Lets try deleting it.
$ kubectl delete pod nginx
pod "nginx" deleted
$ kubectl get pods nginx
Error from server (NotFound): pods "nginx" not found
```  

One thing to note is that roles are additive and you can bind more than 1 role to a user. This means that the access a user/service accont has is the sum of all the rules set on the roles/clusterrole.  
```
# On the master server.
# Lets recreate the nginx pod.
$ kubectl run nginx --image=nginx
pod/nginx created

# Lets bind the pod-reader-cluster clusterrole to the vagrant user again.
$ kubectl create rolebinding vagrant-pod-reader-cluster --clusterrole=pod-reader-cluster --user=vagrant --namespace=default
rolebinding.rbac.authorization.k8s.io/vagrant-pod-reader-cluster created

# Now lets go back to the Jumpbox server.
# Lets now see if vagrant can view all pods inside the default namespace,
$ kubectl get pods
NAME              READY   STATUS             RESTARTS       AGE
nginx             1/1     Running            0              2m17s
nginx2            1/1     Running            7 (102m ago)   14d
nginx3-master     1/1     Running            6 (102m ago)   12d

# Now lets see if vagrant can still delete the pod named nginx.
$ kubectl delete pod nginx
pod "nginx" deleted
vagrant@jumpbox:~$ kubectl get pods
NAME              READY   STATUS             RESTARTS       AGE
nginx2            1/1     Running            7 (109m ago)   14d
nginx3-master     1/1     Running            6 (109m ago)   12d

# Now lets see if we can delete any other pods in the default namespace.
$ kubectl delete pod nginx2
Error from server (Forbidden): pods "nginx2" is forbidden: User "vagrant" cannot delete resource "pods" in API group "" in the namespace "default"
```  

### Cluster Role Aggregration  
Cluster Role has pretty much the same parameters as a Role object. However Kubernetes allows you to aggregrate cluster roles together and then reference this aggregation.  

Let us allow our vagrant user to list nodes and pods on all namespaces.  But instead of creating 2 role bindings, lets create an aggregrate role instead.
```
# On the master server.
# Lets remove all the rolebindings to the vagrant user.
$ kubectl delete rolebinding vagrant-pod-reader-cluster vagrant-nginx-pod-all
rolebinding.rbac.authorization.k8s.io "vagrant-pod-reader-cluster" deleted
rolebinding.rbac.authorization.k8s.io "vagrant-nginx-pod-all" deleted

# Lets add a label to our pod-reader-cluster clusterrole.
$ kubectl label --overwrite clusterrole pod-reader-cluster reader_role=true
clusterrole.rbac.authorization.k8s.io/pod-reader-cluster labeled
$ kubectl get clusterrole pod-reader-cluster -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: "2023-05-20T06:54:23Z"
  labels:
    reader_role: "true"
  name: pod-reader-cluster
  resourceVersion: "88553"
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

# Now lets create a clusterrole to view nodes.
$ kubectl create clusterrole node-reader-cluster --resource=nodes --verb=list --verb=get --verb=watch
clusterrole.rbac.authorization.k8s.io/node-reader-cluster created

# Lets label it as well.
$ kubectl label --overwrite clusterrole node-reader-cluster reader_role=true
clusterrole.rbac.authorization.k8s.io/node-reader-cluster labeled
$ kubectl get clusterrole node-reader-cluster -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: "2023-05-20T16:17:51Z"
  labels:
    reader_role: "true"
  name: node-reader-cluster
  resourceVersion: "88866"
  uid: 7e62d9ea-3a7c-49fd-ad0a-e4c1ae667958
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - list
  - get
  - watch

# Now lets create an aggregrate cluster role:
$ cat <<'EOF'>> aggregrate_reader_clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aggregrate-reader-cluster
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      reader_role: "true"
rules: []
EOF

# Now lets apply this manifest.
$ kubectl apply -f aggregrate_reader_clusterrole.yaml
clusterrole.rbac.authorization.k8s.io/aggregrate-reader-cluster created
$ kubectl get clusterrole aagregrate-reader-cluster -o=yaml
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      reader_role: "true"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"aggregationRule":{"clusterRoleSelectors":[{"matchLabels":{"reader_role":"true"}}]},"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRole","metadata":{"annotations":{},"name":"aggregrate-reader-cluster"},"rules":[]}
  creationTimestamp: "2023-05-20T16:23:33Z"
  name: aggregrate-reader-cluster
  resourceVersion: "89275"
  uid: 0c5d4e86-c560-478e-bb25-5e03e08dede5
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - list
  - get
  - watch
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
  - list
  - watch

# Now let us bind the aggregrate role to vagrant.
$ kubectl create clusterrolebinding vagrant-super-reader --clusterrole=aggregrate-reader-cluster --user=vagrant
clusterrolebinding.rbac.authorization.k8s.io/vagrant-super-reader created
$ kubectl get clusterrolebinding vagrant-super-reader -o=yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  creationTimestamp: "2023-05-20T16:26:19Z"
  name: vagrant-super-reader
  resourceVersion: "89527"
  uid: da3c0911-4a55-4b0f-b2ac-0dea1dbf5080
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: aggregrate-reader-cluster
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: vagrant

# Now on the Jumpbox server.
# Lets make sure that we are using the vagrant context.
$ kubectl config use-context vagrant
Switched to context "vagrant".

# Lets view all pods.
$ kubectl get pods -A
NAMESPACE      NAME                             READY   STATUS    RESTARTS        AGE
default        nginx2                           1/1     Running   7 (135m ago)    14d
default        nginx3-master                    1/1     Running   6 (135m ago)    12d
kube-flannel   kube-flannel-ds-6rc4b            1/1     Running   18 (135m ago)   28d
kube-flannel   kube-flannel-ds-df9tp            1/1     Running   21 (134m ago)   28d
kube-flannel   kube-flannel-ds-gdfb6            1/1     Running   19 (135m ago)   28d
kube-system    coredns-787d4945fb-h8dl9         1/1     Running   15 (135m ago)   26d
kube-system    coredns-787d4945fb-v92dc         1/1     Running   15 (135m ago)   26d
kube-system    etcd-master                      1/1     Running   8 (135m ago)    14d
kube-system    kube-apiserver-master            1/1     Running   22 (135m ago)   24d
kube-system    kube-controller-manager-master   1/1     Running   19 (135m ago)   24d
kube-system    kube-proxy-42n4m                 1/1     Running   14 (135m ago)   21d
kube-system    kube-proxy-7d8dk                 1/1     Running   14 (134m ago)   21d
kube-system    kube-proxy-qh64n                 1/1     Running   15 (135m ago)   24d
kube-system    kube-scheduler-master            1/1     Running   19 (135m ago)   24d

# Lets view our nodes.
$ kubectl get nodes
NAME     STATUS   ROLES           AGE   VERSION
master   Ready    control-plane   28d   v1.26.4
node1    Ready    <none>          28d   v1.26.4
node2    Ready    <none>          28d   v1.26.4

# Lets see if we can delete a pod or a node
$ kubectl delete pod nginx2
Error from server (Forbidden): pods "nginx2" is forbidden: User "vagrant" cannot delete resource "pods" in API group "" in the namespace "default"
$ kubectl delete node node2
Error from server (Forbidden): nodes "node2" is forbidden: User "vagrant" cannot delete resource "nodes" in API group "" at the cluster scope
```  

## Service Accounts  
Service accounts allow pods to gain access to API. They are managed by Kubernetes unlike users. This means that we can create a Service Account through kubectl or the API directly. This can be useful in situations where you application running inside a pod requires access to the Kubernetes API. These may include monitoring or CI/CD applications (Prometheus and ArgoCD come to mind.).  

Every pod is assigned a service account. If you do not specify a service account for a pod, it uses the "default" service account on the namespace that it is one. Service accounts are namespaced resources. Lets look at the service accounts in the default and kube-system namespaces.  
```
# Service Account in the default namespace.
$ kubectl get serviceaccount -n default
NAME      SECRETS   AGE
default   0         35h
$ kubectl get serviceaccount default -o=yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2023-05-20T18:11:47Z"
  name: default
  namespace: default
  resourceVersion: "348"
  uid: 2831e57c-d06d-44b1-81fc-d357b1b006ee

# Get Service Accounts in kube-system
$ kubectl get serviceaccount -n kube-system
NAME                                 SECRETS   AGE
attachdetach-controller              0         35h
bootstrap-signer                     0         35h
certificate-controller               0         35h
clusterrole-aggregation-controller   0         35h
coredns                              0         35h
cronjob-controller                   0         35h
daemon-set-controller                0         35h
default                              0         35h  <--- default is also here
deployment-controller                0         35h
<--- Output truncated --->
```  

As can be seen, the default service account is on all namespaces. If you create a new namespace, a new default service account will be created.  
```
# Create a new namespace and check what service accounts are created.
$ kubectl create namespace sa-demo
namespace/sa-demo created
$ kubectl get serviceaccounts -n sa-demo
NAME      SECRETS   AGE
default   0         9s
```  

By default, no roles or cluster roles are binded to the default account. This means that pods using this service account do not have any access to the Kubernetes API. Let try accessing the API inside a pod to test this out. We can follow the instructions [here](https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/). We will need a few things before we start.  

We will need to know or have:
* The CA cert file.
* A valid bearer token.
* A valid API command.  

The CA cert file and bearer token should already be in a pod. We can confirm this by inspecting a pod.  
```
# Check if the CA cert and bearer token is available in a pod. We will inspect the nginx2 pod.
$ kubectl get pod nginx2 -o=yaml | | grep volumes -A 18
  volumes:
  - name: kube-api-access-krhmw
    projected:
      defaultMode: 420
      sources:
      - serviceAccountToken:
          expirationSeconds: 3607
          path: token
      - configMap:
          items:
          - key: ca.crt
            path: ca.crt
          name: kube-root-ca.crt
      - downwardAPI:
          items:
          - fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
            path: namespace

$ kubectl get pod nginx2 =o=yaml | grep volumeMounts -A 3
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-krhmw
      readOnly: true
```  

As can be seen in the pod definition, the CA certificate and bearer tokens are mounted under /var/run/secrets/kubernetes.io/serviceaccount.  

Now lets get a valid REST API command. Lets see how to do a get pods command through the API.  
```
$ kubectl get pods -v 9
I0522 06:21:42.025813   13861 loader.go:373] Config loaded from file:  /home/vagrant/.kube/config                                                                                              
I0522 06:21:42.037351   13861 round_trippers.go:466] curl -v -XGET  -H "User-Agent: kubectl/v1.26.0 (linux/amd64) kubernetes/b46a3f8" -H "Accept: application/json;as=Table;v=v1;g=meta.k8s.io,application/json;as=Table;v=v1beta1;g=meta.k8s.io,application/json" 'https://192.168.73.5:6443/api/v1/namespaces/default/pods?limit=500'
I0522 06:21:42.037959   13861 round_trippers.go:510] HTTP Trace: Dial to tcp:192.168.73.5:6443 succeed
I0522 06:21:42.051810   13861 round_trippers.go:553] GET https://192.168.73.5:6443/api/v1/namespaces/default/pods?limit=500 200 OK in 14 milliseconds
<--- Output truncated --->
```  

We can see that kubectl issued the following curl command to get the pods in the default namespace: https://192.168.73.5:6443/api/v1/namespaces/default/pods?limit=500.  Now we have all the information we need to access the API inside the pod.  
```
# Connect to the nginx2 pod.
$ kubectl exec nginx2 -i --tty -- /bin/sh
# APISERVER=https://kubernetes.default.svc
# SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
# TOKEN=$(cat ${SERVICEACCOUNT}/token)
# CACERT=${SERVICEACCOUNT}/ca.crt
# curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/default/pods
{
  "kind": "Status",
  "apiVersion": "v1",
  "metadata": {},
  "status": "Failure",
  "message": "pods is forbidden: User \"system:serviceaccount:default:default\" cannot list resource \"pods\" in API group \"\" in the namespace \"default\"",
  "reason": "Forbidden",
  "details": {
    "kind": "pods"
  },
  "code": 403
# exit
```  

As can be seen in the output, the default service account does not have permission to list pods in the default namespace.  

Now we can go ahead and bind the pod-reader-cluster cluster role or pod-reader-role to the default service account and call it a day, but that is not the best practice. Not all pods in a namespace should have access to the API. Binding a role to the default service account will give any pod that is not set up with a different service account access to the Kubernetes API. So lets create a service account and bind a a role or cluster role to it.  
```
# Create a Service Account.
$ kubectl create serviceaccount default-pod-reader -n default
serviceaccount/default-pod-reader created

# Let create a rolebinding of the pod-reader-cluster to the default-pod-reader service account.
$ kubectl create rolebinding nginx-pod-reader --serviceaccount=default:default-pod-reader --clusterrole=pod-reader-cluster --namespace=default
rolebinding.rbac.authorization.k8s.io/nginx-pod-reader created

# Now lets create a pod that uses this service account.
$ cat <<'EOF'>> sa-demo-nginx.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: sa-demo-nginx
  name: sa-demo-nginx
spec:
  serviceAccountName: default-pod-reader
  containers:
  - image: nginx
    name: sa-demo-nginx
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
EOF

$ kubectl apply -f sa-demo-nginx.yaml
pod/sa-demo-nginx created

# Lets confirm that our pod is using the service account we created.
$ kubectl get pod sa-demo-nginx -o=yamo | grep serviceAccountName
      {"apiVersion":"v1","kind":"Pod","metadata":{"annotations":{},"labels":{"run":"sa-demo-nginx"},"name":"sa-demo-nginx","namespace":"default"},"spec":{"containers":[{"image":"nginx","name":"sa-demo-nginx","resources":{}}],"dnsPolicy":"ClusterFirst","restartPolicy":"Always","serviceAccountName":"default-pod-reader"}}
  serviceAccountName: default-pod-reader

# Now lest attach to the pod and issue the same commands we did earlier.
$ kubectl exec sa-demo-nginx -i --tty -- /bin/sh
# APISERVER=https://kubernetes.default.svc
# SERVICEACCOUNT=/var/run/secrets/kubernetes.io/serviceaccount
# TOKEN=$(cat ${SERVICEACCOUNT}/token)
# CACERT=${SERVICEACCOUNT}/ca.crt
# curl --cacert ${CACERT} --header "Authorization: Bearer ${TOKEN}" -X GET ${APISERVER}/api/v1/namespaces/default/pods
{
  "kind":"PodList",
  "apiVersion": "v1",                                  
  "metadata": {
    "resourceVersion": "10783"                           
  },                         
  "items":[
    {                                                    
      "metadata": {
        "name": "nginx",
        "namespace": "default",
        "uid": "ce7bff04-89e3-435b-b076-b3ab33fd0c9a",
        "resourceVersion": "3043",
        "creationTimestamp": "2023-05-20T18:19:16Z",
        "labels": {
          "run": "nginx"
        },
  <--- Output truncated --->
```