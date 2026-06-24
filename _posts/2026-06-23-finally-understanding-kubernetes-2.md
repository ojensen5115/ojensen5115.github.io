---
layout: post
title:  "Finally understanding Kubernetes (part 2 of 4)"
date:   2026-06-23 12:32:00
categories: Kubernetes infrastructure security
permalink: /infra/understanding-k8s-2
---

You've probably seen / had to use Kubernetes to some extent, but maybe you don't really *get* it yet? And you'd like to? Then this post is for you. In [Part 1](/infra/understanding-k8s-1), we dug into the basic nuts and bolts of Kubernetes, learning about Pods, Deployments, and Services. Next, we'll dig into configuration and persistence.

# Map of the territory

* [Part 1](/infra/understanding-k8s-1)
  * [Cluster setup](/infra/understanding-k8s-1#cluster-setup)
  * [First Pod](/infra/understanding-k8s-1#first-pod)
  * [Deployments & scaling](/infra/understanding-k8s-1#deployments--scaling)
  * [Services](/infra/understanding-k8s-1#services)
  * [Rolling updates & rollbacks](/infra/understanding-k8s-1#rolling-updates--rollbacks)
* **Part 2 (you are here)**
  * [ConfigMaps & Secrets](/infra/understanding-k8s-2#configmaps--secrets)
  * [Multi-container pod](/infra/understanding-k8s-2#multi-container-pod)
  * [Persistent storage](/infra/understanding-k8s-2#persistent-storage)
  * [StatefulSets](/infra/understanding-k8s-2#statefulset)
* Part 3 (coming soon)
  * Ingress
  * Health
  * Namespaces & resource limits
  * RBAC
* Part 4 (coming soon)
  * Helm
  * Capstone






# ConfigMaps & Secrets

You generally don't want to bake environment-specific values (e.g. a database URL, an API credential, etc) into your container image, or hardcode them into the Pod specification. Instead, you injecting them at deploy time -- this lets you have the same image running in dev / staging / production, with different configurations.

## Setup

First, we'll create a ConfigMap and look at its contents:

    kubectl create configmap app-config --from-literal=GREETING="Hello from ConfigMap" --from-literal=APP_MODE="development"
    kubectl get configmap app-config -o yaml

And then we'll create a Secret:

    kubectl create secret generic app-secret --from-literal=DB_PASSWORD="zaphodbeeblebrox"
    kubectl get secret app-secret -o yaml

Notice that while the Secret is not shown in plaintext, it is only base64 encoded.

**The Secret is not encrypted.**

It's also worth noting that we did this imperatively insted of declaratively. And your database password is now in your shell's history, which also isn't great. We'll discuss those points in a bit.

## Consuming as env vars

Create a file called `manifests/config-pod.yaml` with the following contents:

    apiVersion: v1
    kind: Pod
    metadata:
      name: config-test
    spec:
      containers:
        - name: app
          image: busybox
          command: ["sh", "-c", "env | grep -E 'GREETING|APP_MODE|DB_PASSWORD'; sleep 3600"]
          env:
            - name: GREETING
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: GREETING
            - name: APP_MODE
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: APP_MODE
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secret
                  key: DB_PASSWORD

Reading through that manifest, you can see that we're injecting those three values into the Pod's environment, and then the pod is configured to echo them back out. So, let's apply it and check its logs to see the output:

    kubectl apply -f manifests/config-pod.yaml
    kubectl logs config-test

You should see the two configuration values and the secret printed.

Also, while we are managing config values and the secret separately, to the Pod, values from a ConfigMap are indistinguishable from values from a Secret: after pod instantiation, they're all just strings in environment variables.

## Consuming as mounted files

Configurations and secrets can also be made available to the Pod by way of mounted files. This may be preferable if you're in a situation where environment variables end up a little too visible for comfort (i.e. end up in logs when a crash happens, or similar).

Create a file called `manifests/config-pod-volume.yaml` with the following contents:

    apiVersion: v1
    kind: Pod
    metadata:
      name: config-test-vol
    spec:
      containers:
        - name: app
          image: busybox
          command: ["sh", "-c", "cat /etc/config/GREETING; echo; cat /etc/secret/DB_PASSWORD; echo; sleep 3600"]
          volumeMounts:
            - name: config-vol
              mountPath: /etc/config
            - name: secret-vol
              mountPath: /etc/secret
      volumes:
        - name: config-vol
          configMap:
            name: app-config
        - name: secret-vol
          secret:
            secretName: app-secret

In this manifest we mount our ConfigMap and our Secret as directories, and we've set up our Pod to just `cat` their contents to stdout. So once again, let's apply it and check its logs to see the output:

    kubectl apply -f manifests/config-pod-volume.yaml
    kubectl logs config-test-vol

Each key becomes a separate file in the mount path (e.g. `/etc/config/GREETING`, `/etc/config/APP_MODE`) with the value as the file contents. In addition to keeping secrets out of environment variables, this is also particularly useful for full configuration files rather than individual values (e.g. mounting an entire `nginx.conf` as a single ConfigMap key).

## Changes do not propagate

Change the `GREETING` value in the ConfigMap:

    kubectl patch configmap app-config -p '{"data":{"GREETING":"UPDATED GREETING"}}'

Now check both pods:

    kubectl exec config-test -- env | grep GREETING
    kubectl exec config-test-vol -- cat /etc/config/GREETING

Notice that the environment variables **do not auto-update** -- they were injected when the Container was started and are frozen for the lifetime of the Pod. If you want to update the value, you will need to delete and re-deploy the Pod.

But the mounted file **eventually does update**. You likely saw the original greeting in both cases when you ran the commands above. But if you run the second one again now (or in a few moments) you'll get the updated greeting. Kubernetes periodically syncs mounted ConfigMap/Secret volumes every minute or so, without restarting the Pod.

## Declarative definitions

You can (and probably should) define your ConfigMap declaratively via a manifest:

    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: app-config
    data:
      GREETING: "Hello from ConfigMap"
      APP_MODE: "development"

You can also define your Secrets declaratively via a manifest:

    apiVersion: v1
    kind: Secret
    metadata:
      name: app-secret
    type: Opaque
    data:
      DB_PASSWORD: c3VwM3JzM2NyM3Q=

but you probably shouldn't: you don't want your plaintext (okay, base64 encoded) secrets committed to your source code repository. 

Good practice for secrets here depends on where you want them stored. Either encrypt the values before they are committed (e.g. [SOPS](https://github.com/getsops/sops) by Mozilla) if you want them stored securely in your repository, or you can use an external secrets manager like Vault / AWS Secrets Manager.



## Clean up

Delete your configs, secrets, and pods:

    kubectl delete -f manifests/config-pod.yaml
    kubectl delete -f manifests/config-pod-volume.yaml
    kubectl delete configmap app-config
    kubectl delete secret app-secret






# Multi-container Pod

So far we've been putting each container in its own Pod. But a Pod can actually hold more than one container. Containers in the same pod share a network namespace, which means that they can reach each other via `localhost`, and can also share volumes.

This construction is often referred to as a "sidecar": you have a main application, and then a "helper" process that is tightly coupled to the main application's lifecycle. A common example is a sidecar which ships the main application's logs to wherever they need to go, or that synchronizes files that the main application reads or writes.

## Log-shipping sidecar

Create a file called `manifests/sidecar-pod.yaml` with the following contents:

    apiVersion: v1
    kind: Pod
    metadata:
      name: sidecar-demo
    spec:
      containers:
        - name: writer
          image: nginx:1.25
          ports:
            - containerPort: 80
          volumeMounts:
            - name: shared-logs
              mountPath: /var/log/nginx
        - name: sidecar
          image: busybox
          command:
            [
              "sh",
              "-c",
              "tail -f /var/log/nginx/access.log 2>/dev/null || sleep 3600",
            ]
          volumeMounts:
            - name: shared-logs
              mountPath: /var/log/nginx
      volumes:
        - name: shared-logs
          emptyDir: {}


The first container ("writer") is our nginx container we know and love. The second container ("sidecar") reads the log output and prints it to standard out -- though in real life, you could imagine it shipping the logs to your logging platform.

They share an ephemeral storage volume called "shared-logs". The `emptyDir` is the simplest volume type: it exists for the Pod's lifetime, is shared by every container in the Pod, and is deleted when the Pod is deleted.

## Apply and look around

Apply the manifest and look at the resulting Pod:

    kubectl apply -f manifests/sidecar-pod.yaml
    kubectl get pod sidecar-demo

Notice that for the first time, the "READY" status shows `2/2`, indicating there are two containers running in this Pod. 

Now let's have a look at log output:

    kubectl logs sidecar-demo

Note that by default, it shows you the logs of your first container. If you want to view the logs of a specific container in a multi-container pod, you'll need to pass it in as a `-c` argument:

    kubectl logs sidecar-demo -c writer
    kubectl logs sidecar-demo -c sidecar

See how the writer has emitted the typical nginx startup loglines, but the reader has not emitted anything yet. This is because nginx has not yet fielded a request

## See the shared resources

Let's hop into the sidecar container:

    kubectl exec -it sidecar-demo -c writer -- /bin/sh
    # ~~ inside the container ~~
    curl localhost:80
    exit

As you would expect, you can see nginx's welcome page. Now try from the sidecar:

    kubectl exec -it sidecar-demo -c sidecar -- /bin/sh
    # ~~ inside the container ~~
    wget -O- localhost:80
    ls /var/logs/nginx
    exit

Since the two containers share a network namespace, our network request also loads the nginx welcome page (though since the sidecar is just a busybox image, we had to use `wget` instead of `curl`). We can also see the nginx request log in the volume that the two containers share.

Now let's check logs again:

    kubectl logs sidecar-demo -c writer
    kubectl logs sidecar-demo -c sidecar

Now the sidecar's logs contain the nginx requests. Note that they both came from `localhost`.

While the two processes share a disk volume and the network namespace, they do *not* share a process space. Run `ps -A` from the sidecar to see this:

    kubectl exec -it sidecar-demo -c sidecar -- ps -A

Note that the `nginx` process is not present.

If you need your containers to share their process namespaces (e.g. in case one needs to send signals to the others' processes), you can do so by setting `spec.shareProcessNamespace: true` in the Pod manifest.

## Kill one container

Exec into the nginx container and kill it:

    kubectl exec -it sidecar-demo -c writer -- /bin/sh
    # ~~ inside the container ~~
    kill 1
    # ~~ note: the container gets killed ~~
    kubectl get pod sidecar-demo

Killing PID 1 terminates the container, but notice that the Pod does not die. Instead, it shows `1/2` under the `READY` column, and immediately restarts the writer container. Run `kubectl describe pod sidecar-demo` and you'll see a restart event for only the `writer` container: by default, individual container restarts within a multi-container pod are independent.

## Clean up

Run the following command to delete the pod:

    kubectl delete -f manifests/sidecar-pod.yaml








# Persistent storage

In our last manifest, we used an `emptyDir` storage volume. This is fine for scratch space, but it dies with the Pod -- not very useful for data that needs to survive a Pod restart, such as in a database. 

## The two-object model

For persistent storage, Kubernetes tracks two different kinds of objects in order to decouple "what storage do I need" from "where does that storage physically live".

A `PersistentVolume` (PV) represents an actual piece of storage (e.g. a disk, an NFS share, a cloud volume, etc), which can be provisioned manually by an admin, or dynamically by a [StorageClass](https://kubernetes.io/docs/concepts/storage/storage-classes/) (which is more typical in a cloud environment).

A `PersistentVolumeClaim` (PVC) represents a request for storage allocation (e.g. "I need 1gb of ReadWriteOnce") that a Pod can reference.
Kubernetes is responsible for binding a PVC to a suitable PV.
Manifests will only ever reference PVCs, and are agnostic to what PV may be in use.

`kind` ships with a default StorageClass that dynamically creates a PV the moment a PVC requests one. You can see it here:

    kubectl get storageclass

## Create a PVC

Create a file called `manifests/pvc.yaml` with the following contents:

    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: data-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi

And then apply it and look at what you've got:

    kubectl apply -f manifests/pvc.yaml
    kubectl get pvc
    kubectl get pv

You'll notice that the PVC sits at "pending" and the PV doesn't get created at all. Let's diagnose what's happening:

    kubectl describe pvc data-pvc

Look at the Events section, and you'll see "waiting for first consumer to be created before binding". It seems like our default StorageClass does not actually allocate the PV until something uses it.

## Use the PVC

Create a file called `manifests/storage-pod.yaml` with the following contents:

    apiVersion: v1
    kind: Pod
    metadata:
      name: storage-test
    spec:
      containers:
        - name: app
          image: busybox
          command: ["sh", "-c", "sleep 3600"]
          volumeMounts:
            - name: persistent-storage
              mountPath: /data
      volumes:
        - name: persistent-storage
          persistentVolumeClaim:
            claimName: data-pvc

Then apply it, and let's look at our PVC and PV again:

    kubectl apply -f manifests/storage-pod.yaml
    kubectl get pvc
    kubectl get pv

Now you can see the PVC's status is "Bound", and the PV backing it was automatically allocated.

## Data surviving Pod death

Let's use our Pod to write a file in our PVC:

    kubectl exec storage-test -- /bin/sh
    # ~~ inside the Pod ~~
    echo "Hello there" > /data/test.txt
    exit

Now delete the pod, create a new instance of it, and read the file:

    kubectl delete pod storage-test
    kubectl apply -f manifests/storage-pod.yaml
    kubectl exec storage-test -- cat /data/test.txt

The file should still be there, even though our Pod is brand new, because the PVC / PV are independent of the Pod. 

## So this is how you do Databases

Yep.

So let's done one.

Create a file called `manifests/postgres.yaml` with the following contents:

    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: postgres-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: postgres
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: postgres
      template:
        metadata:
          labels:
            app: postgres
        spec:
          containers:
            - name: postgres
              image: postgres:16
              env:
                - name: POSTGRES_PASSWORD
                  value: "testpass"
              ports:
                - containerPort: 5432
              volumeMounts:
                - name: pgdata
                  mountPath: /var/lib/postgresql/data
                  subPath: pgdata
          volumes:
            - name: pgdata
              persistentVolumeClaim:
                claimName: postgres-pvc

This manifest is a little different than the ones we've written so far. Fun fact: you can bundle multiple things into the same manifest file, just put three dashes on a line betewen them.

The `subPath` directive when mounting the PVC means we're going to use a subdirectory on the volume instead of the volume root. This is because postgres expects a completely empty directory, and without the subpath it'd complain about `lost+found`.

By the way, it's worth noting that you can tab-complete your resource names in kubectl commands. This will save you doing a quick `kubectl get pod` when you apply the module and put something in the database:

    kubectl apply -f manifests/postgres.yaml
    kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s
    kubectl exec -it postgres-[TAB_COMPLETE_HERE] -- psql -U postgres

    # ~~ postgres inside the container ~~
    CREATE TABLE test (id serial primary key, note text);
    INSERT INTO test (note) VALUES ('survived a restart');
    exit

## Data survives the Pod

Delete the Pod and wait for a new one to be created. For fun, here's another way to delete resources: by label.

    kubectl delete pod -l app=postgres
    kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s

Now query the database:

    kubectl exec -it postgres-[TAB_COMPLETE_HERE] -- psql -U postgres

    # ~~ postgres inside the container ~~
    SELECT * FROM test;
    exit    

You should see the data you stored in the old pod.

## Clean up

Delete the resources we made:

    kubectl delete -f manifests/postgres.yaml
    kubectl delete -f manifests/storage-pod.yaml
    kubectl delete -f manifests/pvc.yaml

Since they eat up disk space, it's worth confirmig your PV / PVCs are gone:

    kubectl get pvc
    kubectl get pv
    





# StatefulSets

Deployments are great for stateless web servers. A Deployment's pods are essentially fungible, the whole "cattle not pets" model:
any replica can be replaced by any other, names are random hashes, none of them have a persistent individual identity.

That's fine for stateless web servers, but doesn't work for things like a database cluster, where you might need to have a primary replica and one or two other replicas that sync from the primary. In cases like that, you need each replica to have a stable identity that survives restarts.

StatefulSets provide stable identity, ordered startup/shutdown, and stable per-replica storage.

## Create a headless service

StatefulSets need a headless service (i.e. no ClusterIP) in order to provide stable per-Pod DNS names, rather than just load-balancing across an undifferentiated pool of replicas.

Create a file called `manifests/statefulset.yaml` with the following contents:

    apiVersion: v1
    kind: Service
    metadata:
      name: web-headless
    spec:
      clusterIP: None
      selector:
        app: web
      ports:
        - port: 80
          targetPort: 80
    ---
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: web
    spec:
      serviceName: web-headless
      replicas: 3
      selector:
        matchLabels: { app: web }
      template:
        metadata: { labels: { app: web } }
        spec:
          containers:
            - name: nginx
              image: nginx:1.25
              ports: [{ containerPort: 80 }]
              volumeMounts:
                - name: www
                  mountPath: /usr/share/nginx/html
      volumeClaimTemplates:
        - metadata: { name: www }
          spec:
            accessModes: ["ReadWriteOnce"]
            resources: { requests: { storage: 100Mi } }

Notice how in our StatefulSet we have a `volumeClaimTemplate`. Instead of creating a PVC shared by each Pod in a Deployment, each Pod here is going to get its own PVC according to the template we supply here.

Now apply the manifest and watch the pods come up:

    kubectl apply -f manifests/statefulset.yaml
    kubectl get pods
    kubectl get pods
    ...

You'll see the three pods come up sequentially and in order. Morever instead of having names with randomized hashes in them, they have predictable names of `web-0`, `web-1`, and `web-2`.

## Pod deletion

Delete a pod and watch it come back:

    kubectl delete pod web-1
    kubectl get pods

When the replacement pod is launched, it has the same name as the one you deleted: the StatefulSet guarantees that identity is stable and reused, even with full Pod deletion.

## Examine the storage

Look at the PVCs you created:

    kubectl get pvc

You'll see three separate PVCs, each named for the Pod it is bound to. Now let's write something to them:

    kubectl exec web-0 -- /bin/sh -c "echo 'aa' > /usr/share/nginx/html/index.html"
    kubectl exec web-1 -- /bin/sh -c "echo 'bb' > /usr/share/nginx/html/index.html"
    kubectl exec web-2 -- /bin/sh -c "echo 'cc' > /usr/share/nginx/html/index.html"

and read them back

    kubectl exec web-0 -- cat /usr/share/nginx/html/index.html
    kubectl exec web-1 -- cat /usr/share/nginx/html/index.html
    kubectl exec web-2 -- cat /usr/share/nginx/html/index.html

## Data is stable

Kill a pod, wait for it to come back, and read its data again:

    kubectl delete pod web-0
    # wait a sec for it to come back...
    kubectl exec web-0 -- cat /usr/share/nginx/html/index.html

## DNS is also stable

While a Pod's name is stable, it's not the same Pod. Let's redo our pod deletion experiment, but this time keeping an eye on the IP address of the Pod:

    kubectl get pods -o wide
    kubectl kill web-0
    kubectl get pods -o wide

As you can see, the IP address of the replacement pod is *not* the same.
However, we still get stable addressability by virtue of each Pod getting its own stable DNS name:

    kubectl run debug --image=busybox --rm -it -- /bin/sh
    # ~~ inside the temporary container ~~
    nslookup web-0.web-headless.default.svc.cluster.local
    nslookup web-1.web-headless.default.svc.cluster.local
    nslookup web-2.web-headless.default.svc.cluster.local

## Scaling respects order

Scale down the number of replicas, and watch them go:

    kubectl scale statefulset web --replicas=1
    kubectl get pods

You'll see that you're left with just `web-0`. If you were quick, you'd also have seen that the pods are sequentially removed, one at a time, in reverse order of creation. The idea is that when you scaling down, you want to remove the newest or "most expendable" replicas.

So going back to our database example, it's a good idea to put your primary or leader in the first Pod. 

## Clean up

Unlike a Deployment+PVC, deleting a StatefulSet does *not* delete the associated PVCs. So you'll need to delete both:

    kubectl delete -f manifests/statefulset.yaml
    kubectl delete pvc -l app=web
    kubectl get pvc

# Next steps

Stay tuned for part 3!
