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

