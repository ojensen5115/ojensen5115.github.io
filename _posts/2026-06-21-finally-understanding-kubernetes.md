---
layout: post
title:  "Finally understanding Kubernetes (part 1 of 4)"
date:   2026-06-21 08:53:00
categories: Kubernetes infrastructure security
permalink: /infra/understanding-k8s-1
---


So you've made it to 2026 and you understand Docker containers to be "kinda like a VM, but not really", and Kubernetes is "kinda deploy docker containers, but not really"... and you've probably seen / had to use Kubernetes to some extent, but don't really *get* it yet? And you'd like to? Then this post is for you.

We'll talk through the fundamentals right up to what you can probably expect to see in a typical engineering org, and you'll run them yourself locally.

# Glossary

Before we begin, here are some of the fundamental building blocks we'll be talking about. Don't worry about remembering or even fully understanding these for now, this is just so that you've seen the words before when they come up later.

* **Node:** a worker machine running pods, managed by the Kubernetes control plane
* **Image:** read-only filesystem snapshot + metadata (env vars, command to run, etc)
* **Container:** running (or stopped) instance of an image, with a thin writeable layer
* **Pod:** smallest deployable unit, one or more containers sharing network/storage
* **Deployment:** managed a set of pods, handles rolling updates/rollbacks
* **Service:** stable network endpoint to reach a set of pods
* **StatefulSet:** like a deployment, but for stateful apps needing stable identity/storage
* **ConfigMap/Secret:** external configuration and sensitive data injected into pods
* **Namespace:** logical isolation within a cluster
* **Ingress:** HTTP routing into the cluster from outside
* **Volume/PersistentVolume:** storage that outlives a pod's lifecycle
* **kubectl:** CLI application to interact with the cluster


# Setup

In this tutorial we will be using [kind](https://kind.sigs.k8s.io/) as our Kubernetes implementation, backed by [docker](https://www.docker.com/).

Install [Docker Engine](https://docs.docker.com/engine/install) and make sure you're in the appropriate system groups to be able to run it without `sudo`. You do not need a Docker account, the desktop app, or any of their commercial or cloud offerings that the main website pushes.

Next, create a project directory (e.g. `k8s-learning`).

Finally, install kubernetes and the necessary software. If you're on [NixOS](https://nixos.org/) or otherwise have `nix` on your system, you can get a dev shell with everything you need by making file in your project directory called `flake.nix` with the following contents:


    {
      description = "Kubernetes learning environment";
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      outputs =
        { self, nixpkgs }:
        let
          # Adjust this line to your architecture as needed
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        {
          devShells.x86_64-linux.default = pkgs.mkShell {
            packages = [
              pkgs.kind
              pkgs.kubectl
              pkgs.kubernetes-helm
            ];
          };
        };
    }

and activate it by running `nix develop`.

Otherwise, take whatever steps you need to in order to install `kind`, `kubectl`, and `kubernetes-helm`.

# Map of the territory

We'll split this into four parts to keep things somewhat manageable. But here's the list of things we'll cover:

* **Part 1 (you are here)**
  * [Cluster setup](/infra/understanding-k8s-1#cluster-setup)
  * [First Pod](/infra/understanding-k8s-1#first-pod)
  * [Deployments & scaling](/infra/understanding-k8s-1#deployments--scaling)
  * [Services](/infra/understanding-k8s-1#services)
  * [Rolling updates & rollbacks](/infra/understanding-k8s-1#rolling-updates--rollbacks)
* [Part 2](/infra/understanding-k8s-2)
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







# Cluster setup

Our goal here is just to get a working cluster using `kind`, and confirm that you can interact with it using `kubectl`. You'll look at what's in it and get a feel for how it's running on your computer. We'll also talk about how a real Kubernetes deployment would differ.

## Create the cluster

Create your cluster with the following command:

```
kind create cluster --name learning
```

This creates a cluster with a single node: a Docker container which acts as both the Kubernetes control plane and a worker on which you can launch pods. It also points your `kubectl` context at it automatically. See this for yourself:

```
kubectl config current-context
```

Observe that this prints `kind-learning`.

## Look at your node

List the nodes in your Kubernetes cluster:

```
kubectl get nodes
```

You should see a single node with a status of `Ready`. Recall, this is both your Kubernetes control plane and your worker node. You can get more detailed summary by running `kubectl get nodes -o wide`.

## Look at your pods

List the pods running in your Kubernetes cluster:

```
kubectl get pods -A
```

The `-A` flag means "all namespaces". You'll see a bunch of system pods like `coredns`, `kube-proxy`, `etcd`,  and so on in the `kube-system` namespace. These make up the Kubernetes control plane, basically the nuts and bolts that make up Kubernetes itself, and run as pods inside the same node container. 

That is to say: the Kubernetes control plane is made of containers that run and are managed the same way your apps will be.

## Peek under the hood

Let's see what docker is running:

```
docker ps
```

As you can see, there's only one docker container, which is the node we talked about. This node container itself runs `containerd`, another container runtime.

The pods are also containers, running inside the node container. Observe these by running `crictl ps` inside the node:

```
docker exec -it learning-control-plane crictl ps
```

Note how these map onto the nodes you saw when you ran `kubectl get pods -A`.

A "real" Kubernetes deployment wouldn't have this nesting: each node would be its own separate machine or VM, which would run `containerd` directly. The layers we're dealing with here is just because we want to run a whole Kubernetes cluster on a single machine, so we effectively need to virtualize each node.

## Tear down and recreate the cluster

We don't particularly need to do this for any reason, and this isn't really a "Kubernetes" thing, but since we're working with `kind` in this guide it's worth knowing how to list, create, and delete a cluster.

```
kind get clusters
kind delete cluster --name learning
kind create cluster --name learning
```








# First Pod

Our goal here is to Write a Pod manifest for nginx, and then apply it. We'll connect to a shell running inside the pod via `kubectl exec`, have a look around, and then delete it.

## Write your manifest

We'll spin up an nginx webserver.

Create a file called `manifests/pod.yaml` with the following contents:

    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx-test
      labels:
        app: nginx-test
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80

Pretty much every Kubernetes manifest is going to have roughly the same shape here:
* `apiVersion` and `kind` identify what kind of object this is (a `Pod` from the `v1` API)
* `metadata` is how we'll identify what we're making
* `spec` is the state we want to achieve (Kubernetes's job is to reconcile this with reality)

## Create your Pod

First apply the manifest:

    kubectl apply -f manifests/pod.yaml

Now watch it come up:

    kubectl get pods

You can add a `-w` argument to the command above if you want to watch changes live (Ctrl-C to exit). You'll see it go from `Pending` to `ContainerCreating` to `Running`. As before, you can get more detail about your pods via `kubectl get pods -o wide`.

## Look at your pod

You can instruct Kubernetes to describe pretty much anything. In this case:

    kubectl describe pod nginx-test

Take a moment to read through the output fully to get a feel for what information is surfaced here.

Now pull up its logs:

    kubectl logs nginx-test

This will show the nginx webserver's startup log lines.

## Interact with it

First, we'll get a shell on our Pod:

    kubectl exec -it nginx-test -- /bin/sh
    # ~~ inside the Pod ~~
    curl localhost:80
    exit

You should see the nginx welcome page. You can also just run `curl` directly without spinning up an interactive shell:

    kubectl exec nginx-test -- curl localhost:80

Now pull up your Pod's logs again:

    kubectl logs nginx-test

You'll see the GET requests that it just fielded.



## Interact with it over the network

You currently have no ingress into your Kubernetes deployment, so you can't access it directly from your host's web browser. But we can get around this problem by just spinning up another temporary Pod in the cluster to use as a "jump host", and then interacting with our nginx Pod from there.

First lets note down the nginx Pod's IP address:

    kubectl get pods -o wide

Then we'll spin up a temporary pod inside our cluster:

    kubectl run debug --image=busybox --rm -it -- /bin/sh

Note that busybox doesn't have `curl`, so we'll need to use `wget`. From inside the pod:

    wget -O- [ip address from above]

You should once again see the nginx welcome page, this time having queried it from a different Pod in your cluster.

When you exit the temporary Pod, and you'll see that it gets automatically deleted (this was what the `--rm` flag did). Now if you check the nginx Pod's logs again, you'll see another request, this time not from localhost.


## Target an unavailable image

Delete the pod:

    kubectl delete pod nginx-test

then use `kubectl get pods` to confirm that it's gone.

Edit the manifest to change the image tag to something incorrect:

    image: nginx:idontexist

Apply the manifest as before, then describe the pod again:

    kubectl describe pod nginx-test

In the events section at the bottom, you should see `ImagePullBackoff`. When Kubernetes tries to pull an image that isn't available, it will enter this state.

## Clean up

Delete the pod again:

    kubectl delete pod nginx-test










# Deployments & scaling

In real life, you almost never create Pods directly. A Pod is ephemeral. If the Node dies, or if the Pod is deleted, then it's gone. The purpose of a Deployment is to say "I want *n* replicas of this Pod template at any given time", and then Kubernetes continually works to reconcile this with reality.

*Technically* a Deployment manages a ReplicaSet and the ReplicaSet manages the Pods, but you can mostly just ignore the concept of a ReplicaSet and be ok.

## Create a Deployment

Create a file called `manifests/deployment.yaml` with the following contents:

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deploy
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: nginx-deploy
      template:
        metadata:
          labels:
            app: nginx-deploy
        spec:
          containers:
            - name: nginx
              image: nginx:1.25
              ports:
                - containerPort: 80

Compare this with the manifest for a Pod - you'll notice that `spec.template` is itself essentially a Pod manifest.

Deployments do not themselves track which pods they spawn, which is what the `selector.matchLabels` is for: if any Pod has every label listed in a Deployment's `selector.matchLabels`, then it is considered part of the deployment.

Apply the manifest and look at what gets created:

    kubectl apply -f manifests/deployment.yaml
    kubectl get deployments
    kubectl get replicasets
    kubectl get pods -o wide

You should see one Deployment, one ReplicaSet, and three Pods, with names derived from each other.

Let's describe the Deployment:

    kubectl describe deployment nginx-deploy

Things worth noting here are the `Replicas`, `StrategyType`, and of course the `Events` section.

## Scale it imperatively

Let's scale up our deployment to 5 replicas:

    kubectl scale deployment nginx-deploy --replicas=5
    kubectl get pods

You should see two more replicas launch. If you're quick you might have seen them in the `ContainerCreating` state but they'll stabilize into `Running` after a moment or two.

## Scale it declaratively

Scaling things like we just did is fine, but we now have a problem: our manifest file no longer matches reality. In a production environment, you almost always want to do your actual scaling by way of modifying the manifest and re-applying it.

Edit `manifest/deployment.yaml` to change the number of replicas to `2` and then re-apply it:

    kubectl apply -f manifests/deployment.yaml
    kubectl get pods

You'll see three of the pods get terminated / disappear.

## Watch state reconciliation

Kill one of the pods and see what happens:

    kubectl get pods
    kubectl delete pod [one of the pod names]
    kubectl get pods

The pod you deleted disappears, but a new one automatically pops up to take its place. 

## Look at the ReplicaSet

Describe the ReplicaSet and Deployment:

    kubectl get replicasets
    kubectl describe replicaset [replicaset name]
    kubectl get deployments
    kubectl describe deployment nginx-deploy

While the Deployment sees events which describe the overall desired state, you need to look at the ReplicaSet to see events that happen to individual Pods. This is pretty much the only reason I know of to care about the fact that ReplicaSets exist.

## Clean up

Rather than manually deleting your Pods, ReplicaSet, and Deployment, we can just delete them all by referencing the manifest:

    kubectl delete -f manifests/deployment.yaml







# Services

The purpose of a Service is is to present "single unified thing" in front of a shifting set of individual Pods making up a Deployment.

When we first interacted with our nginx Pod, we used `curl` / `wget` to access it using the Pod's IP address.

When we spun up our Deployment, we saw each pod had its own IP address. We could select one to communicate with if we wanted to, but we don't particularly care which replica fields our request. Moreover, when we killed a Pod from the Deployment and watched it get replaced, we saw that IP addresses are as ephemeral as the Pods themselves.

A Service solves this problem. In practice, it takes the form of a stable address (both IP address and DNS bindings), and performs load balancing across replicas.

## Bring your deployment back

Re-apply the manifest to get your nginx Deployment back:

    kubectl apply -f manifests/deployment.yaml
    kubectl get pods -o wide

Notice how each pod has its own unique IP address.

## Create a ClusterIP service

Create a file called `manifests/service-clusterip.yaml` with the following contents:

    apiVersion: v1
    kind: Service
    metadata:
      name: nginx-svc
    spec:
      type: ClusterIP
      selector:
        app: nginx-deploy
      ports:
        - port: 80
          targetPort: 80

It's worth noting here that the `selector` here matches the labels applied to the *Pods*, and *not* anything on the Deployment. Services don't know or care about Deployments, they sit in front of Pods directly.

Apply the manifest then have a look:

    kubectl apply -f manifests/service-clusterip.yaml
    kubectl get service
    kubectl describe service nginx-svc

Note that when you listed the services, you got two results: Kubernetes also exposes its own control plane to the cluster as a service.

In the `describe` output, look for the `Endpoints` field. You should see the IP/ports of your Pods. This is the live, continually-updated set of destinations that this service will balance load between.

## Use the Service

Spin up another temporary busybox Pod:

    kubectl run debug --image=busybox --rm -it -- /bin/sh
    # ~~ now inside the temporary Pod ~~
    wget -O- nginx-svc

You should once again see the nginx welcome page. We didn't have to select an individual Pod, or look up IP addresses, or anything like that: CoreDNS resolved the `nginx-svc` name to the Service's IP address, which in turn forwarded the request to one of your replicas. You can peek at each of your Pods' logs if you want to see which one handled it.

## Kill some pods and try again

Back on your host:

    kubectl delete pod [one of your pods]
    kubectl get pods -o wide

Notice that the Pod you killed is gone, and a new one with a new and different IP address spun up to take its place.

Go ahead and ship-of-Theseus your Deployment by deleting the original versions of *all* of your pods. Then hop back into a temporary Pod and hit the service again like you did in the previous step, and see the nginx welcome page again.

In spite of the fact that we've cycled every pod and have a brand new set of IP addresses, we can still interact with the logical service without interruption through the Service's DNS name.


## Access from outside

A ClusterIP service is only accessible from inside the Kubernetes cluster. But sometimes you want to expose a service to outside the cluster. If you've got an HTTP service you're likely going to want to use Ingress, but NodePort can be useful in particular if you have a non-HTTP service you want to expose.

Copy your `manifests/service-clusterip.yaml` file to `manifests/service-nodeport.yaml`.
Then change `spec.type` from `ClusterIP` to `NodePort`, and then add a `nodePort` value of `30080` to the `spec.ports`.
The file should now look like this:

    apiVersion: v1
    kind: Service
    metadata:
      name: nginx-svc
    spec:
      type: NodePort
      selector:
        app: nginx-deploy
      ports:
        - port: 80
          targetPort: 80
          nodePort: 30080

Specifying the `nodePort` value is optional -- leaving it off just has Kubernetes pick a port for you, but by specifying it you'll have the same port as I do which makes our lives a little easier for the purposes of this tutorial.

Apply your manifest and have a look at your service:

    kubectl apply -f manifests/nodeport.yaml
    kubectl get service nginx-svc
    
When you deploy a NodePort service, it opens a specific port on every Node of your cluster, which forwards traffic to the Service inside the cluster. As such, the Deployment is now accessible to anything that can reach your Kubernetes Nodes.

So under normal circumstances, you'd now be able to see the nginx welcome page in your computer's browser. *However*, `kind` does not expose external port mappings unless you specify them when creating the cluster, so we can't quite do that right now. But we can get close, by connecting to the Docker container that's running our Node, and interacting with the Service from there:

    docker exec -it learning-control-plane /bin/sh
    # ~~ now inside the Node (docker container) ~~
    curl localhost:30080

You should, once again, see the nginx welcome page. This time, however, you hit the service from *outside* the cluster.

## Clean up

Once again, this is easiest to do from our manifests:

    kubectl delete -f manifests/service-clusterip.yaml
    kubectl delete -f manifests/service-nodeport.yaml
    kubectl delete -f manifests/deployment.yaml










# Rolling updates & rollbacks

You will eventually want to change what's running in your cluster. Maybe you're upgrading nginx, or maybe pushing a new vesion of your code. Kubernetes has tools for doing this.

## Launch your Deployment and Service

Re-apply your manifests to spin everything back up.

    kubectl apply -f manifests/deployment.yaml
    kubectl apply -f manifests/service-clusterip.yaml

Then confirm that your pods are running nginx 1.25:

    kubectl get pods
    kubectl describe pod [one of the pods]

## Update your deployment

Now, edit `manifests/deployment.yaml` and change the image to `nginx:1.26`, then apply it and watch the rollout status. We'll run both commands with a single invocation since the deploy will happen very quickly:

    kubectl apply -f manifests/deployment.yaml && \
    kubectl rollout status deployment nginx-deploy

The `kubectl rollout status` command blocks until the rollout is complete, which is handy in an automation context.

## Watch the ReplicaSet

It's worth noting that while the image in a Deployment can be upgraded, the ReplicaSet (which is the thing that contains / manages the Pods) cannot. See this for yourself: edit your manifest to drop the image version back down to 1.25, and then right after you apply it, run this command a few times:

    kubectl get replicaset

You'll see it creates a *new* ReplicaSet, and starts spinning down Pods from the old one and spinning up new Pods in the new one. 

## Deploy something broken

Edit `manifests/deployment.yaml` to change the image to `nginx:idontexist`. Then apply it and watch the rollout:

    kubectl apply -f manifests/deployment.yaml
    kubectl rollout status deployment nginx-deployment

This will block, since the rollout can't complete with a broken image. Ctrl-C out of it and have a look at your pods:

    kubectl get pods

You can see that it has spun down one of your old replicas, and has been trying to spin up replacements in a new ReplicaSet, but they end up in an `ImagePullBackoff` state. While this is ongoing, the old version of your application is still responding happily (albeit with one fewer replicas than usual). This is the "rolling update" strategy that Kubernetes uses.

## Roll back

Check your rollout history:

    kubectl rollout history deployment nginx-deploy

You'll probably see a handful of revisions from the various deploys you've done since creating the deployment. Let's roll back to the previous deployment and look again:

    kubectl rollout undo deployment nginx-deploy
    kubectl rollout status deployment nginx-deploy
    kubectl get pods

The `rollout staus` command now terminates, and you can see you're back to running your full contingent of properly configured pods. 

But notice that when you ran `rollout undo`, you got a warning. We just affected the status of the deployment imperatively, which means we have once again drifted away from what our manifest says. This is OK for emergency situations, but in general usage you'll want to be operating declaratively instead: editing your manifest and applying it rather than faffing around with things like `rollout undo` and so on.

## Clean up

Delete your resources again:

    kubectl delete -f manifest/deployment.yaml
    kubectl delete -f manifest/service-clusterip.yaml








# Next steps

Check out [Part 2](/infra/understanding-k8s-2), where we'll dig into configuration and persistence.
