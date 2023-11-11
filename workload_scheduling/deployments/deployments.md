# Deployments
Deployments allows you set declarative updates for Pods and ReplicaSets. This allows you make changes to your pods or replicasets to reduce disruption. Deployments allow to specifcy how to perform these updates, which by default is set to "RollingUpdate".  

# Creating a Deployment
We can easily create a deployment through the command "kubectl create deployment". Lets run through a basic setting.
```
# Create an nginx deployment.
$ kubectl create deployment nginx-deployment --image=nginx
deployment.apps/nginx-deployment created

# We can check the status of the deployment.
$ kubectl get deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   1/1     1            1           100s

# We can also see that creating a deployment also creates a replicaset.
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-55888b446c   1         1         1       2m18s
```

As can be seen, when creating a deployment and not setting any values for replicas will automatically set it to 1. There are are more options available to deployments, but before that, lets scale it up to 4 then perform an update.
```
# Scale up the deployment to 4.
$ kubectl scale deployment nginx-deployment --replicas=4
deployment.apps/nginx-deployment scaled

# Confirm that our deployment has been scaled up:
$ kubectl get deployment
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   4/4     4            4           13m

# We can also confirm that our replicaset has been increased.
$ kubectl get replicaset
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-55888b446c   4         4         4       14m

# Now let us change the version of Nginx installed on our deployment.
$ kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1
deployment.apps/nginx-deployment image updated

# Check the status of the update.
$ kubectl rollout status deployment/nginx-deployment
deployment "nginx-deployment" successfully rolled out

# Lets check that our container has a different version of nginx.
# First lets get a pod.
$ kubectl get pods
NAME                                READY   STATUS    RESTARTS      AGE
nginx                               1/1     Running   3 (51m ago)   33h
nginx-deployment-5d55fddd76-5vrbv   1/1     Running   0             4m14s
nginx-deployment-5d55fddd76-hjdrx   1/1     Running   0             4m10s
nginx-deployment-5d55fddd76-mp85d   1/1     Running   0             4m14s
nginx-deployment-5d55fddd76-sbbrm   1/1     Running   0             4m9s

# Now lets pass -v to nginx to get the version number.
$ kubectl exec nginx-deployment-5d55fddd76-hjdrx -- nginx -v
nginx version: nginx/1.16.1

# Lets look at our replicasets.
$ kubectl get replicaset
nginx-deployment-55888b446c   0         0         0       21m
nginx-deployment-5d55fddd76   4         4         4       114s
```  

As we can see, when we changed the image, it created a new replicaset and scaled down the old one. However when we scaled up the deployment, it did not create a new replicaset. To understand this a bit more lets look at the deployment manifest.
```
# View the deployment manifest.
$ kubectl get deployment nginx-deployment --output=yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
  creationTimestamp: "2023-06-12T14:06:58Z"
  generation: 3
  labels:
    app: nginx-deployment
  name: nginx-deployment
  namespace: default
  resourceVersion: "68610"
  uid: 32780341-3785-4b16-bae4-432fd9c9a620
spec:
  progressDeadlineSeconds: 600
  replicas: 4
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: nginx-deployment
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx-deployment
    spec:
      containers:
      - image: nginx:1.16.1
        imagePullPolicy: Always
        name: nginx
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
status:
<-- Output Truncated -->
```

As can be seen, 'replicas' are defined under 'spec'. While 'image' is defined under 'spec.template.spec.containers'. Generally, only changes under 'container' will trigger a new rollout. 

# Deployment Rollback
By default deployments keep 10 versions of a deployment. This allows you to rollback to any of the previous 10 versions. This list of version can be modified by including the '.spec.revisionHistoryLimit' field in your manifiest.  

To view details about a "rollout" we can use the "kubectl rollout" command.  
```
# View rollout status.
$ kubectl rollout status deployment/nginx-deployment
deployment "nginx-deployment" successfully rolled out

# View all revisions available of a deployment rollout.
$ kubectl rollout history deployment/nginx-deployment
deployment.apps/nginx-deployment
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

# View version detail
$ kubectl rollout history deployment/nginx-deployment --revision=1
deployment.apps/nginx-deployment with revision #1
Pod Template:
  Labels:       app=nginx-deployment
        pod-template-hash=5c4d87dfc7
  Containers:
   nginx:
    Image:      nginx:1.14.2
    Port:       <none>
    Host Port:  <none>
    Environment:        <none>
    Mounts:     <none>
  Volumes:      <none>
```  

We can also rollback to a previous version using the 'rollout undo' command.

```
# Rollback to a previous version.
$ kubectl rollout undo deployment/nginx-deployment
deployment.apps/nginx-deployment rolled back
```