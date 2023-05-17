# Role Based Access Control
RBAC allows you to set controls on what actions can be performed by a user or service account. There are several objects to know when talking about RBAC.  
* Role - allows you specify what actions can be performed on a namespace level.
* Cluster Role - allows you to specify what actions can be performed on the cluster level.  

Some actions, like inspecting nodes, are only available on the cluster level.  
```
# Role config
---
# ClusterEole config
```
As can be seen above, the configs are similar. Similarly, you can use the commands below to create them.


