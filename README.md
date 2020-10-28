# JARVICE cloud platform

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
    - [Kubernetes device plugins](#kubernetes-device-plugins)
    - [Kubernetes persistent volumes (for non-demo installation)](#kubernetes-persistent-volumes-for-non-demo-installation)
    - [JARVICE license and credentials](#jarvice-license-and-credentials)
* [Installation Recommendations](#installation-recommendations)
    - [Kubernetes Cluster Shaping](#kubernetes-cluster-shaping)
        - [Node labels and selectors](#node-labels-and-selectors)
        - [Node labels for jarvice-dockerbuild and jarvice-dockerpull](#node-labels-for-jarvice-dockerbuild-and-jarvice-dockerpull)
        - [Utilizing jarvice-compute labels](#utilizing-jarvice-compute-labels)
        - [Node taints and pod tolerations](#node-taints-and-pod-tolerations)
        - [jarvice-compute taints and pod tolerations](#jarvice-compute-taints-and-pod-tolerations)
* [JARVICE Quick Installation (Demo without persistence)](#jarvice-quick-installation-demo-without-persistence)
    - [Code repository of the JARVICE helm chart](#code-repository-of-the-jarvice-helm-chart)
    - [Quick install command with helm](#quick-install-command-with-helm)
    - [Quick install to Amazon EKS or Google GKE](#quick-install-to-amazon-eks-or-google-gke)
* [JARVICE Standard Installation](#jarvice-standard-installation)
    - [Persistent volumes](#persistent-volumes)
    - [Selecting external, load balancer IP addresses](#selecting-external-load-balancer-ip-addresses)
    - [Using an Ingress controller for jobs](#using-an-ingress-controller-for-jobs)
    - [Site specific configuration](#site-specific-configuration)
        - [JARVICE helm deployment script](#jarvice-helm-deployment-script)
    - [Updating configuration (or upgrading to newer JARVICE chart version)](#updating-configuration-or-upgrading-to-newer-jarvice-chart-version)
    - [Non-JARVICE specific services](#non-jarvice-specific-services)
        - [MySQL database (jarvice-db)](#mysql-database-jarvice-db)
        - [Memcached (jarvice-memcached)](#memcached-jarvice-memcached)
        - [Docker registry (jarvice-registry)](#docker-registry-jarvice-registry)
* [JARVICE Downstream Installation](#jarvice-downstream-installation)
    - [Upstream cluster settings](#upstream-cluster-settings)
* [JARVICE Configuration Values Reference](#jarvice-configuration-values-reference)
* [JARVICE Post Installation](#jarvice-post-installation)
    - [Install recommended DaemonSets](#install-recommended-daemonsets)
    - [Set up database backups](#set-up-database-backups)
    - [Customize JARVICE files via a ConfigMap](#customize-jarvice-files-via-a-configmap)
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
directory of this helm chart can be used to install `kubectl`.
Simply execute `./scripts/install-kubectl` to do so.

If the script does not support the client machine's operating system,
specific operating system instructions can be found here:
https://kubernetes.io/docs/tasks/tools/install-kubectl/

### Helm package manager for kubernetes (https://helm.sh/)

Deploying JARVICE requires that the `helm` executable be installed on a
client machine which has access to a kubernetes cluster.
The `install-helm` shell script included in the `scripts`
directory of this helm chart can be used to install `helm`.
Simply execute `./scripts/install-helm` to do so.

If the script does not support the client machine's operating system,
specific operating system instructions can be found here:
https://github.com/helm/helm/releases

**Note:** The JARVICE helm chart requires helm version 3.2.0 or newer.

#### Add `stable` helm chart repository

If `helm` was previously installed (without `install-helm`), it may be
necessary to initialize and update the stable helm chart repository with the
following commands:
```bash
$ helm repo add stable https://kubernetes-charts.storage.googleapis.com/
$ helm repo update
```

Please see the Helm Quickstart Guide for more details:
https://helm.sh/docs/intro/quickstart/

**NOTE:**  This documentation assumes that Helm version 3.0 or newer is being
used with the kubernetes cluster.  Older versions of Helm can be used, but the
`helm` command examples documented here assume that Helm v3 is installed.
If an older version of Helm was previously being used with the target
kubernetes cluster, migration to Helm v3 is highly recommended:
https://helm.sh/blog/migrate-from-helm-v2-to-helm-v3/

<!--  Comment: helm repo not yet enabled
After helm is installed, add the `jarvice-master` chart repository:
```bash
$ helm repo add jarvice-master https://repo.nimbix.net/charts/jarvice-master
```

To confirm that the chart repository was properly added, execute the following
set of commands:
```bash
$ helm repo list
$ helm repo update
$ helm search jarvice
```

The `update` command will make sure that the helm installation has access to
all of the latest JARVICE updates.  It will also need to be run before doing
future JARVICE upgrades.
The `search` command will output the latest available version of JARVICE:
```bash
NAME                   	CHART VERSION         	APP VERSION	DESCRIPTION
jarvice-master/jarvice 	2.0.18-1.20190105.2358	2.0.18     	JARVICE cloud platform
```
-->

### Configure kubernetes CPU management policies

**WARNING:** `static` CPU policy, at the time of this writing, is known to interfere with NVIDIA GPU operations in the container environment.  While this setting can be used to more accurately implement "Guaranteed" QoS for fractional node CPU allocation, **it may not be stable enough for many usecases!**

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

<!--
However, if a more complex configuration is needed for your cluster,
it will be necessary to adjust the script or execute `helm` manually.
Please visit the MetalLB web site (https://metallb.universe.tf/) and/or
execute the following to get more details on MetalLB configuration and
installation:
```bash
$ helm inspect all stable/metallb
```
-->

### Kubernetes ingress controller

An ingress controller is required for making the JARVICE services and jobs
available and accessible from outside of the kubernetes cluster via
DNS host names.
[Traefik](https://traefik.io/) is the ingress controller solution that is
supported by JARVICE.

If your cluster does not already have an ingress controller deployed, see the
[Kubernetes ingress controller](KubernetesInstall.md#kubernetes-ingress-controller)
section of the
[Kubernetes Cluster Installation](KubernetesInstall.md) documentation.

If a more complex configuration is needed for your cluster,
it will be necessary to adjust the `deploy2k8s-traefik` script included in
the `jarvice-helm` git repository or execute `helm` manually.
Please visit https://github.com/helm/charts/tree/master/stable/traefik and/or
execute the following to get more details on Traefik configuration and
installation via helm:
```bash
$ helm inspect all stable/traefik
```

<!--
There are a few things to note when installing Traefik for JARVICE.  In
particular, the default resource setting for the helm chart are not sufficient
for use with JARVICE.  If deploying Traefik with `helm` manually,
it will be necessary to adjust the number of pod
replicas, cpu, and memory settings per site specifications.
-->

**Note:** It will be necessary to have a valid `loadBalancerIP` or `externalIP`
which is accessible via DNS lookups.  The site domain's DNS settings will need
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

This helm chart includes a script which will install and configure all of the
device plugin
[prerequisites](https://github.com/NVIDIA/k8s-device-plugin#prerequisites) on
kubernetes worker nodes running Ubuntu or CentOS/RHEL distributions.  It can
be run directly with the following command line:
```bash
$ curl https://raw.githubusercontent.com/nimbix/jarvice-helm/master/scripts/nvidia-docker-install | bash
```

In order to enable the NVIDIA device plugin DaemonSet provided in this helm
chart, add the following `--set` flag to the helm install/upgrade command:
```bash
--set jarvice.daemonsets.nvidia.enabled="true"
```

For further details on the NVIDIA device plugin itself,
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

For those sites that do not wish to separately install/maintain a MySQL
database and docker registry, this helm chart provides installations for them
via the `jarvice-db` and `jarvice-registry` deployments/services.  If you wish
to use `jarvice-db` and `jarvice-registry` as is provided from this helm chart,
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

------------------------------------------------------------------------------

## Installation Recommendations

<!--
### kubernetes-dashboard

While not required, to ease the monitoring of JARVICE in the kubernetes
cluster, it is recommended that the `kubernetes-dashboard` be installed into
the cluster.

To quickly install the dashboard, issue the following command:
```bash
$ helm install --namespace kube-system \
    --name kubernetes-dashboard stable/kubernetes-dashboard
```

Please execute the following to get more details on dashboard configuration and
installation:
```bash
$ helm inspect all stable/kubernetes-dashboard
```

After the dashboard is installed, it may be desirable to bind the
`kubernetes-dashboard` service account to the `cluster-admin` role so that it
can access the necessary kubernetes cluster components.  The
`kubernetes-dashboard-crb.yaml` file can be used for this.  Modify as necessary
for your cluster and issue the following commands:
```bash
$ kubectl --namespace kube-system create -f jarvice-helm/extra/kubernetes-dashboard-crb.yaml
```

Please be aware the default configuration as provided in
`kubernetes-dashboard-crb.yaml` will allow users to select `SKIP` from the
dashboard's login page.  If this is not desired, modify
`kubernetes-dashboard-crb.yaml` so that it binds the `cluster-admin` role
to a different service account.  See the access control documentation for
more information:
https://github.com/kubernetes/dashboard/wiki/Access-control#admin-privileges

In order to access the dashboard from outside of the cluster, it will be
necessary to expose the deployment.  Here is an example:
```bash
$ kubectl --namespace kube-system expose deployment kubernetes-dashboard \
    --type=LoadBalancer --name kubernetes-dashboard-lb
```

Retrieve the IP address from the `kubernetes-dashboard-lb` service:
```bash
$ kubectl --namespace kube-system get services \
    kubernetes-dashboard-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

If a specific IP is desired, the `--load-balancer-ip` flag is required:
```bash
$ kubectl --namespace kube-system expose deployment kubernetes-dashboard \
    --type=LoadBalancer --name kubernetes-dashboard-lb \
    --load-balancer-ip='<available_IP_from_load_balancer_config>'
```

Login tokens for the dashboard can be retrieved via kubectl.  Here is an
example:
```bash
$ secret=$(kubectl --namespace kube-system get secret -o name | \
    grep '<service_account>-token-')
$ kubectl --namespace kube-system describe $secret | grep '^token:' \
    | awk '{print $2}'
```

Use `https://$DASHBOARD_IP:8443/` to log into the dashboard.
-->

### Kubernetes Cluster Shaping

At the highest level, JARVICE utilizes pods which can be thought of as
encompassing two essential types.  The first of which, `jarvice-system`, are
used for running the JARVICE platform itself.  The second type,
`jarvice-compute`, are used for running JARVICE application jobs.

The `jarvice-system` pods could be broken down further into four basic types.
The base `jarvice-system` pods contain components related to the web portal,
API endpoints, Data Abstraction Layer (DAL), etc.  JARVICE application
builds use `jarvice-dockerbuild` and `jarvice-dockerpull` pod types
(or the combined `jarvice-dockerbuildpull` type).  Lastly,
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
types to specific nodes by utilizing node selectors.  The JARVICE helm chart
provides node selector settings which can be applied to all of the
`jarvice-system` components (`jarvice.nodeSelector`), as well as node
selectors for each individual JARVICE component.  These can be set in a
configuration values `override.yaml` file or on the `helm` command line.

Note that node selectors are specified using JSON syntax.  When using `--set`
on the `helm` command line, special characters must be escaped.  Also,
individual component node selectors are not additive.  They will override
`jarvice.nodeSelector` if they are set.

For example, if both `jarvice.nodeSelector` and
`jarvice_dockerpull.nodeSelector` are specified on the `helm` command line:
```bash
--set-string jarvice.nodeSelector="\{\"node-role.jarvice.io/jarvice-system\": \"true\"\}"
--set-string jarvice_dockerpull.nodeSelector="\{\"node-role.jarvice.io/jarvice-dockerpull\": \"true\"\}"
```

In the example above,
`node-role.jarvice.io/jarvice-system` will not be
applied to `jarvice_dockerpull.nodeSelector`.  In the case that both node
selectors are desired for `jarvice_dockerpull.nodeSelector`, use:
```bash
--set-string jarvice_dockerpull.nodeSelector="\{\"node-role.jarvice.io/jarvice-system\": \"true\"\, \"node-role.jarvice.io/jarvice-dockerpull\": \"true\"\}"
```

For more information on assigning kubernetes node labels and using node
selectors, please see the kubernetes documentation:
https://kubernetes.io/docs/concepts/configuration/assign-pod-node/

##### Node labels for `jarvice-dockerbuild` and `jarvice-dockerpull`

In order to take advantage of docker layer caching when building and pulling
application images into JARVICE, it may be advantageous that a node in the
kubernetes cluster be labeled for both of those operations simultaneously.
Use commands similar to the following to do so:
```bash
$ kubectl label nodes <node_name> node-role.jarvice.io/jarvice-dockerbuild=true
$ kubectl label nodes <node_name> node-role.jarvice.io/jarvice-dockerpull=true
```

Or, it may be desirable to simply combine those into a single label:
```bash
$ kubectl label nodes <node_name> node-role.jarvice.io/jarvice-dockerbuildpull=true
```

To take advantage of such a setup, set `jarvice_dockerbuild.nodeSelector` and
`jarvice_dockerpull.nodeSelector` in the JARVICE helm chart.

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
nodes selectors.  That is, they are used to "repel" pod types from nodes.
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
and `node-role.jarvice.io/jarvice-compute` taints.  This is currently not
configurable.
Tolerations for `jarvice-compute` will be made configurable in future
releases of JARVICE.

------------------------------------------------------------------------------

## JARVICE Quick Installation (Demo without persistence)

<!--  Comment: helm repo not yet enabled
The installation commands assume that they are being run on a client machine
that has access to the kubernetes cluster and has `helm` installed as
mentioned in the installation prerequisites above.  They also assume that the
`jarvice-master` chart repository has also been added.

### Find the latest JARVICE chart version

It is first necessary to find the latest available JARVICE chart version:
```bash
$ helm repo update
$ helm search jarvice
```

Optionally, with the chart version returned by the search, verify the chart
signature:
```bash
$ helm inspect chart --verify --version <chart-version> jarvice-master/jarvice
```

It will also be necessary to provide `--version <chart-version>` to execute
the helm install and upgrade functions mentioned below.
-->

### Code repository of the JARVICE helm chart

It is first necessary to clone this git repository to a client machine that
has access to the kubernetes cluster and has `helm` installed.

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

### Quick install command with helm

Once cloned, JARVICE can be quickly installed via the following `helm` command:

```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
    --set jarvice.imagePullSecret="$(echo "_json_key:$(cat jarvice-reg-creds.json)" | base64 -w 0)" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>"
```
<!--
    --namespace jarvice-system --name jarvice \
    --version <chart-version> jarvice-master/jarvice
-->

Alternatively, in order to install and get the application catalog
synchronized, use the following `helm` command:
```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
    --set jarvice.imagePullSecret="$(echo "_json_key:$(cat jarvice-reg-creds.json)" | base64 -w 0)" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>" \
    --set jarvice.JARVICE_REMOTE_USER="<jarvice_upstream_user>" \
    --set jarvice.JARVICE_REMOTE_APIKEY="<jarvice_upstream_user_apikey>"
```
<!--
    --version <chart-version> jarvice-master/jarvice
-->

**NOTE:** `jarvice.JARVICE_APPSYNC_USERONLY=true` can be set to only synchronize application catalog items owned by the user set in `jarvice.JARVICE_REMOTE_USER`; this is a simple way to restrict the applications that get synchronized from the upstream service catalog.

### Quick install to Amazon EKS or Google GKE

If a kubernetes cluster is not readily available, JARVICE can be quickly
deployed and demoed using kubernetes cluster services such as
Amazon EKS on AWS or Google GKE on GCP.
See the following link for details:

https://github.com/nimbix/jarvice-helm/tree/master/scripts

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
server.  These can be found in the `jarvice-helm/extra` directory.  It is
expected, however, that most sites may want/need a more robust solution.

Please review the detailed kubernetes documentation for further information
on persistent volumes:
https://kubernetes.io/docs/concepts/storage/persistent-volumes/

Expanding upon the previous quick installation command, the following command
could then be used to install JARVICE with persistence enabled:
```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
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

### Selecting external, load balancer IP addresses

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

### Using an Ingress controller for jobs

By default, interactive JARVICE jobs request LoadBalancer addresses; to use
an Ingress controller, set the parameter `jarvice.JARVICE_JOBS_DOMAIN` to the
FQDN of the Ingress controller; JARVICE will create `*.${JARVICE_JOBS_DOMAIN}`
address for accessing interactive jobs over HTTPS.  To assign LoadBalancer
addresses even if Ingress is used, set `jarvice.JARVICE_JOBS_LB_SERVICE=true`,
in which case JARVICE will create both Ingress as well as LoadBalancer service
IPs for interactive jobs.

#### Enable path based ingress

Set the parameter `jarvice.JARVICE_JOBS_DOMAIN` to the FQDN of the Ingress
controller and add the desired path for jobs to use terminated by `$`.

e.g. `JARVICE_JOBS_DOMAIN=my-domain.com/path/to/jobs$`

JARVICE will replace `$` with the job number to enable access to interactive
jobs over HTTPS.

### Additional LoadBalancer service annotation for jobs

On some platforms/deployments, the LoadBalancer service type must be annotated for it to properly assign an address.  The value for `jarvice.JARVICE_JOBS_LB_ANNOTATIONS` should be set to a JSON dictionary of name/value pairs as needed.

#### Example: using an internal LoadBalancer on AWS

Set the parameter `jarvice.JARVICE_JOBS_LB_ANNOTATIONS` to the following value:
```
'{"service.beta.kubernetes.io/aws-load-balancer-internal": "true"}'
```
(note the single quotes needed to properly encapsulate the JSON format)

See [https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html](https://docs.aws.amazon.com/eks/latest/userguide/load-balancing.html) for additional details.

Please note that this parameter is ignored when Ingress is used unless the application specifically requests a LoadBalancer address via its configuration.


### Site specific configuration

The easiest way to configure all of the JARVICE options is to copy the default
`values.yaml` file to `override.yaml`.  It can then be modified and used as
a part of the helm installation command:

```bash
$ cp jarvice-helm/values.yaml jarvice-helm/override.yaml
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
    --values jarvice-helm/override.yaml
```


#### JARVICE helm deployment script

Alternatively, the simplified `deploy2k8s-jarvice` shell script included in
the `scripts` directory of this helm chart can be used to install/upgrade
the JARVICE helm deployment.
Simply execute `./scripts/deploy2k8s-jarvice --help` to see it's usage.

```bash
$ ./jarvice-helm/scripts/deploy2k8s-jarvice --help
Usage:
    ./jarvice-helm/scripts/deploy2k8s-jarvice [options]

Options:
    -r, --release <release>             Helm release name
                                        (Default: jarvice)
    -n, --namespace <kube_namespace>    Kubernetes namespace to deploy to
                                        (Default: jarvice-system)
    -f, --values <values_file>          Site specific values YAML file
                                        (Default: jarvice-helm/override.yaml)

Example:
    ./jarvice-helm/scripts/deploy2k8s-jarvice -f jarvice-helm/override.yaml
```

### Updating configuration (or upgrading to newer JARVICE chart version)

The `helm upgrade` command can be used to tweak JARVICE after the initial
installation.  e.g. If it is necessary to increase the number of
replicas/pods for one of the JARVICE services.  The following example
command could be used to update the number of replicas/pods for the
JARVICE DAL deployment:

```bash
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
    --reuse-values --set jarvice_dal.replicaCount=3
```

This could also be done from an `override.yaml` file:

```bash
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
    --reuse-values --values jarvice-helm/override.yaml
```

### Non-JARVICE specific services

#### MySQL database (`jarvice-db`)

If there is an already existing MySQL installation that you wish to use with
JARVICE, it will be necessary to create an `override.yaml` file (shown above)
and edit the settings database settings (`JARVICE_DBHOST`, `JARVICE_DBUSER`,
`JARVICE_DBPASSWD`) in the base `jarvice` configuration stanza.

If there is not an existing MySQL installation, but wish to maintain the
database in kubernetes, but outside of the JARVICE helm chart, execute the
following to get more details on using helm to perform the installation:
```bash
$ helm inspect all stable/mysql
```

When using a database outside of the JARVICE helm chart, it will be necessary
to disable it in the JARVICE helm chart.  This can be done either in an
`override.yaml` file or via the command line with:

`--set jarvice_db.enabled=false`

Note that the MySQL installation will require a database named `nimbix`.
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
$ helm inspect all stable/memcached
```

When using Memcached outside of the JARVICE helm chart, it will be necessary
to disable it in the JARVICE helm chart.  This can be done either in an
`override.yaml` file or via the command line with:

`--set jarvice_memcached.enabled=false`

#### Docker registry (`jarvice-registry`)

As with the above, you may already have or wish to use a docker registry
outside of the control of the JARVICE helm chart.  If doing so, it will
be necessary to set the `JARVICE_LOCAL_REGISTRY` from the `values.yaml` to
point to the hostname/IP of the docker registry.  (Currently, the default
registry setting points to `docker.io`)

When using the registry provided with the JARVICE helm chart, it will be
necessary to enable it in the JARVICE helm chart.  This can be done either in
an `override.yaml` file or via the command line with:

`--set jarvice_registry.enabled=true`
`--set jarvice.JARVICE_LOCAL_REGISTRY=jarvice-registry:443`

The registry can be exposed for access from outside the cluster via:

`--set jarvice_registry.ingressHost=<jarvice-registry.my-domain.com>`

Please note, that this will require that an ingress controller is installed
in the kubernetes cluster which has a valid TLS certificate and key.

There is also a docker-registry specific helm chart available for deployment.
Use the helm inspect command for details:
```bash
$ helm inspect all stable/docker-registry
```

------------------------------------------------------------------------------

## JARVICE Downstream Installation

The JARVICE helm chart supports a deployment mode for downstream clusters.
Once a downstream [kubernetes cluster](#kubernetes-cluster) is ready and it's
nodes are [labeled and tainted](#kubernetes-cluster-shaping), a downstream
JARVICE deployment can quickly be deployed into the cluster with a helm
command similar to the following:

```bash
$ kubectl create namespace jarvice-system
$ helm upgrade jarvice ./jarvice-helm --namespace jarvice-system --install \
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

#### JARVICE Cache Pull

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
        "ref": "ubuntu:xenial",
        "registry": "docker.io",
        "private": false,
        "config": "jarvice-docker",
        "arch": {
            "amd64": "docker.io/library/ubuntu:xenial",
            "ppc64le": "docker.io/ppc64le/ubuntu:xenial"
        }
    },
    {
        "ref": "centos:latest",
        "registry": "docker.io",
        "private": false,
        "config": "jarvice-docker",
        "arch": {
            "amd64": "docker.io/library/centos:7",
            "ppc64le": "docker.io/ppc64le/centos:7"
        }
    },
    {
        "ref": "base-centos7-realvnc",
        "registry": "quay.io",
        "private": true,
        "config": "jarvice-docker",
        "arch": {
            "amd64": "gcr.io/nimbix/base-centos7-realvnc:7.5"
        }
    }
EOF
$ kubectl --namespace <jarvice-system-daemonsets> create configmap \
    jarvice-cache-pull --from-literal interval=300 --from-file image.config
```

Please view the README.md for more detailed configuration information:
https://github.com/nimbix/jarvice-cache-pull

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

#### Dumping the database with the `jarvice-db-dump` script

The `jarvice-db-dump` shell script included in the `scripts`
directory of this helm chart can also be used to backup the JARVICE database.
Simply execute `./scripts/jarvice-db-dump --help` to see it's usage.

#### Restoring the database from backup

The `jarvice-db-restore` shell script included in the `scripts`
directory of this helm chart can be used to backup the JARVICE database.
Simply execute `./scripts/jarvice-db-restore --help` to see it's usage.

### Customize JARVICE files via a ConfigMap

Some JARVICE files can be updated via a ConfigMap.  The files found
in `jarvice-helm/jarvice-settings` represent
all of those files which may optionally be updated from the setting of a
ConfigMap.

The portal may be "skinned" with a custom look and feel by providing
replacements for `default.png`, `favicon.png`, `logo.png`, `palette.json`,
or `eula.txt`.

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


