# cka-training
My preparation for the Certified Kubernetes Training Administrator notes.  

I will using this space to place in files and notes that I will be using to train for the Certified Kubernetes Administrator certificate. I am starting this on February 14, 2023 and am targeting on going for the exam by the 2nd quarter of this year.  

# What am I using to learn?
I am currently going through the [Container](https://learn.acloud.guru/learning-path/cloud-adjacent-containers) learning path on [aCloud.guru](https://acloud.guru). In particular I am tracing the lessons on the [Certified Kubernetes Administrator(CKA)](https://learn.acloud.guru/course/certified-kubernetes-administrator/overview) and [Kubernetes the hard way](https://learn.acloud.guru/course/8832e727-9101-4785-8ea6-e8057ad62f69/overview), both by [William Boyd](https://www.linkedin.com/in/wilb/).  

# What is covered in the exam?
As of 2023, the exam covers the [Kubernetes 1.26](https://kubernetes.io/blog/2022/12/09/kubernetes-v1-26-release/) and as such I will be following the [1.26 curriculum](files/CKA_Curriculum_v1.26.pdf).  These incude the following:  
* 25% - Cluster Architecture, Installation and Configuration  
  * [Manage role based access control (RBAC)](./cluster_install_config/role_based_access_control/rbac.md)
  * [Use kubeadm to install a basic cluster](./cluster_install_config/installation/install_k8s_kubeadm.md)
  * [Manage a highly-available Kubernetest cluster](./cluster_install_config/manage_ha_cluster/ha_cluster.md)
  * Provision underlying infrastructure to deploy a Kuernetes cluster
  * [Perform a version upgrade on a Kubernetes cluster using Kubeadm](./cluster_install_config/upgrade/upgrade_k8s_kubeadm.md)
  * [Implement etcd backup and restore](./cluster_install_config/etcd_backup_restore/backup_etcd.md)
* 15% - Workloads & Scheduling
  * [Understand deployments and how to perform rolling update and rollbacks](./workload_scheduling/deployments/deployments.md)
  * Use ConfigMaps and Secrets to configure applications
  * Know how to scale applications
  * Understand the primitives used to create robust, self-healing, application deployments
  * Understand how resource limits can affect Pod scheduling
  * Awareness of manifest management and common templating tools
* 20% - Services & Networking
   * Understand host networking configuration on the cluster nodes
   * Understand connectivity between Pods
   * Understand ClusterIP, NodePort, LoadBalancer service types and endpoints
   * Know how to use Ingress controllers and Ingress resources
   * Know how to configure and use CodeDNS
   * Choose and appropriate container network interface plugin
* 10% - Storage
  * Understand storage classes, persistent volumes
  * Understand volume mode, access modes and reclaim policies for voluems
  * Understand persistent volume claims primitive
  * know how to configure applications with persistent storage
* 30% - Troubleshooting
  * Evaluate cluster and node logging
  * Understand how to monitor applications
  * Manage container stdout & stderr logs
  * Troubleshoot application failure
  * Troubleshoot cluster component failure
  * Troubleshoot networking