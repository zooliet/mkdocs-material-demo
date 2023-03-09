# Getting Started

## Requirements

At the current state of Kubernetes, running cloud controller manager requires a few things. Please read through the requirements carefully as they are critical to running cloud controller manager on a Kubernetes cluster on DigtialOcean.

### Version

These are the recommended versions to run the cloud controller manager based on your Kubernetes version

* Use CCM versions <= v0.1.1 if you're running Kubernetes version v1.7
* Use CCM versions >= v0.1.2 if you're running Kubernetes version v1.8
* Use CCM versions >= v0.1.4 if you're running Kubernetes version v1.9 - v1.10
* Use CCM versions >= v0.1.5 if you're running Kubernetes version >= v1.10
* Use CCM versions >= v0.1.8 if you're running Kubernetes version >= v1.11

### --cloud-provider=external

All `kubelet`s in your cluster **MUST** set the flag `--cloud-provider=external`. `kube-apiserver` and `kube-controller-manager` must **NOT** set the flag `--cloud-provider` which will default them to use no cloud provider natively.

**WARNING**: setting `--cloud-provider=external` will taint all nodes in a cluster with `node.cloudprovider.kubernetes.io/uninitialized`, it is the responsibility of cloud controller managers to untaint those nodes once it has finished initializing them. This means that most pods will be left unscheduable until the cloud controller manager is running.

In the future, `--cloud-provider=external` will be the default. Learn more about the future of cloud providers in Kubernetes [here](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/cloud-provider/cloud-provider-refactoring.md).

### Kubernetes node names must match the droplet name, private ipv4 ip or public ipv4 ip

By default, the kubelet will name nodes based on the node's hostname. On DigitalOcean, node hostnames are set based on the name of the droplet. If you decide to override the hostname on kubelets with `--hostname-override`, this will also override the node name in Kubernetes. It is important that the node name on Kubernetes matches either the droplet name, private ipv4 ip or the public ipv4 ip, otherwise cloud controller manager cannot find the corresponding droplet to nodes.

When setting the droplet host name as the node name (which is the default), Kubernetes will try to reach the node using its host name. However, this won't work since host names aren't resovable on DO. For example, when you run `kubectl logs` you will get an error like so:

```bash
$ kubectl logs -f mypod
Error from server: Get https://k8s-worker-03:10250/containerLogs/default/mypod/mypod?follow=true: dial tcp: lookup k8s-worker-03 on 67.207.67.3:53: no such host
```

Since on DigitalOcean the droplet's name is not resolvable, it's important to tell the Kubernetes masters to use another address type to reach its workers. You can do this by setting `--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname` on the apiserver. Doing this will tell Kubernetes to use a droplet's private IP to connect to the node before attempting it's public IP and then it's host name.

### All droplets must have unique names

All droplet names in kubernetes must be unique since node names in kubernetes must be unique.

## Implementation Details

Currently `digitalocean-cloud-controller-manager` implements:

* nodecontroller - updates nodes with cloud provider specific labels and addresses, also deletes kubernetes nodes when deleted on the cloud provider.
* servicecontroller - responsible for creating LoadBalancers when a service of `Type: LoadBalancer` is created in Kubernetes.

In the future, it may implement:

* volumecontroller - responsible for creating, deleting, attaching and detaching DO block storage.
* routecontroller - responsible for creating firewall rules

### Resource Tagging

When the environment variable `DO_CLUSTER_ID` is given, `digitalocean-cloud-controller-manager` will use it to tag DigitalOcean resources additionally created during runtime (such us load-balancers) accordingly. The cloud ID is usually represented by a UUID and prefixed with `k8s:` when tagging, e.g., `k8s:c63024c5-adf7-4459-8547-9c0501ad5a51`.

The primary purpose of the variable is to allow DigitalOcean customers to easily understand which resources belong to the same DOKS cluster. Specifically, it is not needed (nor helpful) to have in DIY cluster installations.

### Custom VPC

When a cluster is created in a non-default VPC for the region, the environment variable `DO_CLUSTER_VPC_ID` must be specified or Load Balancer creation for services will fail.

## Deployment

### Token

To run `digitalocean-cloud-controller-manager`, you need a DigitalOcean personal access token. If you are already logged in, you can create one [here](https://cloud.digitalocean.com/settings/api/tokens). Ensure the token you create has both read and write access. Once you have a personal access token, create a Kubernetes Secret as a way for the cloud controller manager to access your token. You can do this with one of the following methods:

#### Script

You can use the script [scripts/generate-secret.sh](https://github.com/digitalocean/digitalocean-cloud-controller-manager/blob/master/scripts/generate-secret.sh) in this repo to create the Kubernetes Secret. Note that this will apply changes using your default `kubectl` context. For example, if your token is `abc123abc123abc123`, run the following to create the Kubernetes Secret.

```bash
export DIGITALOCEAN_ACCESS_TOKEN=abc123abc123abc123
scripts/generate-secret.sh
```

#### Manually

Copy [releases/secret.yml.tmpl](https://github.com/digitalocean/digitalocean-cloud-controller-manager/blob/master/releases/secret.yml.tmpl) to releases/secret.yml:

```bash
cp releases/secret.yml.tmpl releases/secret.yml
```

Replace the placeholder in the copy with your token. When you're done, the releases/secret.yml should look something like this:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: digitalocean
  namespace: kube-system
stringData:
  access-token: "abc123abc123abc123"
```

Finally, run this command from the root of this repo:

```bash
kubectl apply -f releases/secret.yml
```

You should now see the digitalocean secret in the `kube-system` namespace along with other secrets

```bash
$ kubectl -n kube-system get secrets
NAME                  TYPE                                  DATA      AGE
default-token-jskxx   kubernetes.io/service-account-token   3         18h
digitalocean          Opaque                                1         18h
```

### Cloud controller manager

Currently we only support alpha release of the `digitalocean-cloud-controller-manager` due to its active development. Run the first alpha release like so

```bash
kubectl apply -f releases/v0.1.13.yml
deployment "digitalocean-cloud-controller-manager" created
```

NOTE: the deployments in `releases/` are meant to serve as an example. They will work in a majority of cases but may not work out of the box for your cluster.
