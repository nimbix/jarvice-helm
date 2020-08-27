# Kubernetes Cluster Installation

This documentation describes a highly opinionated kubernetes cluster
installation procedure which uses `kubeadm`.
It is intended to outline and illustrate the most straightforward
way to stand up a proof of concept (PoC) cluster which can be used for
deploying JARVICE.  It is not intended to be authoratative documentation for
site-specific production deployments.

There are a myriad of options to work with when considering a site-specific
production deployment of a kubernets cluster.  Visit the following links to
get started and find out more:

* [Getting started - Kubernetes](https://kubernetes.io/docs/setup/#production-environment)
* [Bootstrapping clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

Please be sure to read the rest of this document thoroughly before beginning
a PoC cluster installation.

------------------------------------------------------------------------------

## Table of Contents

* [System Overview](#system-overview)
    - [Machine components](#machine-components)
    - [Cluster software components](#cluster-software-components)
    - [Deployed software components](#deployed-software-components)
* [Prerequisites for Cluster Installation](#prerequisites-for-cluster-installation)
    - [Scripts from the JARVICE helm chart git repository](#scripts-from-the-jarvice-helm-chart-git-repository)
    - [Access to cluster nodes](#access-to-cluster-nodes)
        - [SSH keys](#ssh-keys)
        - [Configuring sudoers](#configuring-sudoers)
    - [CIDRs for IP address blocks](#cidrs-for-ip-address-blocks)
    - [IP address range or subnet for accessing JARVICE](#ip-address-range-or-subnet-for-accessing-jarvice)
    - [DNS host entry or entries](#dns-host-entry-or-entries)
    - [SSL/TLS certificate and key](#ssl-tls-certificate-and-key)
    - [Cluster nodes](#cluster-nodes)
        - [Control plane endpoint (HAProxy load balancer)](#control-plane-endpoint-HAProxy-load-balancer)
        - [Kubernetes master nodes](#kubernetes-master-nodes)
        - [Kubernetes worker nodes](#kubernetes-worker-nodes)
            - [jarvice-system nodes](#jarvice-system-nodes)
            - [jarvice-dockerbuild nodes (optional)](#jarvice-dockerbuild-nodes-optional)
            - [jarvice-compute nodes](#jarvice-compute-nodes)
* [Node Software Installation](#node-software-installation)
    - [HAProxy (control plane endpoint)](#haproxy-control-plane-endpoint)
        - [Control plane endpoint on a kubernetes master node](#control-plane-endpoint-on-a-kubernetes-master-node)
    - [Docker and kubeadm](#docker-and-kubeadm)
        - [SELinux](#selinux)
        - [Update firewall settings](#update-firewall-settings)
            - [Ports on master nodes](#ports-on-master-nodes)
            - [Ports on worker nodes](#ports-on-worker-nodes)
* [Cluster Stand Up](#cluster-stand-up)
    - [Initialize cluster](#initialize-cluster)
        - [Saving the join commands](#saving-the-join-commands)
    - [Install `kubectl` on a client machine](#install-kubectl-on-a-client-machine)
        - [Create configuration file](#create-configuration-file)
        - [Verify configuration](#verify-configuration)
    - [Deploy a pod network plugin/add-on](#deploy-a-pod-network-plugin-add-on)
        - [Kube-Router](#kube-router)
            - [Verify Kube-Router deployment](#verify-kube-router-deployment)
            - [Update firewall settings for Kube-Router](#update-firewall-settings-for-kube-router)
        - [Weave Net](#weave-net)
            - [Verify Weave Net deployment](#verify-weave-net-deployment)
            - [Update firewall settings for Weave Net](#update-firewall-settings-for-weave-net)
    - [Add master nodes](#add-master-nodes)
    - [Add worker nodes](#add-worker-nodes)
    - [Label and taint kubernetes worker nodes](#label-and-taint-kubernetes-worker-nodes)
        - [Add node labels](#add-node-labels)
        - [Add node taints](#add-node-taints)
* [Enable External Access to Cluster Applications](#enable-external-access-to-cluster-applications)
    - [Install helm package manager](#install-helm-package-manager)
    - [Kubernetes load balancer](#kubernetes-load-balancer)
    - [Kubernetes ingress controller](#kubernetes-ingress-controller)
* [Deploy JARVICE](#deploy-jarvice)
* [Scaling Up the Kubernetes Cluster](#scaling-up-the-kubernetes-cluster)
    - [Adding kubernetes worker nodes](#adding-kubernetes-worker-nodes)
    - [Adding kubernetes master nodes](#adding-kubernetes-master-nodes)
* [Upgrading the Kubernetes Cluster](#upgrading-the-kubernetes-cluster)
    - [Prerequisites for cluster upgrade](#prerequisites-for-cluster-upgrade)
        - [Package repository](#package-repository)
        - [User with `sudo` access](#user-with-sudo-access)
        - [SSH access from a `kubectl` client machine](#ssh-access-from-a-kubectl-client-machine)
    - [Review kubernetes documentation](#review-kubernetes-documentation)
    - [Upgrade scripts](#upgrade-scripts)
        - [`upgrade-kubeadm-cluster`](#upgrade-kubeadm-cluster)
        - [`upgrade-kubeadm`](#upgrade-kubeadm)
        - [`upgrade-kubelet`](#upgrade-kubelet)
* [Additional Resources](#additional-resources)

------------------------------------------------------------------------------

## System Overview

Before getting started, here is a brief overview of the various components
that will be used for the kubernetes cluster installation and
JARVICE deployment into the cluster.

### Machine components

These are the virtual machine and/or bare metal nodes that will be necessary
for running a kubernetes cluster with JARVICE deployed into it:

* Kubernetes control plane endpoint
    - Node(s) that serve as the entrypoint and load balancer to the master nodes
* Kubernetes master nodes
    - Three or more nodes that serve as the cluster control plane
* Kubernetes worker nodes
    - Three or more nodes for running the `jarvice-system` deployment
    - Two or more nodes for running `jarvice-compute` work
* Kubernetes client node
    - A node which interacts with and manages the cluster

### Cluster software components

These are the software components that will be used to stand up the
kubernetes cluster itself and deploy JARVICE into the cluster:

* HAProxy
    - Load balancer that serves as the control plane endpoint for the API servers running on the kubernetes master nodes.
* Docker
    - Kubernetes leverages docker to run it's system kubelets and applications on master and worker nodes.
* kubeadm
    - Used to initialize the kubernetes cluster and enable the system kubelets on the master and worker nodes.
* kubectl
    - Command line client for communicating with the kubernetes control plane endpoint.
* helm
    - Command line client to deploy and manage software **in** the kubernetes cluster.

### Deployed software components

These are the software components that will be deployed **into** the
kubernetes cluster:

* Kubernetes pod network add-on
    - Pod network manager for routing traffic between kubernetes pods
* Kubernetes load balancer
    - Enables IP routing into the cluster from external sources
* Kubernetes ingress controller
    - Enables name based (DNS) access to the cluster from external sources
* JARVICE
    - High performance computing (HPC) technology for kubernetes

------------------------------------------------------------------------------

## Prerequisites for Cluster Installation

### Scripts from the JARVICE helm chart git repository

The scripts referred to in this documentation can be found in the JARVICE
helm chart git repository.  If you have not done so already, clone this
git repository onto the client machine that will be used to access the
kubernetes cluster:

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

The scripts have been tested on Ubuntu 16.04 (Xenial), Ubuntu 18.04 (Bionic),
and CentOS 7.  The scripts assume that they are being executed on a
fresh, minimal Linux installation.  They also assume `sudo` or `root` access
on each node in the cluster.

Also, if configuration management software (puppet, chef, ansible, etc.) is
being used to manage the operating system on the cluster nodes, be certain
that it is disabled or will not undo any system updates and changes done by
the scripts.  As an alternative, the code in the scripts can serve as a
reference for integrating a kubernetes cluster setup into a configuration
management environment.

### Access to cluster nodes

#### SSH keys

On the client machine that will be used to access the cluster nodes, it is
recommended that you create SSH keys using `ssh-keygen` and then copy
the generated keys to each cluster node using `ssh-copy-id`.  This will make
the example commands and script executions in this document work more
seemlessly.

It may be necessary to manually set up `ssh-agent` on your client machine
if it is not already running.  See the following link for more information
on `ssh-agent`:
https://www.ssh.com/ssh/agent

#### Configuring sudoers

Several of the example commands and script executions in this document will
also work more seemlessly if the cluster nodes are set up with passwordless
`sudo` access for a user without a tty requirement.

Assuming the user is named `jarvice`, something similar to the following
could be written to the configuration file
`/etc/sudoers.d/99_jarvice` to enable that access for the `jarvice` user:
```bash
jarvice ALL=(ALL) NOPASSWD: ALL
Defaults: jarvice !requiretty
```

### CIDRs for IP address blocks

By default, kubernetes uses `10.96.0.0/12` (`10.96.0.1-10.111.255.254`) as the
default CIDR for the range of virtual IP addresses which are assigned to
kubernetes services.
In addition, `10.32.0.0/12` (`10.32.0.1-10.47.255.254`) is the default CIDR
used by certain pod network add-ons for assigning IP addresses to kubernetes
pods.

The above CIDR blocks will be used during the initialization of the kubernetes
cluster.  If either address block may conflict with IP addresses
at your site, or any connecting satellite sites, it will be necessary to
arrange for the use of alternative CIDR blocks before continuing with the
installation and stand up of a kubernetes cluster.

### IP address range or subnet for accessing JARVICE

Once the kubernetes cluster is installed, an IP address range or subnet will
be required to access the JARVICE portal and JARVICE API endpoint in order
to run jobs on the platform.

In our example installation below, we will use a subnet of `10.20.0.0/30`
with an IP range of `10.20.0.1-10.20.0.2`.  This range will be used when
configuring the [kubernetes load balancer](#kubernetes-load-balancer).

### DNS host entry or entries

DNS will need to be configured in order access the JARVICE portal, JARVICE
API endoint, and JARVICE jobs by host names instead of IP addresses.
A wild card DNS setup, such as `*.k8s.my-domain.com`, is the
recommended solution for JARVICE.  The DNS name(s) should resolve to one of
the IP addresses within the
[IP address range or subnet for accessing JARVICE](#ip-address-range-or-subnet-for-accessing-jarvice).

The DNS host(s) will be used when configuring the ingress host(s) during the
[JARVICE deployment](README.md#jarvice-standard-installation).

### SSL/TLS certificate and key

A SSL/TLS certificate and key will be needed for secure access to the
kubernetes cluster.  The certificate should match the wildcard domain
configured for the [DNS host entry or entries](#dns-host-entry-or-entries)
that will be used to access JARVICE.

The certificate and key will be used when deploying and configuring the
[kubernetes ingress controller](#kubernetes-ingress-controller).

### Cluster nodes

The commands and examples in the following sections of this document will be
using the example layout, node host names, and IP addresses/ranges as
described.  This layout is meant to outline the minimal number of
nodes and their requirements for running JARVICE on a kubernetes cluster.

Be sure to adjust the example host names and IPs used in the commands and
examples so that they match your environment.

**Note:**
For all of the kubernetes master and worker nodes, the `/var` partition
should be assigned all disk space not required by the base Linux installation.
The `/var` partition will hold all of the data used by docker and
the kubernetes kubelets.
The kubernetes master nodes will also use `/var` to hold etcd data.

**Note:**
The kubernetes master and worker nodes will be set up using kubeadm.
Detailed requirements will be described for each node type below.
The more general, minimum requirements for kubeadm can be found via the
following link:
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#before-you-begin

#### Control plane endpoint (HAProxy load balancer)

In the following example installation,
we will use a single node for the control plane endpoint.
The minimum recommended requirements call for a virtual machine or
bare metal server with 2 CPUs and 1 GB of RAM.
The disk usage will be minimal as long as the node's Linux installation
provides enough space for log files in `/var`.

We'll use the following host name for the control plane endpoint
in the example commands below:

* k8s-master

**Note:**  If desired, the control plane endpoint could be installed on one
of the kubernetes master nodes instead of it's own, separate node.

**Also note:**  A production cluster installation would use a
high availability (HA) setup for the control plane endpoint which utilizes
multiple load balancer instances running in a failover or round robin
configuration.  A HA setup of the control plane endpoint is recommended,
but is beyond the scope of this documentation.

#### Kubernetes master nodes

At a minimum, three kubernetes master nodes will be required.  

For JARVICE, the minimum recommended requirements per node calls for
virtual machines or bare metal servers with 2 CPUs and 8 GB of RAM.
The amount of disk space needed will largely depend on the cluster usage, but
100 GB of disk space is recommended.

We'll use the following host names for the kubernetes master nodes
in the example commands below:

* k8s-master-00
* k8s-master-01
* k8s-master-02

#### Kubernetes worker nodes

It should be expected that six kubernetes worker nodes will be required for
running JARVICE.  Note, however, that more nodes may be desired in the
event that it becomes necessary to scale up the JARVICE deployment.

The kubernetes worker nodes will be given `jarvice-system`, `jarvice-compute`,
and optionally `jarvice-dockerbuild` roles.  The requirements for worker nodes
of each type will vary somewhat.  Those requirements are described below.

##### jarvice-system nodes

At a minimum, three `jarvice-system` nodes will be required.  However, it is
suggested that four `jarvice-system` nodes be used in case it becomes
necessary to scale up the JARVICE system deployment.

For JARVICE, the minimum recommended requirements per node calls for
virtual machines or bare metal servers with 8 CPUs and 32 GB of RAM.
The amount of disk space needed will largely depend on the cluster usage, but
100 GB of disk space is recommended.

We'll use the following host names for the `jarvice-system` worker nodes
in the example commands below:

* k8s-worker-00
* k8s-worker-01
* k8s-worker-02
* k8s-worker-03

##### jarvice-dockerbuild nodes (optional)

For JARVICE, the minimum recommended requirements per node calls for
virtual machines or bare metal servers with 8 CPUs and 32 GB of RAM.
The amount of disk space needed will largely depend on the number of JARVICE
application builds that will be done and the size of the docker images those
builds will produce.
500 GB of disk space is the recommended minimum.

If the `jarvice-dockerbuild` node will be used to build very large JARVICE
application images, it is also recommended that the `/var` partition be
placed on a solid state drive (SSD) as a SSD can greatly speed up image
build time and docker cache utilization.

We'll use the following host names for the `jarvice-dockerbuild` worker node
in the example commands below:

* k8s-worker-04

##### jarvice-compute nodes

At a minimum, two `jarvice-compute` nodes will be required.  However, the
total number of `jarvice-compute` nodes will depend on the number of jobs
run by JARVICE users.  The number of `jarvice-compute` nodes may vary widely
per site specific user numbers and JARVICE job requirements.

For JARVICE, the minimum recommended requirements per node calls for
bare metal servers with 8 CPUs and 32 GB of RAM.
These minimums will be sufficient to run small jobs in JARVICE, but note
that the per node CPU and RAM requirements may also vary widely per site.
The minimums will primarily depend on the types of jobs that will be run
with JARVICE.  Please contact Nimbix sales or support for more information.

200 GB of disk space is the recommended minimum.

We'll use the following host names for the `jarvice-compute` worker nodes
in the example commands below:

* k8s-worker-10
* k8s-worker-11

### Firewall settings on the cluster nodes

It will be necessary to either disable any active firewall on the cluster
nodes or open up the ports which are required by kubernetes.
CentOS uses `firewalld` which is enabled by default.
Ubuntu uses `ufw` which is disabled by default.

The sections below outline the commands needed to open up ports with
`firewalld`.

#### Disabling firewall

If it is preferable to simply disable the firewall,
it can be disabled on each CentOS node with the following commands:
```bash
$ sudo systemctl stop firewalld
$ sudo systemctl disable firewalld
$ sudo systemctl mask --now firewalld
```

------------------------------------------------------------------------------

## Node Software Installation

The example commands below require that the scripts from the JARVICE helm
chart git repository exist on each of the cluster nodes.
Execute the following to clone that git repository on each of the destination
nodes:
```bash
$ NODES="k8s-master k8s-master-00 k8s-master-01 k8s-master-02 k8s-worker-00 k8s-worker-01 k8s-worker-02 k8s-worker-03 k8s-worker-04 k8s-worker-10 k8s-worker-11"
$ USER=jarvice
$ CMD=$(cat <<EOF
[ -f /etc/centos-release ] && sudo yum -y install git || (sudo apt-get -y update && sudo apt-get -y install git)
git clone https://github.com/nimbix/jarvice-helm.git
EOF
)
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

Be sure to adjust the `NODES` and `USER` before executing the above commands.
Note that the `USER` is assumed to have password-less `sudo` access with
`!requiretty` on each of the `NODES`.  Without such a setup, it
will be necessary to manually execute the commands on each node.
Also note that if ssh keys have not been installed on each of the nodes, you
will be prompted for the `USER` password for each node that is referenced.

### HAProxy (control plane endpoint)

The `install-haproxy` script can be used to install and configure `HAProxy`
on the cluster's control plane endpoint.  Execute
`./jarvice-helm/scripts/install-haproxy --help` to see it's usage.

For our example cluster, ssh into the control plane endpoint as `USER` and
execute the following:
```bash
$ ./jarvice-helm/scripts/install-haproxy \
    --master k8s-master-00 --master k8s-master-01 --master k8s-master-02
```

#### Control plane endpoint on a kubernetes master node

If the control plane endpoint will live on one of the kubernetes master nodes,
it will be necessary to adjust the default port HAProxy listens on.
Assuming that the control plane endpoint will also live on `k8s-master-00`,
execute `install-haproxy` from that nodes with the `--address` flag to
adjust the port:
```bash
$ ./jarvice-helm/scripts/install-haproxy \
    --master k8s-master-00 --master k8s-master-01 --master k8s-master-02 \
    --address "*:7443"
```

#### Open firewall port

If the control plane endpoint node is running CentOS with `firewalld` enabled,
execute the following to open up the appropriate port:

```bash
$ PORT="6443/tcp"
$ sudo firewall-cmd --permanent --add-port=$PORT
$ sudo systemctl restart firewalld
```

### Docker and kubeadm

The `install-docker` and `install-kubeadm` scripts can be used to install
docker and kubeadm respectively on each kubernetes cluster node.  Execute
each script with the `--help` flag to see their usage.

Assuming that `USER` has password-less, `!requiretty` sudo access, execute
the following to install docker and kubeadm on the kubernetes master and
worker nodes:
```bash
$ NODES="k8s-master-00 k8s-master-01 k8s-master-02 k8s-worker-00 k8s-worker-01 k8s-worker-02 k8s-worker-03 k8s-worker-04 k8s-worker-10 k8s-worker-11"
$ USER=jarvice
$ CMD="./jarvice-helm/scripts/install-docker && ./jarvice-helm/scripts/install-kubeadm"
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

The above scripts will set up their corresponding apt/yum repositories before
installing the packages.  The `install-kubeadm` script will also disable swap
on the system and apply `sysctl` updates.
On CentOS, it will also disable SELinux.

#### SELinux

On CentOS nodes, you may wish to re-enabled SELinux.  In the instance that
you choose to do so, there is the potential that certain JARVICE applications
may not work due to SELinux restrictions.  If so, it will be necessary to
generate a local policy module on each of the `jarvice-compute` worker nodes
to allow whichever operations are being denied by SELinux.  Refer to the
[audit2allow](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/selinux_users_and_administrators_guide/sect-security-enhanced_linux-troubleshooting-fixing_problems#sect-Security-Enhanced_Linux-Fixing_Problems-Allowing_Access_audit2allow)
documentation for more details on creating local policy modules.

#### Update firewall settings

On CentOS nodes which have `firewalld` enabled, it will be necessary to open
up the appropriate ports.

##### Ports on master nodes

For the master nodes, execute the following:
```bash
$ NODES="k8s-master-00 k8s-master-01 k8s-master-02"
$ USER=jarvice
$ CMD=$(cat <<EOF
PORTS="6443/tcp 2379-2380/tcp 10250/tcp 10251/tcp 10252/tcp 10255/tcp 8472/udp"
for p in $PORTS; do
    sudo firewall-cmd --permanent --add-port=$p;
done
sudo firewall-cmd --add-masquerade --permanent
sudo systemctl restart firewalld
EOF
)
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

##### Ports on worker nodes

For the worker nodes, execute the following:
```bash
$ NODES="k8s-worker-00 k8s-worker-01 k8s-worker-02 k8s-worker-03 k8s-worker-04 k8s-worker-10 k8s-worker-11"
$ USER=jarvice
$ CMD=$(cat <<EOF
PORTS="10250/tcp 10255/tcp 8472/udp"
for p in $PORTS; do
    sudo firewall-cmd --permanent --add-port=$p;
done
sudo firewall-cmd --add-masquerade --permanent
sudo systemctl restart firewalld
EOF
)
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

------------------------------------------------------------------------------

## Cluster Stand Up

### Initialize cluster

On the first kubernetes master node, execute the following commands (with any
necessary substitutions) to initialize the cluster:
```bash
$ SERVICE_CIDR=10.96.0.0/12
$ POD_NETWORK_CIDR=10.32.0.0/12
$ CONTROL_PLANE_ENDPOINT=k8s-master:6443
$ sudo kubeadm init --service-cidr "$SERVICE_CIDR" --pod-network-cidr "$POD_NETWORK_CIDR" --control-plane-endpoint "$CONTROL_PLANE_ENDPOINT" --upload-certs
```

As mentioned in [CIDRs for IP address blocks](#cidrs-for-ip-address-blocks),
it will be necessary to set `SERVICE_CIDR` and `POD_NETWORK_CIDR` to CIDR
blocks which will not conflict IP addresses at your site(s).

Also, if `--address` was specified when initializing the control plane
endpoint with `install-haproxy`, be sure that `CONTROL_PLANE_ENDPOINT`
matches the port value passed in with that flag.

#### Saving the join commands

The `kubeadm init` output will show two separate `kubeadm join` commands
that will be needed to add additional nodes later on.  Be sure to copy and
save these commands.

The first join command will be used for joining additional master nodes.
It will look similar to this:
```bash
$ kubeadm join k8s-master:6443 --token y8ilih.syk2g16evujwtzx4 \
    --discovery-token-ca-cert-hash sha256:08fae14ad35691a5af851648d57c0c1413048023a94657401262989aa532ac1c \
    --control-plane \
    --certificate-key 44bb1cfcf55ed8e343aa76765d4e4057d524fcacc453d6f18dc4881856f59da6
```

The second join command will be used for joining worker nodes.
It will look similar to this:
```bash
$ kubeadm join k8s-master:6443 --token y8ilih.syk2g16evujwtzx4 \
    --discovery-token-ca-cert-hash sha256:08fae14ad35691a5af851648d57c0c1413048023a94657401262989aa532ac1c
```

### Install `kubectl` on a client machine

The `install-kubectl` script can be used to install `kubectl` onto a client
machine which will be used to access the kubernetes cluster.  Execute
`./jarvice-helm/scripts/install-kubectl --help` to see it's usage.

Simply execute the following to use the script to install `kubectl` onto
the machine you wish to access the cluster from:
```bash
$ ./jarvice-helm/scripts/install-kubectl
```

#### Create configuration file

It will be necessary to create a `~/.kube/config` file so that `kubectl`
can access the newly initialized cluster.  Simply copy the
`/etc/kubernetes/admin.conf` from the inital kubernetes master node to
`~/.kube/config` or use the following commands to create it:
```bash
$ NODE=k8s-master-00
$ USER=jarvice
$ CMD="sudo cat /etc/kubernetes/admin.conf"
$ mkdir -p ~/.kube && ssh $USER@$NODE "$CMD" >~/.kube/config && chmod 600 ~/.kube/config
```

#### Verify configuration

Execute the following to verify that the client is able to communicate with
the cluster control plane:
```bash
$ kubectl get nodes
```

The output should show a single master node in the `NotReady` state.

### Deploy a pod network plugin/add-on

After access to the kubernetes cluster has been verified, a pod network
plugin must be deployed in order for kubernetes pods to be able to
communicate with each other.  We currently recommend the following plugins:

* [Kube-Router (www.kube-router.io)](https://www.kube-router.io/)
* [Weave Net (www.weave.works)](https://www.weave.works/oss/net/)

**WARNING:** Only one pod network plugin may be deployed into a cluster.

#### Kube-Router

The `deploy2k8s-kube-router` script can be used to deploy this plugin into the
cluster.  Execute `./jarvice-helm/scripts/deploy2k8s-kube-router --help` to
see it's usage.

Execute the following to deploy it into the kubernetes cluster:
```bash
$ ./jarvice-helm/scripts/deploy2k8s-kube-router
```

##### Verify Kube-Router deployment

After deployment, from a `kubectl` client machine, verify that the
initial kubernetes master node is in the `Ready` state:
```bash
$ kubectl get nodes
```

##### Update firewall settings for Kube-Router

On CentOS nodes which have `firewalld` enabled, it will be necessary to open
up the appropriate port.
Execute the following to do so:

```bash
$ NODES="k8s-master-00 k8s-master-01 k8s-master-02 k8s-worker-00 k8s-worker-01 k8s-worker-02 k8s-worker-03 k8s-worker-04 k8s-worker-10 k8s-worker-11"
$ USER=jarvice
$ CMD="sudo firewall-cmd --permanent --add-port=20244/tcp; sudo systemctl restart firewalld"
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

#### Weave Net

The `deploy2k8s-weave-net` script can be used to deploy this plugin into the
cluster.  Execute `./jarvice-helm/scripts/deploy2k8s-weave-net --help` to
see it's usage.

Execute the following to deploy it into the kubernetes cluster:
```bash
$ POD_NETWORK_CIDR=10.32.0.0/12
$ ./jarvice-helm/scripts/deploy2k8s-weave-net --ipalloc-range $POD_NETWORK_CIDR
```

For this plugin, be sure to set `POD_NETWORK_CIDR` to the value used with
the `--pod-network-cidr` flag during cluster initialization.  As mentioned in
[CIDRs for IP address blocks](#cidrs-for-ip-address-blocks), the IP
addresses represented by this CIDR should not conflict with any addresses
used at your connecting site(s).

##### Verify Weave Net deployment

After deployment, from a `kubectl` client machine, verify that the
initial kubernetes master node is in the `Ready` state:
```bash
$ kubectl get nodes
```

##### Update firewall settings for Weave Net

On CentOS nodes which have `firewalld` enabled, it will be necessary to open
up the appropriate port.
Execute the following to do so:

```bash
$ NODES="k8s-master-00 k8s-master-01 k8s-master-02 k8s-worker-00 k8s-worker-01 k8s-worker-02 k8s-worker-03 k8s-worker-04 k8s-worker-10 k8s-worker-11"
$ USER=jarvice
$ CMD="sudo firewall-cmd --permanent --add-port=6784/tcp; sudo systemctl restart firewalld"
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

### Add master nodes

Now add the additional kubernetes master nodes to the cluster using the
`kubeadm join` command that was copied when
[saving the join commands](#saving-the-join-commands).
Execute the master node join command on each master node being
added to the cluster (make sure to use `sudo`):
```bash
$ sudo kubeadm join k8s-master:6443 --token y8ilih.syk2g16evujwtzx4 \
    --discovery-token-ca-cert-hash sha256:08fae14ad35691a5af851648d57c0c1413048023a94657401262989aa532ac1c \
    --control-plane \
    --certificate-key 44bb1cfcf55ed8e343aa76765d4e4057d524fcacc453d6f18dc4881856f59da6
```

Alternatively, it may be more efficient to add the nodes via ssh.
(Assuming that `USER` has password-less, `!requiretty` sudo access):
```bash
$ NODES="k8s-master-01 k8s-master-02"
$ USER=jarvice
$ CMD=$(cat <<EOF
sudo kubeadm join k8s-master:6443 --token y8ilih.syk2g16evujwtzx4 \
    --discovery-token-ca-cert-hash sha256:08fae14ad35691a5af851648d57c0c1413048023a94657401262989aa532ac1c \
    --control-plane \
    --certificate-key 44bb1cfcf55ed8e343aa76765d4e4057d524fcacc453d6f18dc4881856f59da6
EOF
)
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

#### Verify nodes

From a `kubectl` client machine, verify that the nodes have been added
and are in the `Ready` state:
```bash
$ kubectl get nodes
```

### Add worker nodes

Now add the kubernetes worker nodes to the cluster using the
`kubeadm join` command that was copied when
[saving the join commands](#saving-the-join-commands).
Execute the worker node join command on each worker node being
added to the cluster (make sure to use `sudo`):
```bash
$ sudo kubeadm join k8s-master:6443 --token y8ilih.syk2g16evujwtzx4 \
    --discovery-token-ca-cert-hash sha256:08fae14ad35691a5af851648d57c0c1413048023a94657401262989aa532ac1c
```

Alternatively, it may be more efficient to add the nodes via ssh.
(Assuming that `USER` has password-less, `!requiretty` sudo access):
```bash
$ NODES="k8s-worker-00 k8s-worker-01 k8s-worker-02 k8s-worker-03 k8s-worker-04 k8s-worker-10 k8s-worker-11"
$ USER=jarvice
$ CMD=$(cat <<EOF
sudo kubeadm join k8s-master:6443 --token y8ilih.syk2g16evujwtzx4 \
    --discovery-token-ca-cert-hash sha256:08fae14ad35691a5af851648d57c0c1413048023a94657401262989aa532ac1c
EOF
)
$ for n in $NODES; do ssh $USER@$n "$CMD"; done
```

#### Verify nodes

From a `kubectl` client machine, verify that the nodes have been added
and are in the `Ready` state:
```bash
$ kubectl get nodes
```

### Label and taint kubernetes worker nodes

Now that all of the nodes have been added to the cluster, we need to label
and taint them.  This can be done from the client machine which was
set up to access the cluster with `kubectl`.

#### Add node labels

Label the `jarvice-system` nodes.  If you do not wish to delegate a
specific node for JARVICE application builds, add `k8s-worker-04` to the
node list:
```bash
$ NODES="k8s-worker-00 k8s-worker-01 k8s-worker-02 k8s-worker-03"
$ kubectl label nodes $NODES node-role.jarvice.io/jarvice-system=true
$ kubectl label nodes $NODES node-role.kubernetes.io/jarvice-system=true
```

If you will be designating a specific `jarvice-dockerbuild` node:
```bash
$ NODES="k8s-worker-04"
$ kubectl label nodes $NODES node-role.jarvice.io/jarvice-dockerbuild=true
$ kubectl label nodes $NODES node-role.kubernetes.io/jarvice-dockerbuild=true
```

Label the `jarvice-compute` nodes:
```bash
$ NODES="k8s-worker-10 k8s-worker-11"
$ kubectl label nodes $NODES node-role.jarvice.io/jarvice-compute=true
$ kubectl label nodes $NODES node-role.kubernetes.io/jarvice-compute=true
```

##### Verify node labels

From a `kubectl` client machine, verify that the nodes are labeled with the
correct roles:
```bash
$ kubectl get nodes
```

#### Add node taints

Taint the `jarvice-system` nodes:
```bash
$ kubectl taint nodes -l node-role.jarvice.io/jarvice-system=true \
    node-role.jarvice.io/jarvice-system=true:NoSchedule
```

Taint the `jarvice-dockerbuild` nodes:
```bash
$ kubectl taint nodes -l node-role.jarvice.io/jarvice-dockerbuild=true \
    node-role.jarvice.io/jarvice-dockerbuild=true:NoSchedule
```

Taint the `jarvice-compute` nodes:
```bash
$ kubectl taint nodes -l node-role.jarvice.io/jarvice-compute=true \
    node-role.jarvice.io/jarvice-compute=true:NoSchedule
```

------------------------------------------------------------------------------

## Enable External Access to Cluster Applications

### Install helm package manager

The next steps require that the [helm package manager](https://helm.sh/) be
installed.

The `install-helm` script can be used to install `helm` onto a `kubectl`
client machine which will be used to access the kubernetes cluster.

Simply execute the following to use the script to install `helm` onto
the machine you wish to access the cluster from:
```bash
$ ./jarvice-helm/scripts/install-helm
```

The script will install the `helm` binary and initialize the `helm`
repositories.

### Kubernetes load balancer

A load balancer is required for making the JARVICE services and jobs
externally available/accessible from outside of the kubernetes cluster.
[MetalLB](https://metallb.universe.tf/) is the recommended load balancer
solution.

The `deploy2k8s-metallb` script can be used to deploy and configure it
for the kubernetes cluster.
Execute `./jarvice-helm/scripts/deploy2k8s-metallb --help` to see it's usage.

For our example cluster, execute the following from the client machine which
has `helm` and `kubectl` installed:
```bash
$ ./jarvice-helm/scripts/deploy2k8s-metallb --addresses 10.20.0.1-10.20.0.2
```

As mentioned in the
[IP address range or subnet for accessing JARVICE](#ip-address-range-or-subnet-for-accessing-jarvice)
section of this document,
be sure to replace the `--addresses` value with the proper value for your
cluster.

### Kubernetes ingress controller

An ingress controller is required for making the JARVICE portal, JARVICE API
endpoint, and JARVICE jobs available and accessible from outside of
the kubernetes cluster via DNS host names.
[Traefik](https://traefik.io/) is the ingress controller solution that is
supported by JARVICE.

The `deploy2k8s-traefik` script can be used to deploy and configure 
[Traefik](https://traefik.io/) for the kubernetes cluster.
Execute `./jarvice-helm/scripts/deploy2k8s-traefik --help` to see it's usage.

For our example cluster, execute the following from the client machine which
has `helm` and `kubectl` installed:
```bash
$ ./jarvice-helm/scripts/deploy2k8s-traefik --load-balancer-ip 10.20.0.1 \
    --default-cert-file my-domain.com.pem \
    --default-key-file my-domain.com.key
```

The above command uses an IP address from the range configured during the
[kubernetes load balancer](#kubernetes-load-balancer) deployment.
Be sure to replace the `--load-balancer-ip` value with the proper value for
your cluster.

------------------------------------------------------------------------------

## Deploy JARVICE

You are now ready to deploy JARVICE into the newly installed kubernetes
cluster.  See the [JARVICE cloud platform](README.md#jarvice-cloud-platform)
documentation for more details on deploying JARVICE.
Note that many of the prerequisites outlined in that document were already
resolved during the kubernetes cluster installation outlined in this document.

------------------------------------------------------------------------------

## Scaling Up the Kubernetes Cluster

Eventually, it may become necessary to scale up JARVICE by adding more
nodes to the kubernetes cluster.  In order to do so, on each new node,
you must first install
[docker and kubeadm](#docker-and-kubeadm) as outlined in the
[Node Software Installation](#node-software-installation) section of this
document before continuing here.

### Adding kubernetes worker nodes

In order to add additional kubernetes worker nodes for `jarvice-system`,
`jarvice-compute`, or `jarvice-dockerbuild` roles,
execute the following on one of the master nodes in the kubernetes cluster.
This will create a new join token and print out the join command to use
for joining new worker nodes:
```bash
$ sudo kubeadm token create --print-join-command
```

After using the join command to join each new worker node to the cluster,
[label and taint the kubernetes worker nodes](#label-and-taint-kubernetes-worker-nodes)
per their desired node roles.

#### Verify nodes

From a `kubectl` client machine, verify that the node(s) have been added,
are in the `Ready` state, and are labeled with the correct node role(s):
```bash
$ kubectl get nodes
```

### Adding kubernetes master nodes

In order to add additional kubernetes master nodes,
execute the following on one of the master nodes in the kubernetes cluster.
This will create a new join token, make sure master certificates are uploaded
into the cluster, and print out the join command to use for joining
new master nodes:
```bash
$ echo "sudo $(sudo kubeadm token create --print-join-command) --control-plane --certificate-key $(sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -n 1)"
```

After using the join command to join each new master node to the cluster,
it will only be necessary to verify that the new nodes have been added to the
cluster.

#### Verify nodes

From a `kubectl` client machine, verify that the nodes have been added
and are in the `Ready` state:
```bash
$ kubectl get nodes
```

------------------------------------------------------------------------------

## Upgrading the Kubernetes Cluster

### Prerequisites for cluster upgrade

#### Package repository

The upgrade scripts referred to in this documentation assume that access to
the `kubeadm` package repository is already configured on each cluster node.
If the installation procedure in this documentation was followed, that
repository is already set up on the nodes.

#### User with `sudo` access

It is also assumed that a user with `sudo` access already exists on each of
the nodes.  See [access to cluster nodes](#access-to-cluster-nodes) for more
information.

#### SSH access from a `kubectl` client machine

The `upgrade-kubeadm-cluster` script also assumes that the cluster
node names match a DNS resolvable network host name that is directly
accessible, via SSH, from the `kubectl` client machine that the script will
be executed on.

It is recommended that SSH keys are copied to the cluster nodes for the SSH
user that has `sudo` access on each of those nodes.  That user will be used
by the upgrade scripts.  SSH keys can be copied to the nodes with commands
similar to the following:
```bash
$ NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
$ USER=jarvice
$ for n in $NODES; do ssh-copy-id $USER@$n; done
```

### Review kubernetes documentation

Before beginning any upgrade of your cluster, be sure to review
the official kubernetes documentation for
[upgrading kubeadm clusters](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/).

### Upgrade scripts

#### `upgrade-kubeadm-cluster`

This is the master script that should be used to upgrade the entire
`kubeadm` cluster.  It will copy and execute the `upgrade-kubeadm` and
`upgrade-kubelet` scripts onto the master and worker nodes in the appropriate
order.

If you are not able to execute `upgrade-kubeadm-cluster` from a host that has
direct access to the cluster nodes, it will be necessary to manually copy
`upgrade-kubeadm` and `upgrade-kubelet` to the nodes to execute them.

Execute `upgrade-kubeadm-cluster` with the `--help` flag to see it's usage:

```bash
Usage:
    ./scripts/upgrade-kubeadm-cluster [options]

Options:
    --minor         Upgrade to the next minor release.
                    (e.g. 1.15->1.16, 1.16->1.17, 1.17->1.18, etc.)
    --patch         Upgrade to the latest patch release.
                    (e.g. 1.17.x->1.17.y, 1.18.x->1.18.y, etc.)
    --no-dry-run    Do not execute in dry run mode.  Apply package upgrades
                    and/or configuration updates.  (Dry run is default mode.)
    --yes           Skip all continuation prompts.  Auto answer yes.
    --ssh-user      SSH user which will run upgrade on cluster nodes.
    --master-nodes  Only upgrade master nodes, skip worker nodes.
                    (Use to continue previously interrupted upgrade process)
    --worker-nodes  Only upgrade worker nodes, skip master nodes.
                    (Use to continue previously interrupted upgrade process)

Example (dry run, check upgrade of installed 1.x to latest 1.x.y patch version):
    ./scripts/upgrade-kubeadm-cluster --patch --ssh-user jarvice --yes

Example (non-dry run, perform a full cluster upgrade from 1.x.y to 1.x+1.y):
    ./scripts/upgrade-kubeadm-cluster --minor --ssh-user jarvice --no-dry-run

If a previous cluster upgrade was interrupted, it will be necessary to use
--master-nodes and/or --worker-nodes to continue where the upgrade left off.

Example (non-dry run, upgrade remaining master nodes):
    ./scripts/upgrade-kubeadm-cluster --minor --ssh-user jarvice --no-dry-run \
            --master-nodes k8s-master-01 k8s-master-02

Example (non-dry run, upgrade all worker nodes):
    ./scripts/upgrade-kubeadm-cluster --minor --ssh-user jarvice --no-dry-run \
            --worker-nodes

Example (non-dry run, upgrade remaining worker nodes):
    ./scripts/upgrade-kubeadm-cluster --minor --ssh-user jarvice --no-dry-run \
            --worker-nodes k8s-worker-08 k8s-worker-09 k8s-worker-10

Review the kubeadm cluster upgrade documentation prior to beginning upgrade:
https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
```

#### `upgrade-kubeadm`

If not utilizing `upgrade-kubeadm-cluster`, this script will need to be run
with the `--first` flag on the first master node before being executed on
the remaining master nodes with `--additional`.

Be sure that `upgrade-kubeadm` **and** `upgrade-kubelet` have been executed on
all of the master nodes before executing this script on the worker nodes.

Execute `upgrade-kubeadm` with the `--help` flag to see it's usage:

```bash
Usage:
    ./scripts/upgrade-kubeadm [options]

Options:
    --minor         Upgrade to the next minor release.
                    (e.g. 1.15->1.16, 1.16->1.17, 1.17->1.18, etc.)
    --patch         Upgrade to the latest patch release.
                    (e.g. 1.17.x->1.17.y, 1.18.x->1.18.y, etc.)
    --no-dry-run    Do not execute in dry run mode.  Apply package upgrades
                    and/or configuration updates.  (Dry run is default mode.)
    --yes           Skip all continuation prompts.  Auto answer yes.
    --first         First master control plane node.  Apply new version.
    --additional    Additional master control plane node.  Upgrade node.

Example:
    ./scripts/upgrade-kubeadm --patch --first

Review the kubeadm cluster upgrade documentation prior to beginning upgrade:
https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
```

#### `upgrade-kubelet`

If not utilizing `upgrade-kubeadm-cluster`, this script will need to be run
on each cluster node **after** `upgrade-kubeadm` has been executed on them.

Note that it should only be run on each master node after `upgrade-kubeadm`
has been executed on **all** of the master nodes.

Execute `upgrade-kubelet` with the `--help` flag to see it's usage:

```bash
Usage:
    ./scripts/upgrade-kubelet [options]

Options:
    --minor         Upgrade to the next minor release.
                    (e.g. 1.15->1.16, 1.16->1.17, 1.17->1.18, etc.)
    --patch         Upgrade to the latest patch release.
                    (e.g. 1.17.x->1.17.y, 1.18.x->1.18.y, etc.)
    --no-dry-run    Do not execute in dry run mode.  Apply package upgrades
                    and/or configuration updates.  (Dry run is default mode.)
    --yes           Skip all continuation prompts.  Auto answer yes.

Example:
    ./scripts/upgrade-kubelet --patch

Review the kubeadm cluster upgrade documentation prior to beginning upgrade:
https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
```

------------------------------------------------------------------------------

## Additional Resources

- [JARVICE cloud platform](README.md)

