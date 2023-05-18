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
$ kubectl --kubeconfig vagrant-kubeconfig config set-credentials vagrant-admin --client-certificate=vagrant-admin.crt --client-key=vagrant_admin.pem --embed-certs=true
User "vagrant-admin" set.

# Create our vagrant and vagrant-admin context, which combines a user and cluster information.
$ kubectl --kubeconfig vagrant-kubeconfig config set-context vagrant --cluster=kubernetes --user=vagrant
Context "vagrant" created.
$ kubectl --kubeconfig vagrant-kubeconfig config set-context vagrant-admin --cluster=kubernetes --user=vagrant-admin
Context "vagrant-admin" created.

# Lets set the vagrant context as the default.
$ kubectl --kubeconfig vagrant-kubeconfig config use-context vagrant
Switched to context "vagrant".

# Check that our contexts have been set on the kubeconfig file that we created.
$ kubectl --kubeconfig ./vagrant-kubeconfig config get-contexts
CURRENT   NAME            CLUSTER      AUTHINFO        NAMESPACE
*         vagrant         kubernetes   vagrant         
          vagrant-admin   kubernetes   vagrant-admin   
$ kubectl --kubeconfig ./vagrant-kubeconfig config get-users
NAME
vagrant
vagrant-admin
```