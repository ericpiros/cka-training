# Role Based Access Control
RBAC allows you to set controls on what actions can be performed by a user or service account. There are several objects to know when talking about RBAC.  
* Role - allows you specify what actions can be performed on a namespace level.
* Cluster Role - allows you to specify what actions can be performed on the cluster level.  
* RoleBinding - binds a role to a user or service account. As with a role, this is a namespaced object.
* ClusterRoleBinding - binds a cluster role to a user or a service account.  

On a superficial level, the main difference between a role/rolebinding and clusterrole/clusterrolebinding is the scope of the control. Either limited to a namespace (or several namespaces) or the entire cluster.

Some actions, like inspecting nodes, are only available on the cluster level.  
```
# Role config
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: <role name>
  namespace: <namespace>
rules:
- apiGroups:
  - <api groups>
  resources:
  - <resources>
  verbs:
  - <verbs>
---
# ClusterEole config
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: <cluster role name>
rules:
- apiGroups:
  - <api groups>
  resources:
  - <resources>
  verbs:
  - <verbs>
```
As can be seen on the config above, the only difference between them, aside from kind, is that a role requires that a namespace be specified. A cluster role does not need it.  Lets view what other parameters a role can take by running:
```
# Check what parameters we can pass to a role.
$ kubectl create role --help
```  
# Role/ClusterRole Parameters  
* **resource** - a list of resources that the rule applies to. You can get a list of resources available in your cluster by running: 'kubectl api-resources'.
* **verb** - a list of verbs that apply to the resources contained in the rule.  
  * get
  * watch
  * create
  * update
  * patch
  * delete
  * deletecollection
* apiGoups - the API group where the resource belongs to. You can get what API a resource is in by running: 'kubectl api-resources -o wide'
* resource-name - the name of the resource you wish to apply the rule to. This is useful if you only want to limit the rule a specific set of resources. Wildcards can be used.