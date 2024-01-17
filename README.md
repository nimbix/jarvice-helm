# JARVICE XE Hybrid Cloud HPC platform

This is the Helm chart for installation of JARVICE into a kubernetes cluster.
The chart's git repository can be cloned with the following command:

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

------------------------------------------------------------------------------

## Table of Contents

* [Prerequisites for JARVICE Installation](#prerequisites-for-jarvice-installation)
    - [Kubernetes cluster](#kubernetes-cluster)
    - [Helm package manager for kubernetes](#helm-package-manager-for-kubernetes-httpshelmsh)
    - [Configure kubernetes CPU management policies](#configure-kubernetes-cpu-management-policies)
    - [Kubernetes network plugin](#kubernetes-network-plugin)
    - [Kubernetes load balancer](#kubernetes-load-balancer)
    - [Kubernetes ingress controller](#kubernetes-ingress-controller)
        - [Ingress controller installation](#ingress-controller-installation)
    - [Kubernetes device plugins](#kubernetes-device-plugins)
    - [Kubernetes persistent volumes (for non-demo installation)](#kubernetes-persistent-volumes-for-non-demo-installation)
    - [JARVICE license and credentials](#jarvice-license-and-credentials)
    - [Add CA root for JARVICE (optional)](#add-ca-root-for-jarvice-optional)
* [Installation Recommendations](#installation-recommendations)
    - [Kubernetes Cluster Shaping](#kubernetes-cluster-shaping)
        - [Node labels and selectors](#node-labels-and-selectors)
        - [Node label for jarvice-dockerbuild](#node-label-for-jarvice-dockerbuild)
        - [Utilizing jarvice-compute labels](#utilizing-jarvice-compute-labels)
        - [Node taints and pod tolerations](#node-taints-and-pod-tolerations)
        - [jarvice-compute taints and pod tolerations](#jarvice-compute-taints-and-pod-tolerations)
* [JARVICE Quick Installation (Demo without persistence)](#jarvice-quick-installation-demo-without-persistence)
    - [Find the latest JARVICE helm chart release version](#find-the-latest-jarvice-helm-chart-release-version)
    - [Code repository of the JARVICE helm chart](#code-repository-of-the-jarvice-helm-chart)
    - [Quick install command with helm](#quick-install-command-with-helm)
    - [Deployment to managed kubernetes services with `terraform`](#deployment-to-managed-kubernetes-services-with-terraform)
* [JARVICE Standard Installation](#jarvice-standard-installation)
    - [Persistent volumes](#persistent-volumes)
    - [Using a load balancer for jobs](#using-a-load-balancer-for-jobs)
        - [Selecting external, load balancer IP addresses](#selecting-external-load-balancer-ip-addresses)
        - [Possible settings for `jarvice.JARVICE_JOBS_LB_SERVICE`](#possible-settings-for-jarvicejarvice_jobs_lb_service)
        - [Additional LoadBalancer service annotation for jobs](#additional-loadbalancer-service-annotation-for-jobs)
        - [Example: using an internal LoadBalancer on AWS](#example-using-an-internal-loadbalancer-on-aws)
    - [Using an Ingress controller for jobs](#using-an-ingress-controller-for-jobs)
        - [Enable path based ingress](#enable-path-based-ingress)
        - [Additional Ingress annotation for jobs](#additional-ingress-annotation-for-jobs)
    - [PushToCompute (`jarvice-dockerbuild`) Configuration](#pushtocompute-jarvice-dockerbuild-configuration)
        - [Build cache](#build-cache)
            - [Garbage collection of build cache PVCs](#garbage-collection-of-build-cache-pvcs)
        - [Build nodes](#build-nodes)
    - [Site specific configuration](#site-specific-configuration)
        - [JARVICE helm deployment script](#jarvice-helm-deployment-script)
    - [Updating configuration (or upgrading to newer JARVICE chart version)](#updating-configuration-or-upgrading-to-newer-jarvice-chart-version)
    - [Non-JARVICE specific services](#non-jarvice-specific-services)
        - [MariaDB database (jarvice-db)](#mariadb-database-jarvice-db)
        - [Memcached (jarvice-memcached)](#memcached-jarvice-memcached)
        - [Docker registry proxy/cache (jarvice-registry-proxy)](#docker-registry-proxycache-jarvice-registry-proxy)
* [JARVICE Downstream Installation](#jarvice-downstream-installation)
    - [Upstream cluster settings](#upstream-cluster-settings)
* [JARVICE Configuration Values Reference](#jarvice-configuration-values-reference)
* [JARVICE Post Installation](#jarvice-post-installation)
    - [Install recommended DaemonSets](#install-recommended-daemonsets)
    - [Install a dynamic storage provisioner](#install-a-dynamic-storage-provisioner)
    - [Set up database backups](#set-up-database-backups)
    - [Customize JARVICE files via a ConfigMap](#customize-jarvice-files-via-a-configmap)
    - [Customize Keycloak login and email theme](#cutomize-keycloak-login-and-email-theme)
    - [View status of the installed kubernetes objects](#view-status-of-the-installed-kubernetes-objects)
    - [Retreive IP addresses for accessing JARVICE](#retreive-ip-addresses-for-accessing-jarvice)
    - [Deploy "EFK" Stack](#deploy-efk-stack)
* [Additional Resources](#additional-resources)

------------------------------------------------------------------------------

## Prerequisites for JARVICE Installation

### Kubernetes cluster

If you do not already have access to a kubernetes cluster and will not be
using a managed kubernetes cluster service (e.g. Amazon EKS on AWS or
Google GKE on GCP), it will be necessary to install your own cluster.
If you will be installing your own kubernetes cluster, please see the
[Kubernetes Cluster Installation](KubernetesInstall.md) documentation for
more information.

#### kubectl

Deploying JARVICE requires that the `kubectl` executable be installed on a
client machine which has access to a kubernetes cluster.
The `install-kubectl` shell script included in the `scripts`
directory of this git repository can be used to install `kubectl`.
Simply execute `./scripts/install-kubectl` to do so.

If the script does not support the client machine's operating system,
specific operating system instructions can be found here:
https://kubernetes.io/docs/tasks/tools/install-kubectl/

### Helm package manager for kubernetes (https://helm.sh/)

Deploying JARVICE requires that the `helm` executable be installed on a
client machine which has access to a kubernetes cluster.
The `install-helm` shell script included in the `scripts`
directory of this git repository can be used to install `helm`.
Simply execute `./scripts/install-helm` to do so.

If the script does not support the client machine's operating system,
specific operating system instructions can be found here:
https://github.com/helm/helm/releases

Please see the Helm Quickstart Guide for more details:
https://helm.sh/docs/intro/quickstart/

**Note:** The JARVICE helm chart requires helm version 3.2.0 or newer.

### Configure kubernetes CPU management policies

**WARNING:** `static` CPU policy, at the time of this writing, is known to
interfere with NVIDIA GPU operations in the container environment.  While
this setting can be used to more accurately implement "Guaranteed" QoS for
fractional node CPU allocation,
**it may not be stable enough for many usecases!**

If appropriate, `static` CPU policy can be set with the arguments given to a worker node's kublet on startup.  

The default CPU management policy is `none`.  If CPU management policy wasn't
set to `static` at JARVICE worker node install time, it will be necessary
to drain each worker node and remove the previous `cpu_manager_state` file
as a part of the process of restarting each worker node's kubelet.

The `config-kubelet-cpu-policy` shell script included in the `scripts`
directory of this helm chart can be used to set kubelet CPU management
policies on remote compute nodes that run Ubuntu.
Execute `config-kubelet-cpu-policy` with `--help` to see all of the current
command line options:
```bash
Usage:
    ./scripts/config-kubelet-cpu-policy [options]

Options:
    --ssh-user              SSH user with sudo access on nodes (required)
    --policy [static|none]  Set/unset static CPU manager policy (required)
    --nodes "<hostnames>"   Nodes to set policy on (optional)
                            (Default: all nodes labeled for jarvice-compute)
```

Please see the following link for for more information on kubernetes CPU
management policies:
https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/

### Kubernetes network plugin

Deploying a pod network plugin should only be necessary when
standing up a new kubernetes cluster.  If you are working with an already
existing cluster, a pod network plugin may already be deployed.  Contact
your kubernetes cluster administrator for more information.

If your cluster does not already have a pod network plugin deployed, see
[Deploy a pod network plugin/add-on](KubernetesInstall.md#deploy-a-pod-network-plugin-add-on)
section of the
[Kubernetes Cluster Installation](KubernetesInstall.md) documentation.

**NOTE:**  If running on a managed kubernetes service, such as Amazon EKS,
a network plugin has likely been set up for the cluster.

### Kubernetes load balancer

If running on a managed kubernetes service, such as Amazon EKS, a load balancer
has likely been set up for the cluster.  If running a private kubernetes
cluster, a load balancer is required for making the JARVICE services and jobs
externally available/accessible from outside of the kubernetes cluster.

If your cluster does not already have a load balancer deployed, see the
[Kubernetes load balancer](KubernetesInstall.md#kubernetes-load-balancer)
section of the
[Kubernetes Cluster Installation](KubernetesInstall.md) documentation.

### Kubernetes ingress controller

An ingress controller is required for making the JARVICE services and jobs
available and accessible from outside of the kubernetes cluster via
DNS host names.
[Traefik](https://traefik.io/) is the ingress controller solution that is
recommended for JARVICE.

For more information on using an ingress controller with JARVICE, please review
[Using an Ingress controller for jobs](#using-an-ingress-controller-for-jobs)
and [Ingress Patterns and Configuration](Ingress.md).

#### Ingress controller installation

If your cluster does not already have an ingress controller deployed, see the
[Kubernetes ingress controller](KubernetesInstall.md#kubernetes-ingress-controller)
section of the
[Kubernetes Cluster Installation](KubernetesInstall.md) documentation.

If a more complex configuration is needed for your cluster,
it will be necessary to adjust the `deploy2k8s-traefik` script included in
the `jarvice-helm` git repository or execute `helm` manually.
Please visit https://traefik.github.io/traefik-helm-chart/ and/or
execute the following to get more details on Traefik configuration and
installation via helm:
```bash
$ helm inspect all traefik --repo https://helm.traefik.io/traefik
```

**Note:** If not using a `NodePort` service for `traefik`, it will be
necessary to have a valid `loadBalancerIP` which is accessible via DNS
lookups.  In that case, the site domain's DNS settings will need
to allow wildcard lookups so that the ingress controller can use random host
names for routing JARVICE jobs.  A JARVICE job hostname will look similar to
`jarvice-system-jobs-80.<domain>`.

The full details of a site specific Traefik deployment are beyond the scope of
this document.  Please start here for more in depth information on Traefik:
https://github.com/containous/traefik

### Kubernetes device plugins

#### NVIDIA device plugin

If the cluster nodes have NVIDIA GPU devices installed, it will be necessary
to install the NVIDIA device plugin and it's
[prerequisites](https://github.com/NVIDIA/k8s-device-plugin#prerequisites)
in order for JARVICE to make use of them.

This helm chart includes a DaemonSet which can be used to install and
configure the NVIDIA dervice driver and it's prerequisites.
In order to enable the NVIDIA installation DaemonSet provided in this helm
chart, add the following `--set` flag to the helm install/upgrade command:
```bash
--set jarvice.daemonsets.nvidia_install.enabled="true"
```

In order to enable the NVIDIA device plugin DaemonSet provided in this helm
chart, add the following `--set` flag to the helm install/upgrade command:
```bash
--set jarvice.daemonsets.nvidia.enabled="true"
```

For further details on the NVIDIA device plugin,
please see the following link:
https://github.com/NVIDIA/k8s-device-plugin

#### RDMA device plugin

If the cluster nodes have RDMA capable devices installed, it will be necessary
to install the device plugin in order for JARVICE to make use of them.

In order to enable the RDMA device plugin DaemonSet provided in this helm
chart, add the following `--set` flag to the helm install/upgrade command:
```bash
--set jarvice.daemonsets.rdma.enabled="true"
```

Please see the following link for plugin details:
https://github.com/nimbix/k8s-rdma-device-plugin

### Kubernetes persistent volumes (for non-demo installation)

For those sites that do not wish to separately install/maintain a MariaDB
database, this helm chart provides an installation
via the `jarvice-db` deployments/services.  If you wish
to use `jarvice-db` as is provided from this helm chart,
persistent volumes will be required for the kubernetes cluster in order to
maintain state for the JARVICE database and applications registry.  This will
be addressed below, but the full details on the setup and management of
persistent volumes in kubernetes is beyond the scope of this document.

Please see the kubernetes documentation for more details:
https://kubernetes.io/docs/concepts/storage/persistent-volumes/

### JARVICE license and credentials

A JARVICE license and container registry credentials will need to be obtained
from Nimbix sales (`sales@nimbix.net`) and/or support (`support@nimbix.net`).
The license and credentials will be used for the following settings:

    - jarvice.imagePullSecret=<jarvice_base64_encoded_registry_creds>
    - jarvice.JARVICE_LICENSE_LIC=<jarvice_license_key>
    - jarvice.JARVICE_REMOTE_USER=<jarvice_upstream_user>
    - jarvice.JARVICE_REMOTE_APIKEY=<jarvice_upstream_user_apikey>

See the commands below for more detail on how to set and use these values.

### Add CA root for JARVICE (optional)

A CA root can be added to JARVICE to enable trust between internal services,
such as a private container registry, using the following steps:

```bash
# create configmap of CA root
# this example uses /etc/ssl/certs/ca-certificates.crt from the local client
# replace with the desired CA root if needed
kubectl -n jarvice-system create configmap jarvice-cacert --from-file=/etc/ssl/certs/ca-certificates.crt
kubectl -n jarvice-system-jobs create configmap jarvice-cacert --from-file=/etc/ssl/certs/ca-certificates.crt
kubectl -n jarvice-system-pulls create configmap jarvice-cacert --from-file=/etc/ssl/certs/ca-certificates.crt
kubectl -n jarvice-system-builds create configmap jarvice-cacert --from-file=/etc/ssl/certs/ca-certificates.crt
```

Update `jarvice.cacert.configMap` in `values.yaml` (uncomment `# jarvice-cacert`)

------------------------------------------------------------------------------

## Installation Recommendations

### Kubernetes Cluster Shaping

At the highest level, JARVICE utilizes pods which can be thought of as
encompassing two essential types.  The first of which, `jarvice-system`, are
used for running the JARVICE platform itself.  The second type,
`jarvice-compute`, are used for running JARVICE application jobs.

The `jarvice-system` pods could be broken down further into two basic types.
The base `jarvice-system` pods contain components related to the web portal,
API endpoints, Data Abstraction Layer (DAL), etc.  In addition,
there are other non-JARVICE installed/controlled components.  These other
components, such as ingress controllers, can be thought of as the
`jarvice-other` type as they live outside of the JARVICE namespaces.

In order to get the best performance out of JARVICE, it will be necessary to
categorize nodes and separate pod types to prevent overlap.  e.g.  Mixing
`jarvice-system` pods with `jarvice-compute` pods could affect performance
when running JARVICE applications.

As such, it may be beneficial to pre-plan and determine how to manage the
various JARVICE components on kubernetes cluster nodes.  It is recommended
that a kubernetes cluster running JARVICE utilize kubernetes node
labels/selectors and node taints/tolerations to "shape" which pods do and
do not run on particular nodes.

#### Node labels and selectors

The following example commands show how one may label kubernetes nodes so
that JARVICE can assign pods to them with node selectors:
```bash
$ kubectl label nodes <node_name> node-role.jarvice.io/jarvice-system=true
$ kubectl label nodes <node_name> node-role.kubernetes.io/jarvice-system=true
```

Once the kubernetes nodes are labeled, the JARVICE helm chart can direct pod
types to specific nodes by utilizing node affinity and/or selectors.  The
JARVICE helm chart provides node affinity and selector settings which can be
applied to all of the `jarvice-system` components (`jarvice.nodeAffinity` and
`jarvice.nodeSelector`), as well as node affinity/selectors for each
individual JARVICE component.  These can be set in a
configuration values `override.yaml` file or on the `helm` command line.

Note that node affinity/selectors are specified using JSON syntax.  When using
`--set` on the `helm` command line, special characters must be escaped.  Also,
individual component node selectors are not additive.  They will override
`jarvice.nodeAffinity` and/or `jarvice.nodeSelector` if they are set.

For example, if both `jarvice.nodeSelector` and
`jarvice_dockerbuild.nodeSelector` are specified on the `helm` command line:
```bash
--set-string jarvice.nodeSelector="\{\"node-role.jarvice.io/jarvice-system\": \"true\"\}"
--set-string jarvice_dockerbuild.nodeSelector="\{\"node-role.jarvice.io/jarvice-dockerbuild\": \"true\"\}"
```

In the example above,
`node-role.jarvice.io/jarvice-system` will not be
applied to `jarvice_dockerbuild.nodeSelector`.  In the case that both node
selectors are desired for `jarvice_dockerbuild.nodeSelector`, use:
```bash
--set-string jarvice_dockerbuild.nodeSelector="\{\"node-role.jarvice.io/jarvice-system\": \"true\"\, \"node-role.jarvice.io/jarvice-dockerbuild\": \"true\"\}"
```

For more information on assigning kubernetes node labels and using node
affinity and/or selectors, please see the kubernetes documentation:
https://kubernetes.io/docs/concepts/configuration/assign-pod-node/

##### Node label for `jarvice-dockerbuild`

In some instances, mostly for performance reasons related to CPU and/or disk
speed, it may be advantageous to label a node in
the kubernetes cluster for dockerbuild operations specifically.
Use a command similar to the following to do so:
```bash
$ kubectl label nodes <node_name> node-role.jarvice.io/jarvice-dockerbuild=true
```

To take advantage of such a setup, set `jarvice_dockerbuild.nodeAffinity` or
`jarvice_dockerbuild.nodeSelector` in the JARVICE helm chart.

See the
[PushToCompute (`jarvice-dockerbuild`) Configuration](#pushtocompute-jarvice-dockerbuild-configuration)
section below for more details.

##### Utilizing `jarvice-compute` labels

The following demonstrates how one might label nodes for `jarvice-compute`
pods:
```bash
$ kubectl label nodes <node_name> node-role.jarvice.io/jarvice-compute=true
$ kubectl label nodes <node_name> node-role.kubernetes.io/jarvice-compute=true
```

After setting the `jarvice-compute` labels, it will be necessary to add a
matching `node-role.jarvice.io/jarvice-compute=true` string to the `properties`
field of the machine definitions found in the JARVICE console's
"Administration" tab.  This string will be used as a kubernetes node selector
when the JARVICE scheduler assignings jobs.

Please see the [JARVICE System Configuration Notes](Configuration.md) for more
information.

#### Node taints and pod tolerations

Kubernetes node taints can be used to provide an effect opposite to that of
nodes affinity and/or selectors.  That is, they are used to "repel" pod types
from nodes.
For example, a node marked with a `jarvice-compute` label for sending jobs to
it with a node selector could also have a `jarvice-compute` taint in order to
keep non `jarvice-compute` pods from running on it.  This would be the best
practice for isolating `jarvice-compute` application job pods.

This JARVICE helm chart utilizes tolerations settings which are applied to all
of the JARVICE components (`jarvice.tolerations`), as well as tolerations for
each individual JARVICE component.  These can be set in a values
`override.yaml` file or on the `helm` command line.

By default `jarvice.tolerations` tolerates the `NoSchedule` effect for the
keys `node-role.jarvice.io/jarvice-system` and
`node-role.kubernetes.io/jarvice-system`.  A `kubectl` command line
similar to the following could be used to taint nodes already labeled
with `node-role.jarvice.io/jarvice-system`:
```bash
$ kubectl taint nodes -l node-role.jarvice.io/jarvice-system=true \
    node-role.jarvice.io/jarvice-system=true:NoSchedule
```

This is a quick and dirty way to list node taints after adding them:
```bash
$ kubectl get nodes -o json | \
    jq -r '.items[] | select(.spec.taints!=null) | .metadata.name + ": " + (.spec.taints[] | join("|"))'
```

The following example shows how `--set` flags on the helm install/upgrade
command line could be used to override the default tolerations for the
`jarvice-api` component:
```bash
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
    --set jarvice_api.tolerations[0].effect=NoSchedule \
    --set jarvice_api.tolerations[0].key=node-role.jarvice.io/jarvice-system \
    --set jarvice_api.tolerations[0].operator=Exists \
    --set jarvice_api.tolerations[1].effect=NoSchedule \
    --set jarvice_api.tolerations[1].key=node-role.jarvice.io/jarvice-api \
    --set jarvice_api.tolerations[1].operator=Exists
    ...
```

For more information on assigning kubernetes taints and tolerations,
please see the kubernetes documentation:
https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/

#### `jarvice-compute` taints and pod tolerations

The following would taint `jarvice-compute` nodes which are already labeled
with `node-role.jarvice.io/jarvice-compute`:
```bash
$ kubectl taint nodes -l node-role.jarvice.io/jarvice-compute=true \
    node-role.jarvice.io/jarvice-compute=true:NoSchedule
```

By default, the JARVICE job scheduler creates job pods that tolerate the
`NoSchedule` effect on nodes with the `node-role.jarvice.io/jarvice-compute`
and `node-role.kubernetes.io/jarvice-compute` taints.  This is currently not
configurable.
Tolerations for `jarvice-compute` will be made configurable in future
releases of JARVICE.

------------------------------------------------------------------------------

## JARVICE Quick Installation (Demo without persistence)

The installation commands outlined in this documentation assume that the
commands are being run on a client machine
that has access to the kubernetes cluster and has `kubectl` and `helm`
installed as mentioned in the installation prerequisites above.

### Find the latest JARVICE helm chart release version

The preferred method of deployment is to use the JARVICE helm chart repository
located at [https://nimbix.github.io/jarvice-helm/](https://nimbix.github.io/jarvice-helm/).
The latest JARVICE helm chart release versions can be found on the
[Releases](https://github.com/nimbix/jarvice-helm/releases) page.
See the [ChangeLog](ReleaseNotes.md#changelog) section of the
[JARVICE Release Notes](ReleaseNotes.md) to view more detailed information
on each release.

### Code repository of the JARVICE helm chart

If running in an air-gapped environment, or otherwise wishing to deploy via
a local directory instead of the remote
[JARVICE helm repository](https://nimbix.github.io/jarvice-helm/), it will
first be necessary to download the desired release from the JARVICE helm
[Releases](https://github.com/nimbix/jarvice-helm/releases) page or
clone this git repository.

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

After cloning the helm repository, checkout the tag corresponding to the
desired deployment version:
```bash
$ git checkout 3.0.0-1.XXXXXXXXXXXX
```

### Quick install command with helm

JARVICE can be quickly installed from the remote helm repository via the
following `helm` command:

```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice jarvice \
    --version 3.0.0-1.XXXXXXXXXXXX \
    --repo https://nimbix.github.io/jarvice-helm/ \
    --namespace jarvice-system --install \
    --set jarvice.imagePullSecret="$(echo "_json_key:$(cat jarvice-reg-creds.json)" | base64 -w 0)" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>"
```

Alternatively, in order to install and get the application catalog
synchronized, use the following `helm` command:
```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice jarvice \
    --version 3.0.0-1.XXXXXXXXXXXX \
    --repo https://nimbix.github.io/jarvice-helm/ \
    --namespace jarvice-system --install \
    --set jarvice.imagePullSecret="$(echo "_json_key:$(cat jarvice-reg-creds.json)" | base64 -w 0)" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>" \
    --set jarvice.JARVICE_REMOTE_USER="<jarvice_upstream_user>" \
    --set jarvice.JARVICE_REMOTE_APIKEY="<jarvice_upstream_user_apikey>"
```

**NOTE:** `jarvice.JARVICE_APPSYNC_USERONLY=true` can be set to only
synchronize application catalog items owned by the user set in
`jarvice.JARVICE_REMOTE_USER`; this is a simple way to restrict the
applications that get synchronized from the upstream service catalog.

### Deployment to managed kubernetes services with `terraform`

If a kubernetes cluster is not readily available, JARVICE can be quickly
deployed and demoed using kubernetes cluster services such as
Amazon EKS on AWS, Google GKE on GCP, or Microsoft AKS on Azure.
See the [JARVICE Deployment with Terraform](Terraform.md) documentation
for more details.

------------------------------------------------------------------------------

## JARVICE Standard Installation

### Persistent volumes

As mentioned in the installation requirements above, the JARVICE database
(`jarvice-db`) and the JARVICE application registry (`jarvice-registry`)
services require a that the kubernetes cluster have persistent volumes
configured for their use.

By default, the deployments of these services look for storage class names of
`jarvice-db` and `jarvice-registry` respectively.  These defaults can be
modified in the configuration values YAML or with `--set` on the `helm install`
command line.

It is recommended that the persistent volumes be set up before attempting the
helm installation.  The configuration of the persistent volumes can vary widely
from site to site and is thus beyond the scope of the helm installation.

The `jarvice-db-pv.yaml` and `jarvice-registry-pv.yaml` files are provided as
simple examples for setting up a persistent volumes which are backed by a NFS
server.  These can be found in the `jarvice-helm/extra` directory of this git
repository.  It is expected, however, that most sites may want/need a more
robust solution.

Please review the detailed kubernetes documentation for further information
on persistent volumes:
https://kubernetes.io/docs/concepts/storage/persistent-volumes/

Expanding upon the previous quick installation command, the following command
could then be used to install JARVICE with persistence enabled:
```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice jarvice \
    --version 3.0.0-1.XXXXXXXXXXXX \
    --repo https://nimbix.github.io/jarvice-helm/ \
    --namespace jarvice-system --install \
    --set jarvice.imagePullSecret="$(echo "_json_key:$(cat jarvice-reg-creds.json)" | base64 -w 0)" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>" \
    --set jarvice.JARVICE_REMOTE_USER="<jarvice_upstream_user>" \
    --set jarvice.JARVICE_REMOTE_APIKEY="<jarvice_upstream_user_apikey>" \
    --set jarvice_db.enabled=true \
    --set jarvice_db.persistence.enabled=true \
    --set jarvice_db.persistence.size=10Gi \
    --set jarvice_registry.enabled=true \
    --set jarvice_registry.persistence.enabled=true \
    --set jarvice_registry.persistence.size=1000Gi \
    --set jarvice.JARVICE_LOCAL_REGISTRY=jarvice-registry:443
```

By default, the standard install already has `jarvice_db.enabled=true` and
`jarvice_registry.enabled=false`.  Also, `jarvice.JARVICE_LOCAL_REGISTRY`
defaults to `docker.io`.

Also by default, persistence is disabled for `jarvice-db` and
`jarvice-registry`, so note that the persistence settings are required to
enable use of persistent volumes by the JARVICE helm chart.

If kubernetes persistent volumes were created which do no match the default
storage classes, it will be necessary to also `--set` the following values to
match the persistent volume storage classes that you wish to use:

- `jarvice_db.persistence.storageClass`
- `jarvice_registry.persistence.storageClass`

### Using a load balancer for jobs

If using a load balancer is desired, but not already deployed for the
kubernetes cluster, please review the documentation on deploying a
[kubernetes load balancer](KubernetesInstall.md#kubernetes-load-balancer).

#### Selecting external, load balancer IP addresses

By default, the load balancer installed for the target kubernetes cluster will
likely select random IP addresses from the IP range it was configured to use.
If specific IP addresses are desired from that range for external access to
JARVICE (e.g. to provide a consistent DNS name or the like), it will be
necessary to also `--set` the proper values to get the desired IP addresses.
(Contact the kubernetes cluster administrator to determine which IP addresses
are available.)  To direct the load balancer to allocate specific IP addresses
to the JARVICE services, here are the settings to use:

- `jarvice_mc_portal.loadBalancerIP`
- `jarvice_api.loadBalancerIP`

#### Possible settings for `jarvice.JARVICE_JOBS_LB_SERVICE`

Value|Behavior w/Ingress|Behavior w/out Ingress
---|---|---
`always` or `"true"`|All interactive jobs get (and wait for) a LoadBalancer service address before users can connect to them; do not use if there is no load balancer as this will cause jobs to queue indefinitely|This is the default behavior without Ingress
`never`|Jobs never request a LoadBalancer service address even if interactive and their AppDef or API submission requests one; use if there is no load balancer on the cluster to avoid certain jobs queuing indefinitely|This is setting is invalid without Ingress and should not be used
`"false"` (legacy/default)|Interactive jobs get (and wait for) a LoadBalancer service address if the application or job submission requests it; otherwise only Ingress is used|Ignored, as the default behavior is to request a LoadBalancer service address

#### Additional LoadBalancer service annotation for jobs

On some platforms/deployments, the LoadBalancer service type must be annotated
for it to properly assign an address.  The value for
`jarvice.JARVICE_JOBS_LB_ANNOTATIONS` should be set to a JSON dictionary of
name/value pairs as needed.

#### Example: using an internal LoadBalancer on AWS

Set the parameter `jarvice.JARVICE_JOBS_LB_ANNOTATIONS` to the following value:
```
'{"service.beta.kubernetes.io/aws-load-balancer-internal": "true"}'
```
(note the single quotes needed to properly encapsulate the JSON format)

See [https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html](https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html) for additional details.

Please note that this parameter is ignored when Ingress is used unless the
application specifically requests a LoadBalancer address via its configuration.

### Using an Ingress controller for jobs

By default, interactive JARVICE jobs request LoadBalancer addresses; to use
an Ingress controller, set the parameter `jarvice.JARVICE_JOBS_DOMAIN` to the
FQDN of the Ingress controller; JARVICE will create `*.${JARVICE_JOBS_DOMAIN}`
address for accessing interactive jobs over HTTPS.  To assign LoadBalancer
addresses even if Ingress is used, set `jarvice.JARVICE_JOBS_LB_SERVICE=always`,
in which case JARVICE will create both Ingress as well as LoadBalancer service
IPs for interactive jobs.

If using an ingress controller is desired, but not already deployed for the
kubernetes cluster, please review the documentation on deploying a
[kubernetes ingress controller](KubernetesInstall.md#kubernetes-ingress-controller).

#### Enable path based ingress

Set the parameter `jarvice.JARVICE_JOBS_DOMAIN` to the FQDN of the Ingress
controller and add the desired path for jobs to use terminated by `$`.

e.g. `JARVICE_JOBS_DOMAIN=my-domain.com/path/to/jobs$`

JARVICE will replace `$` with the job number to enable access to interactive
jobs over HTTPS.

#### Additional Ingress annotation for jobs

On some platforms/deployments, the Ingress for jobs may need to be annotated
for it to function properly.  The value for
`jarvice.JARVICE_JOBS_INGRESS_ANNOTATIONS` should be set to a JSON dictionary
of name/value pairs as needed.

**Note:**  When `jarvice.ingress.class` contains `nginx`, the
`nginx.org/websocket-services` annotation will automatically be set to the
value of the jobs' kubernetes Service.

**Note:**  Additional information on using ingress with JARVICE can be found
in the [Ingress Patterns and Configuration](Ingress.md) documentation.

### PushToCompute (`jarvice-dockerbuild`) Configuration

When deploying JARVICE to a managed kubernetes service with
[terraform](Terraform.md), `jarvice-dockerbuild` will be automatically
configured to use a build cache on persistent volume claims (PVCs)
with dedicated build nodes.  PVC garbage collection will also be automatically
configured.

If deploying JARVICE to an on-premises kubernetes cluster, a persistent build
cache and dedicated build nodes will not be enabled by default.  In this case,
it may be desirable to customize the configuration.

#### Build cache

When building applications with PushToCompute, successful builds will push
the build cache to the application's configured docker repository, but
failed builds will not.  Thus, the first configuration consideration
is whether or not to use a persistent build cache to speed up
application rebuilds when failures occur.  Using a persistent build cache may
not be necessary when building small applications, but it will likely provide
a benefit when doing large application builds.

To enable the use of a persistent build cache for application builds, set
`jarvice-dockerbuild.persistence.enabled` to `true` and then set
`jarvice-dockerbuild.persistence.storageClass` to the appropriate
`StorageClass` to use when requesting PVCs.  It will be necessary to
[install a dynamic storage provisioner](#install-a-dynamic-storage-provisioner)
on the cluster if one has not already been installed.

The size of the dynamically provisioned PVCs can be set with
`jarvice-dockerbuild.persistence.size`.  This defaults to `300Gi`.

##### Garbage collection of build cache PVCs

Build cache PVCs will not be automatically deleted unless
`jarvice_dockerbuild_pvc_gc.enabled` is set to `true`.  PVCs can be configured
to be kept for different amounts of time for successful, aborted, and failed
builds.  These values can be configured under the
`jarvice_dockerbuild_pvc_gc.env` settings:

```bash
  env:
    JARVICE_BUILD_PVC_KEEP_SUCCESSFUL: 3600  # Default: 3600 (1 hour)
    JARVICE_BUILD_PVC_KEEP_ABORTED: 7200  # Default: 7200 (2 hours)
    JARVICE_BUILD_PVC_KEEP_FAILED: 14400  # Default: 14400 (4 hours)
```

#### Build nodes

If persistence has not been enabled for applications builds, it may be
advantageous to run `jarvice-dockerbuild` pods on nodes with solid-state
drives (SSDs).  It may also be beneficial to run the `jarvice-dockerbuild`
pods on nodes with faster processors.  If either of these is desired,
see the above section on setting a
[node label for jarvice-dockerbuild](#node-label-for-jarvice-dockerbuild)
nodes.

### Site specific configuration

The easiest way to configure all of the JARVICE options is to copy the default
`values.yaml` file to `override.yaml`.  It can then be modified and used as
a part of the helm installation command:

```bash
$ cp jarvice-helm/values.yaml jarvice-helm/override.yaml
$ helm upgrade jarvice jarvice \
    --version 3.0.0-1.XXXXXXXXXXXX \
    --repo https://nimbix.github.io/jarvice-helm/ \
    --namespace jarvice-system --install \
    --values jarvice-helm/override.yaml
```

If deploying JARVICE from the remote helm repository, the corresponding
`values.yaml` file for the release version being deployed can be downloaded
with the following command:
```bash
$ version=3.0.0-1.XXXXXXXXXXXX
$ curl https://raw.githubusercontent.com/nimbix/jarvice-helm/$version/values.yaml >values.yaml
```

#### JARVICE helm deployment script

Alternatively, the simplified `deploy2k8s-jarvice` shell script can be used
to install/upgrade the JARVICE helm deployment.  The latest version can be
downloaded with `curl`:
```bash
$ curl https://raw.githubusercontent.com/nimbix/jarvice-helm/master/scripts/deploy2k8s-jarvice >deploy2k8s-jarvice
$ chmod 755 ./deploy2k8s-jarvice
```

If you have already cloned this helm chart git repository, the
`deploy2k8s-jarvice` can be found in the `scripts` directory.

Simply execute `deploy2k8s-jarvice` with the `--help` flag to see it's usage.

```bash
Usage:
    ./deploy2k8s-jarvice [options] -- [extra_helm_options]

Options:
    -r, --release <release>             Helm release name
                                        (Default: jarvice)
    -n, --namespace <kube_namespace>    Kubernetes namespace to deploy to
                                        (Default: jarvice-system)
    -f, --values <values_file>          Site specific values YAML file
                                        (Default: ./override.yaml)
    -r, --repo <helm_repo>              JARVICE helm repository
                                        (Default: https://nimbix.github.io/jarvice-helm/)
    -v, --version <jarvice_version>     JARVICE chart version from helm repo
                                        (Default: install via local chart dir)

Example deployment using remote JARVICE helm chart repository (preferred):
    ./deploy2k8s-jarvice -f ./override.yaml -v 3.0.0-1.XXXXXXXXXXXX

Example deployment using local JARVICE helm chart directory:
    ./deploy2k8s-jarvice -f ./override.yaml

Visit the JARVICE helm releases page for the latest release versions:
https://github.com/nimbix/jarvice-helm/releases

Available helm values for a released version can be found via:
curl https://raw.githubusercontent.com/nimbix/jarvice-helm/<jarvice_version>/values.yaml
```

### Updating configuration (or upgrading to newer JARVICE chart version)

The `helm upgrade` command can be used to tweak JARVICE after the initial
installation.  e.g. If it is necessary to increase the number of
replicas/pods for one of the JARVICE services.  The following example
command could be used to update the number of replicas/pods for the
JARVICE DAL deployment:

```bash
$ helm upgrade jarvice jarvice \
    --version 3.0.0-1.XXXXXXXXXXXX \
    --repo https://nimbix.github.io/jarvice-helm/ \
    --namespace jarvice-system --install \
    --reuse-values --set jarvice_dal.replicaCount=3
```

This could also be done from an `override.yaml` file:

```bash
$ helm upgrade jarvice jarvice \
    --version 3.0.0-1.XXXXXXXXXXXX \
    --repo https://nimbix.github.io/jarvice-helm/ \
    --namespace jarvice-system --install \
    --reuse-values --values jarvice-helm/override.yaml
```

### Non-JARVICE specific services

#### MariaDB database (`jarvice-db`)

If there is an already existing MariaDB installation that you wish to use with
JARVICE, it will be necessary to create an `override.yaml` file (shown above)
and edit the settings database settings (`JARVICE_DBHOST`, `JARVICE_DBUSER`,
`JARVICE_DBPASSWD`) in the base `jarvice` configuration stanza.

If there is not an existing MariaDB installation, but wish to maintain the
database in kubernetes, but outside of the JARVICE helm chart, execute the
following to get more details on using helm to perform the installation:
```bash
$ helm inspect all mariadb --repo https://charts.bitnami.com/bitnami
```

When using a database outside of the JARVICE helm chart, it will be necessary
to disable it in the JARVICE helm chart.  This can be done either in an
`override.yaml` file or via the command line with:

`--set jarvice_db.enabled=false`

Note that the MariaDB installation will require a database named `nimbix`.
If session management is desired for `jarvice-mc-portal` a database named
`nimbix_portal` is also required along with a `memcached` installation.

#### Memcached (`jarvice-memcached`)

If there is an already existing Memcached installation that you wish to use
with JARVICE, it will be necessary to create an `override.yaml` file (shown
above) and edit the `JARVICE_PORTAL_MEMCACHED_LOCATIONS` setting in the
`jarvice_mc_portal` `env` stanza.

If there is not an existing Memcached installation, but wish to maintain the
one in kubernetes, but outside of the JARVICE helm chart, execute the
following to get more details on using helm to perform the installation:
```bash
$ helm inspect all memcached --repo https://charts.bitnami.com/bitnami
```

When using Memcached outside of the JARVICE helm chart, it will be necessary
to disable it in the JARVICE helm chart.  This can be done either in an
`override.yaml` file or via the command line with:

`--set jarvice_memcached.enabled=false`

#### Docker registry proxy/cache (`jarvice-registry-proxy`)

It may be desirable to enable the docker registry proxy cache available in
the helm chart to reduce docker image pull times and network downloads for
JARVICE system, JARVICE application, and DaemonSet containers.
In order to enable the registry proxy/cache, it will be necessary to set
`jarvice_registry_proxy.enabled` to `true`.  The registry proxy runs as a
`NodePort` service which uses port `32443` on all of the `jarvice-system` and
`jarvice-compute` nodes.  These default settings are configurable in the
`jarvice_registry_proxy` stanza found in the helm chart `values.yaml` file.

This service can be enabled within an `override.yaml` file or via the command
line with:

`--set jarvice_registry_proxy.enabled=true`

Repositories listed in `JARVICE_REGISTRY_PROXY_REPOS` will utilize the proxy
for application containers. This comma separated list defaults to
`us-docker.pkg.dev/jarvice,us-docker.pkg.dev/jarvice-system,us-docker.pkg.dev/jarvice-apps` and can be
customized within `override.yaml` file or via the command line with:

`--set jarvice.JARVICE_REGISTRY_PROXY_REPOS="<repo_lists_served_by_proxy>"`

**Note:** If storage persistence is enabled, the underlying volume will need to
have `atime` support in order for garbage collection to function properly.

##### `cert-manager`

Note that `cert-manager` must be deployed prior to enabling
`jarvice-registry-proxy`.
The `deploy2k8s-cert-manager` shell script included in the `scripts`
directory of this helm chart can be used to deploy it.

##### Garbage collection

It may be desirable to schedule clean up of cached images that have
not been recently accessed.  This can be automated via this
helm chart by setting `jarvice_registry_proxy_gc.enabled` to `true` and
setting `jarvice_registry_proxy_gc.env.IMAGE_LAST_ACCESS_SECONDS` to the
desired value.  `IMAGE_LAST_ACCESS_SECONDS` defaults to `2592000` (30 days
ago).

**Note:** See
[Cron schedule syntax](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#cron-schedule-syntax)
for details on modifying `jarvice_registry_proxy_gc.schedule`.

------------------------------------------------------------------------------

## JARVICE Downstream Installation

The JARVICE helm chart supports a deployment mode for downstream clusters.
Once a downstream [kubernetes cluster](#kubernetes-cluster) is ready and it's
nodes are [labeled and tainted](#kubernetes-cluster-shaping), a downstream
JARVICE deployment can quickly be deployed into the cluster with a helm
command similar to the following:

```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice jarvice \
    --version 3.0.0-1.XXXXXXXXXXXX \
    --repo https://nimbix.github.io/jarvice-helm/ \
    --namespace jarvice-system --install \
    --set jarvice.imagePullSecret="$(echo "_json_key:$(cat jarvice-reg-creds.json)" | base64 -w 0)" \
    --set jarvice.JARVICE_CLUSTER_TYPE="downstream" \
    --set jarvice.JARVICE_SCHED_SERVER_KEY="<user>:<password>" \
    --set jarvice.JARVICE_JOBS_DOMAIN="<downstream-domain.com>" \
    --set jarvice_k8s_scheduler.ingressHost="<jarvice.downstream-domain.com>"
```

The `jarvice.JARVICE_CLUSTER_TYPE` value `downstream` is how the helm chart
determines that this is a downtream deployment of JARVICE.  A `downstream`
deployment automatically disables JARVICE components which are only necessary
in an upstream deployment.

It is recommended that `jarvice.JARVICE_SCHED_SERVER_KEY` is set to provide
authentication for an upstream JARVICE deployment.

The above command assumes that the downstream kubernetes cluster already has a
[kubernetes ingress controller](#kubernetes-ingress-controller) deployed into
it.  It is possible for the downstream JARVICE deployment to utilize a load
balancer service with an IP address, however, ingress is the preferred way
to access JARVICE clusters.

### Upstream cluster settings

Once a downstream deployment is up and running, it will be necessary to
enable it in the upstream cluster.  In order to do so, as a JARVICE
administrator, navigate to the `Clusters` panel found under `Administration`
and click `NEW`.  Use the downstream ingress host name
(`https://<jarvice.downstream-domain.com>`) and scheduler server key
(`<user>:<password>`) in the `URL` and `Authentication` dialog boxes
respectively.

------------------------------------------------------------------------------

## JARVICE Configuration Values Reference

More information on the specific JARVICE configuration options can be found
in the comments found in the `values.yaml` file.  Please refer to that as
it's own configuration reference.

------------------------------------------------------------------------------

## JARVICE Post Installation

### Install recommended DaemonSets

#### LXCFS

JARVICE utilizes LXCFS so that each Nimbix Application Environment (NAE) will
properly reflect the resources requested for each job.

In order to enable the LXCFS DaemonSet provided in this helm
chart, add the following `--set` flag to the helm install/upgrade command:
```bash
--set jarvice.daemonsets.lxcfs.enabled="true"
```

#### JARVICE Images Pull

JARVICE Images Pull is a DaemonSet which can be utilized to pre-populate
kubernetes worker nodes with the docker images used to run JARVICE
appplications.  This can be used to speed up job startup times for the most
used JARVICE applications.

In order to enable the cache pull DaemonSet provided in this helm
chart, add the following `--set` flag to the helm install/upgrade command:
```bash
--set jarvice.daemonsets.images_pull.enabled="true"
```

The images pull interval can then be set with
`jarvice.daemonsets.images_pull.interval`.
The images to pull can be set per architecture via
`jarvice.daemonsets.images_pull.images.amd64` and
`jarvice.daemonsets.images_pull.images.arm64`.

**Note:**  JARVICE Images Pull supersedes JARVICE Images Pull.

#### JARVICE Cache Pull (Deprecated)

**Note:**  JARVICE Cache Pull has been superseded by JARVICE Images Pull.

JARVICE Cache Pull is a DaemonSet which can be utilized to pre-populate
kubernetes worker nodes with the docker images used to run JARVICE
appplications.  This can be used to speed up job startup times for the most
used JARVICE applications.

In order to enable the cache pull DaemonSet provided in this helm
chart, add the following `--set` flag to the helm install/upgrade command:
```bash
--set jarvice.daemonsets.cache_pull.enabled="true"
```

During the initial helm installation, this will create the `jarvice-cache-pull`
ConfigMap with a default configuration.  This can be edited with the following:
```bash
$ kubectl --namespace <jarvice-system-daemonsets> \
    edit configmap jarvice-cache-pull
```

The `jarvice-cache-pull` ConfigMap is used to configure the interval at which
images will be pulled along with which images to pull on certain architectures.

In order to recreate this ConfigMap manually, use commands similar to the
following:
```bash
$ kubectl --namespace <jarvice-system-daemonsets> delete configmap \
    jarvice-cache-pull
$ cat >image.config <<EOF
[
    {
        "ref": "app-filemanager",
        "registry": "us-docker.pkg.dev",
        "private": false,
        "arch": {
            "amd64": "us-docker.pkg.dev/jarvice/images/app-filemanager:ocpassform",
            "arm64": "us-docker.pkg.dev/jarvice/images/app-filemanager:ocpassform-arm"
        }
    },
    {
        "ref": "ubuntu-desktop",
        "registry": "us-docker.pkg.dev",
        "private": false,
        "arch": {
            "amd64": "us-docker.pkg.dev/jarvice/images/ubuntu-desktop:bionic",
            "arm64": "us-docker.pkg.dev/jarvice/images/ubuntu-desktop:bionic-arm"
        }
    },
    {
        "ref": "app-openfoam",
        "registry": "us-docker.pkg.dev",
        "private": false,
        "arch": {
            "amd64": "us-docker.pkg.dev/jarvice/images/app-openfoam:8",
            "arm64": "us-docker.pkg.dev/jarvice/images/app-openfoam:8-arm"
        }
    }
]
EOF
$ kubectl --namespace <jarvice-system-daemonsets> create configmap \
    jarvice-cache-pull --from-literal interval=300 --from-file image.config
```

Please view the README.md for more detailed configuration information:
https://github.com/nimbix/jarvice-cache-pull

### Install a dynamic storage provisioner

If `jarvice_dockerbuild.persistence.enabled` is set to `true`, it will be
necessary to have a dynamic storage provisioner installed and an accompanying
`StorageClass` created which uses it.  If deploying JARVICE on a cloud based
managed kubernetes service, this should already be in place.  For on-premises
cluster installations, please review the following documentation:

- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)

### Set up database backups

It is recommended that JARVICE database backups be regularly scheduled.
This helm chart includes an optional kubernetes CronJob which can be enabled
to regularly back up the JARVICE database.
It can be enabled either in an `override.yaml` file or via the helm
command line with:

`--set jarvice_db_dump.enabled=true`

Use of the CronJob also requires a persistent volume in which to store the
database dump files.  By default, it will attempt to use the `jarvice-db-dump`
storage class and request 50GB of storage.  The
`extra/jarvice-db-dump-pv.yaml` file is provided as a simple example for
creating a persistent volume that can be used for persistent storage.

Please review the `jarvice_db_dump` stanza found in `values.yaml` for more
details on the CronJob settings for backups.

**Note:** See
[Cron schedule syntax](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#cron-schedule-syntax)
for details on modifying `jarvice_db_dump.schedule`.

#### Dumping the database with the `jarvice-db-dump` script

The `jarvice-db-dump` shell script included in the `scripts`
directory of this helm chart can also be used to backup the JARVICE database.
Simply execute `./scripts/jarvice-db-dump --help` to see it's usage.

#### Restoring the database from backup

The `jarvice-db-restore` shell script included in the `scripts`
directory of this helm chart can be used to backup the JARVICE database.
Simply execute `./scripts/jarvice-db-restore --help` to see it's usage.

#### Database upgrades

If using the `jarvice-db` deployment provided by this helm chart and the
value of `jarvice_db.image` is updated upon subsequent JARVICE upgrades, it
will be necessary to run the `./scripts/jarvice-db-upgrade` script afterwords
to update the stored data for use with the newer database image.

**Note:** The default value of `jarvice_db.image` has been changed from
`mysql` to the latest `mariadb` release in all JARVICE releases after
`3.0.0-1.202011252103`.
If upgrading to a release newer than `3.0.0-1.202011252103`, be sure to
execute `./scripts/jarvice-db-upgrade`.

### Customize JARVICE files via a ConfigMap

Some JARVICE files can be updated via a ConfigMap.  The files found
in `jarvice-helm/jarvice-settings` represent
all of those files which may optionally be updated from the setting of a
ConfigMap.

The portal may be "skinned" with a custom look and feel by providing
replacements for `default.png`, `favicon.png`, `logo.png`, `palette.json`,
or `eula.txt`.

To add custom HTML content on the About page, an about.html file is required in the jarvice-override-settings directory, with a configmap
#### Step-by-step customization procedure for the aforementioned JARVICE settings

Create directory for setting the JARVICE customizations:
```bash
$ mkdir -p jarvice-helm/jarvice-settings-override
```

In `jarvice-helm/jarvice-settings-override`, it will only be necessary to
create those files which are to be customized.  The defaults found in
`jarvice-helm/jarvice-settings` may be copied and edited as desired.

Load the new JARVICE settings by creating a ConfigMap in each of the 3 system namespaces:
```bash
$ kubectl --namespace jarvice-system \
    create configmap jarvice-settings \
    --from-file=jarvice-helm/jarvice-settings-override
$ kubectl --namespace jarvice-system-pulls \
    create configmap jarvice-settings \
    --from-file=jarvice-helm/jarvice-settings-override
$ kubectl --namespace jarvice-system-builds \
    create configmap jarvice-settings \
    --from-file=jarvice-helm/jarvice-settings-override
```

Reload jarvice-mc-portal pods (only to apply default.png, favicon.png,
logo.png, palette.json, eula.txt, admin_invite.mailtemplate,
forgot_password.mailtemplate, signup_request_team.mailtemplate, or
signup_success.mailtemplate updates):
```bash
$ kubectl --namespace jarvice-system delete pods -l component=jarvice-mc-portal
```

Reload jarvice-scheduler pods (only to apply email.head or email.tail updates):
```bash
$ kubectl --namespace jarvice-system delete pods -l component=jarvice-scheduler
```

Reload jarvice-dal pods (only to apply dal_hook\*.sh updates):
```bash
$ kubectl --namespace jarvice-system delete pods -l component=jarvice-dal
```

### Customize Keycloak login and email theme

The Keycloak login and email themes can be customized using initContainers with settings provided by `jarvice-settings` configMap.

#### Step 1) Adding initContainers to `keycloakx` section of `values.yaml`

```bash
  extraInitContainers: |
    - name: get-bird-theme
      image: us-docker.pkg.dev/jarvice-system/images/jarvice-keycloak:jarvice-master
      imagePullPolicy: Always
      command:
        - sh
      args:
        - -c
        - |
          cp /opt/keycloak/providers/*.jar /theme
      volumeMounts:
        - name: theme-init
          mountPath: /theme
    - name: build-custom-theme
      env:
        - name: KEYCLOAK_BEFORE_LOGO
          value: "keycloak_theme_before.png"
        - name: KEYCLOAK_AFTER_LOGO
          value: "keycloak_theme_after.png"
      image: us-docker.pkg.dev/jarvice/images/eclipse-temurin:11-jdk-ubi9-minimal
      imagePullPolicy: Always
      command:
        - sh
      args:
        - -c
        - |
          set -e
          chown root:root /theme/*.*
          cd /theme
          jar xf bird-keycloak-themes.jar
          rm -rf theme/oldatos
          rm -rf bird-keycloak-themes.jar
          # uncomment to customize login theme
          #rm theme/eviden/login/resources/img/*.*
          #cp /jarvice-settings/favicon.ico theme/eviden/login/resources/img/
          #cp /jarvice-settings/$KEYCLOAK_BEFORE_LOGO theme/eviden/login/resources/img/
          #cp /jarvice-settings/$KEYCLOAK_AFTER_LOGO theme/eviden/login/resources/img/
          #cp /jarvice-settings/keycloak-bg.jpg theme/eviden/login/resources/img/
          #sed -i "s|Software-Suites-black.svg|$KEYCLOAK_BEFORE_LOGO|" theme/eviden/login/resources/css/login.css
          #sed -i "s|eviden.svg|$KEYCLOAK_AFTER_LOGO|" theme/eviden/login/resources/css/login.css
          # uncomment to customize email theme
          #mkdir -p theme/eviden/email/messages
          #echo 'parent=keycloak' > theme/eviden/email/theme.properties
          #echo 'import=common/keycloak' >> theme/eviden/email/theme.properties
          #cp /jarvice-settings/messages_en.properties theme/eviden/email/messages
          #sed -i "s|\"login\"|\"login\", \"email\"|" META-INF/keycloak-themes.json
          jar cf bird-keycloak-themes.jar theme/ META-INF/
          rm -rf theme/ META-INF/
      volumeMounts:
        - name: theme-init
          mountPath: /theme
        - name: theme-config
          mountPath: /jarvice-settings
  extraVolumes: |
    - name: theme-init
      emptyDir: {}
    - name: theme-config
      configMap:
        name: jarvice-settings
        optional: true
  extraVolumeMounts: |
    - name: theme-init
      mountPath: "/opt/keycloak/providers"
      readOnly: true
```

#### Step 2) Provide override files in `jarvice-settings`:

##### Keycloak login theme
* `favicon.ico` favicon used for webpages
* `keycloak_theme_before.png` logo or branding for top-left of login page (png/svg format preferred)
* `keycloak_theme_after.png` logo or branding for top-right of login page (png/svg format preferred)
* `keycloak-bg.jpg` background image for login page (1920x1080 resolution recommended)
##### Keycloak email theme
* `messeges_en.properties` Keycloak email messages.
```bash
/* sample messeges_en.properties */
passwordResetSubject=My password recovery
passwordResetBody=Reset password link: {0}
passwordResetBodyHtml=<a href="{0}">Reset password</a>
```

### View status of the installed kubernetes objects

To get the status for all of the kubernetes objects created in the
`jarvice-system` namespace:

```bash
$ kubectl --namespace jarvice-system get all
```

### Retreive IP addresses for accessing JARVICE

If utilizing LoadBalancer IP addresses instead of an ingress controller for
web portal and API endpoint access, the LoadBalancer IP addresses can be
found with the following commands:

```bash
$ PORTAL_IP=$(kubectl --namespace jarvice-system get services \
    jarvice-mc-portal-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
$ API_IP=$(kubectl --namespace jarvice-system get services \
    jarvice-api-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Then use https://`$PORTAL_IP`/ to initialize and/or log into JARVICE.

### Deploy "EFK" Stack

The `deploy2k8s-efk` shell script included in the `scripts`
directory of this helm chart can used to deploy an Elasticsearch,
Fluentd/Fluent-bit, Kibana (EFK) stack that can be used to examine logs of
containers run on kubernetes nodes.
Simply execute `./scripts/deploy2k8s-efk --help` to see it's usage.

The script is opinionated and is provided as an initial starting point.
It is not intended to be used a production setup as more detailed
configuration regardning site specific options and security is beyond the
scope of this document.

Please reference the
[Elastic Stack and Production Documentation](https://www.elastic.co/guide/index.html)
for more details on further configuring an Elasticsearch based stack.

------------------------------------------------------------------------------

## Additional Resources

- [Release Notes](ReleaseNotes.md)
- [Resource Planning and Scaling Guide](Scaling.md)
- [JARVICE System Configuration Notes](Configuration.md)
- [User Storage Patterns and Configuration](Storage.md)
- [Ingress Patterns and Configuration](Ingress.md)
- [Active Directory Authentication Best Practices](ActiveDirectory.md)
- [In-container Identity Settings and Best Practices](Identity.md)
- [JARVICE Multi-tenant Overview](MultiTenant.md)
- [JARVICE Troubleshooting Guide](Troubleshooting.md)
- [JARVICE Helm chart deployment scripts](https://github.com/nimbix/jarvice-helm/tree/master/scripts)
- [Kubernetes Cluster Installation](KubernetesInstall.md)
- [JARVICE deployment with Terraform](Terraform.md)
- [JARVICE Developer Documentation (jarvice.readthedocs.io)](https://jarvice.readthedocs.io)

### Patents and Intellectual Property

For the most up to date information on Nimbix inventions and intellectual property, please visit the [Nimbix Patents](https://www.nimbix.net/patents) page.

