# JARVICE cloud platform

This is the Helm chart for installation of JARVICE into a kubernetes cluster.

------------------------------------------------------------------------------

## Installation Prerequisites

### Helm (with Tiller) package manager for kubernetes (https://helm.sh/):

The installation requires that the helm command line be installed on a client
machine and that Tiller is installed/initialized in the target kubernetes
cluster.  Please see the Helm Quickstart/Installation guide:

https://docs.helm.sh/using_helm/#quickstart-guide

After Tiller is initialized, it may be necessary to create a tiller service
account with a cluster-admin role binding.  The `tiller-sa.yaml` file can be
used for this.  Modify as necessary for your cluster and issue the following
commands:
```bash
$ kubectl --namespace kube-system create -f jarvice-helm/extra/tiller-sa.yaml
$ helm init --upgrade --service-account tiller
```

<!--
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

### Kubernetes CPU management policies:

JARVICE prefers that kubelets use a `static` CPU managment policy on
the JARVICE worker nodes.  This policy can be set with the arguments given to
a worker node's kublet on startup.

The default CPU management policy is `none`.  As such, it will be necessary
to drain each worker node and remove the previous `cpu_manager_state` file
as a part of the process of restarting each worker node's kubelet.

The following shell script is an example of how one might reconfigure worker
node kubelets on Ubuntu systems:
```bash
#!/bin/bash

# Set KUBELET_EXTRA_ARGS=--cpu-manager-policy=static --kube-reserved cpu=0.1
# Then restart kublet
cmd=$(cat <<EOF
sudo systemctl stop kublet;
sudo rm -f /var/lib/kubelet/cpu_manager_state;
sudo sed -i -e 's/^KUBELET_.*/KUBELET_EXTRA_ARGS=--cpu-manager-policy=static --kube-reserved cpu=0.1/' /etc/default/kubelet;
sudo systemctl start kubelet
EOF
)

nodes=$(kubectl get nodes -o name | awk -F/ '{print $2}')
for n in nodes; do
    kubectl drain --ignore-daemonsets --delete-local-data --force $n
    ssh sudo-user@$n "$cmd"
    kubectl uncordon $n
done
```

Please see the following link for for more information on kubernetes CPU
management policies:
https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/

### Kubernetes network plugin:

As of this writing, Weave is the only known plugin to work out-of-the-box
on multiple architectures (amd64, ppc64le, arm64).  As such, it is recommended
that kubernetes installations use the Weave plugin if intending to run jobs in
a multiarch environment.

If running on a managed kubernetes service, such as Amazon EKS, a network
plugin has likely been set up for the cluster.

### Kubernetes load balancer:

If running on a managed kubernetes service, such as Amazon EKS, a load balancer
has likely been set up for the cluster.  If running a private kubernetes
cluster, a load balancer is required for making the JARVICE services and jobs
externally available/accessible from outside of the kubernetes cluster.

Currently, MetalLB (https://metallb.universe.tf/) is a good solution.  After
installing helm, MetalLB can quickly be installed via helm commands.
However, it will be necessary to configure MetalLB specifically for your
cluster.

Please execute the following to get more details on MetalLB configuration and
installation:
```bash
$ helm inspect stable/metallb
```

### Kubernetes ingress controller:

An ingress controller is required for making the JARVICE services and jobs
externally available/accessible from outside of the kubernetes cluster via
fixed, DNS host names.

Currently, Traefik (https://traefik.io/) is the solution that is
supported by JARVICE.  After installing helm, Traefik can quickly be 
installed via helm commands.  However, it will be necessary to configure
Traefik specifically for your cluster.

Please visit https://github.com/helm/charts/tree/master/stable/traefik and/or
execute the following to get more details on Traefik configuration and
installation via helm:
```bash
$ helm inspect stable/traefik
```

Here is an example command to install Traefik for use with JARVICE:
```bash
$ helm install stable/traefik \
    --set rbac.enabled=true \
    --set nodeSelector."beta\.kubernetes\.io/arch"=amd64 \
    --set nodeSelector."node-role\.kubernetes\.io/jarvice-system"="" \
    --set tolerations[0].key="node-role.kubernetes.io/jarvice-system" \
    --set tolerations[0].effect="NoSchedule" \
    --set tolerations[0].operator="Exists" \
    --set ssl.enabled=true \
    --set ssl.enforced=true \
    --set ssl.permanentRedirect=true \
    --set ssl.insecureSkipVerify=true \
    --set ssl.defaultCert="$(cat <site-domain>.pem | base64 -w 0)" \
    --set ssl.defaultKey="$(cat <site-domain>.key | base64 -w 0)" \
    --set dashboard.enabled=true \
    --set dashboard.domain=traefik-dashboard.<site-domain> \
    --set loadBalancerIP=<static-ip> \
    --set memoryRequest=1Gi \
    --set memoryLimit=1Gi \
    --set cpuRequest=1 \
    --set cpuLimit=1 \
    --set replicas=3 \
    traefik stable/traefik
```

There are a few things to note when installing Traefik for JARVICE.  In
particular, the default resource setting for the helm chart are not sufficient
for use with JARVICE.  It will be necessary to adjust the number of pod
replicas, cpu, and memory settings per site specifications.

It will also be necessary to have a valid `loadBalancerIP` or `externalIP`
which is accessible via DNS lookups.  The site domain's DNS settings will need
to allow wildcard lookups so that the ingress controller can use random host
names for routing JARVICE jobs.  A JARVICE job hostname will look similar to
`jarvice-system-jobs-80.<domain>`.

The full details of a site specific Traefik deployment are beyond the scope of
this document.  Please start here for more in depth information on Traefik:
https://github.com/containous/traefik

### Kubernetes device plugins:

If the cluster nodes have NVIDIA GPU devices installed, it will be necessary
to install the device plugin in order for JARVICE to make use of them.  Please
see the following link for plugin installation details:
https://github.com/NVIDIA/k8s-device-plugin

If the cluster nodes have RDMA capable devices installed, it will be necessary
to install the device plugin in order for JARVICE to make use of them.  Please
see the following link for plugin installation details:
https://github.com/nimbix/k8s-rdma-device-plugin

To quickly install the RDMA device plugin DaemonSet, execute the following:
```bash
$ kubectl -n kube-system apply -f https://raw.githubusercontent.com/nimbix/k8s-rdma-device-plugin/master/rdma-device-plugin.yml
```

### Kubernetes persistent volumes (for non-demo installation):

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

### JARVICE license and credentials:

A JARVICE license and user/password credentials will need to be obtained from
Nimbix sales (`sales@nimbix.net`) and/or support (`support@nimbix.net`).  The
license and credentials will be used for the following settings:

    - jarvice.imagePullSecret.username=<jarvice_quay_io_user>
    - jarvice.imagePullSecret.password=<jarvice_quay_io_pass>
    - jarvice.JARVICE_LICENSE_LIC=<jarvice_license_key>
    - jarvice.JARVICE_REMOTE_USER=<jarvice_upstream_user>
    - jarvice.JARVICE_REMOTE_APIKEY=<jarvice_upstream_user_apikey>

See the commands below for more detail on how to set and use these values.

------------------------------------------------------------------------------

## Installation Recommendations

### kubernetes-dashboard:

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
$ helm inspect stable/kubernetes-dashboard
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

### Kubernetes Cluster Shaping

At the highest level, JARVICE utilizes pods which can be thought of as
encompassing two essential types.  The first of which, `jarvice-system`, are
used for running the JARVICE platform itself.  The second type,
`jarvice-compute`, are used for running JARVICE application jobs.

The `jarvice-system` pods could be broken down further into four basic types.
The base `jarvice-system` pods contain components related to the web portal,
API endpoints, Data Abstraction Layer (DAL), etc.  JARVICE application
builds use `jarvice-dockerbuild` and `jarvice-dockerpull` pod types.  Lastly,
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
$ kubectl label nodes <node_name> node-role.kubernetes.io/jarvice-system=
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
--set jarvice.nodeSelector="\{\"node-role.kubernetes.io/jarvice-system\": \"\"\}"
--set jarvice_dockerpull.nodeSelector="\{\"node-role.kubernetes.io/jarvice-dockerpull\": \"\"\}"
```

In the above case,
`node-role.kubernetes.io/jarvice-system` will not be
applied to `jarvice_dockerpull.nodeSelector`.  In the case that both node
selectors are desired for `jarvice_dockerpull.nodeSelector`, use:
```bash
--set jarvice_dockerpull.nodeSelector="\{\"node-role.kubernetes.io/jarvice-system\": \"\"\, \"node-role.kubernetes.io/jarvice-dockerpull\": \"\"\}"
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
$ kubectl label nodes <node_name> node-role.kubernetes.io/jarvice-dockerbuild=
$ kubectl label nodes <node_name> node-role.kubernetes.io/jarvice-dockerpull=
```

To take advantage of such a setup, set `jarvice_dockerbuild.nodeSelector` and
`jarvice_dockerpull.nodeSelector` in the JARVICE helm chart.

##### Utilizing `jarvice-compute` labels

The following demonstrates how one might label nodes for `jarvice-compute`
pods:
```bash
$ kubectl label nodes <node_name> node-role.kubernetes.io/jarvice-compute=
```

After setting the `jarvice-compute` labels, it will be necessary to add a
matching `node-role.kubernetes.io/jarvice-compute=` string to the `properties`
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
key `node-role.kubernetes.io/jarvice-system`.  A `kubectl` command line
similar to the following could be used to taint nodes already labeled
with `node-role.kubernetes.io/jarvice-system`:
```bash
$ kubectl taint nodes -l node-role.kubernetes.io/jarvice-system= \
    node-role.kubernetes.io/jarvice-system=:NoSchedule
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
$ helm install \
    --set jarvice_api.tolerations[0].effect=NoSchedule \
    --set jarvice_api.tolerations[0].key=node-role.kubernetes.io/jarvice-system \
    --set jarvice_api.tolerations[0].operator=Exists \
    --set jarvice_api.tolerations[1].effect=NoSchedule \
    --set jarvice_api.tolerations[1].key=node-role.kubernetes.io/jarvice-api \
    --set jarvice_api.tolerations[1].operator=Exists
    ...
    --name jarvice --namespace jarvice-system ./jarvice-helm
```

For more information on assigning kubernetes taints and tolerations,
please see the kubernetes documentation:
https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/

#### `jarvice-compute` taints and pod tolerations

The following would taint `jarvice-compute` nodes which are already labeled
with `node-role.kubernetes.io/jarvice-compute`:
```bash
$ kubectl taint nodes -l node-role.kubernetes.io/jarvice-compute= \
    node-role.kubernetes.io/jarvice-compute=:NoSchedule
```

By default, the JARVICE job scheduler creates job pods that tolerate the
`NoSchedule` effect on nodes with the `node-role.kubernetes.io/jarvice-compute`
taint.  This is currently not configurable.
Tolerations for `jarvice-compute` will be made configurable in future
releases of JARVICE.

------------------------------------------------------------------------------

## JARVICE Quick Installation (Demo without persistence)

<!--
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
$ helm install \
    --set jarvice.imagePullSecret.username="<jarvice_quay_io_user>" \
    --set jarvice.imagePullSecret.password="<jarvice_quay_io_pass>" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>" \
    --name jarvice --namespace jarvice-system ./jarvice-helm
```
<!--
    --name jarvice --namespace jarvice-system \
    --version <chart-version> jarvice-master/jarvice
-->

Alternatively, in order to install and get the application catalog
synchronized, use the following `helm` command:
```bash
$ helm install \
    --set jarvice.imagePullSecret.username="<jarvice_quay_io_user>" \
    --set jarvice.imagePullSecret.password="<jarvice_quay_io_pass>" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>" \
    --set jarvice.JARVICE_REMOTE_USER="<jarvice_upstream_user>" \
    --set jarvice.JARVICE_REMOTE_APIKEY="<jarvice_upstream_user_apikey>" \
    --name jarvice --namespace jarvice-system ./jarvice-helm
```
<!--
    --name jarvice --namespace jarvice-system \
    --version <chart-version> jarvice-master/jarvice
-->

### Quick install to Amazon EKS with `jarvice-deploy2eks` script

If a kubernetes cluster is not readily available, JARVICE can be quickly
deployed and demoed using the Amazon EKS managed kubernetes service on AWS.
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
$ helm install \
    --set jarvice.imagePullSecret.username="<jarvice_quay_io_user>" \
    --set jarvice.imagePullSecret.password="<jarvice_quay_io_pass>" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>" \
    --set jarvice.JARVICE_REMOTE_USER="<jarvice_upstream_user>" \
    --set jarvice.JARVICE_REMOTE_APIKEY="<jarvice_upstream_user_apikey>" \
    --set jarvice_db.enabled=true \
    --set jarvice_db.persistence.enabled=true \
    --set jarvice_db.persistence.size=10Gi \
    --set jarvice_registry.enabled=true \
    --set jarvice_registry.persistence.enabled=true \
    --set jarvice_registry.persistence.size=1000Gi \
    --set jarvice.JARVICE_LOCAL_REGISTRY=jarvice-registry:5000 \
    --name jarvice --namespace jarvice-system ./jarvice-helm
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

### Site specific configuration

The easiest way to configure all of the JARVICE options is to copy the default
`values.yaml` file to `override.yaml`.  It can then be modified and used as
a part of the helm installation command:

```bash
$ cp jarvice-helm/values.yaml jarvice-helm/override.yaml
$ helm install --values jarvice-helm/override.yaml \
    --name jarvice --namespace jarvice-system ./jarvice-helm
```

### Updating configuration (or upgrading to newer JARVICE chart version)

The `helm upgrade` command can be used to tweak JARVICE after the initial
installation.  e.g. If it is necessary to increase the number of
replicas/pods for one of the JARVICE services.  The following example
command could be used to update the number of replicas/pods for the
JARVICE DAL deployment:

```bash
$ helm upgrade --reuse-values \
    --set jarvice_dal.replicaCount=3 jarvice ./jarvice-helm
```

This could also be done from an `override.yaml` file:

```bash
$ helm upgrade --reuse-values \
    --values jarvice-helm/override.yaml jarvice ./jarvice-helm
```

### Non-JARVICE specific services

#### MySQL database (`jarvice-db`)

If there is an already existing MySQL installation that you wish to use with
JARVICE, it will be necessary to create an `override.yaml` file (shown above)
and edit the settings in the `jarvice_dal` `env` stanza
(`JARVICE_SITE_DBHOST`, `JARVICE_SITE_DBUSER`, `JARVICE_SITE_DBPASSWD`).

If there is not an existing MySQL installation, but wish to maintain the
database in kubernetes, but outside of the JARVICE helm chart, execute the
following to get more details on using helm to perform the installation:
```bash
$ helm inspect stable/mysql
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
$ helm inspect stable/memcached
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
`--set jarvice.JARVICE_LOCAL_REGISTRY=jarvice-registry:5000`

The registry can be exposed for access from outside the cluster via:

`--set jarvice_registry.external=true`

Please note, that the default TLS certificate and key will not match your
domain/IP and will either need to be updated or used as an "insecure"
docker registry.  Please see the docker documentation for more information:

https://docs.docker.com/registry/insecure/

There is also a docker-registry specific helm chart available for deployment.
Use the helm inspect command for details:
```bash
$ helm inspect stable/docker-registry
```

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
properly reflect the resources requested for each job.  Please use the
following to install:
```bash
$ kubectl --namespace kube-system create \
    -f https://raw.githubusercontent.com/nimbix/lxcfs-initializer/master/lxcfs-daemonset.yaml
```

#### JARVICE Cache Pull

JARVICE Cache Pull is a DaemonSet which can be utilized to pre-populate
kubernetes worker nodes with docker images.  This should be used to speed up
job startup times for the most used JARVICE applications.  It can be installed
with the following command:
```bash
$ kubectl --namespace <jarvice-system> create \
    -f https://raw.githubusercontent.com/nimbix/jarvice-cache-pull/master/jarvice-cache-pull.yaml
```

Please view the README.md for more detailed configuration information:
https://github.com/nimbix/jarvice-cache-pull

### Set up database backups

It is recommended that JARVICE database backups be regularly scheduled.
If using `jarvice-db` as is provided in the JARVICE helm chart, the following
script could be executed from a cronjob to regularly dump the database:
```bash
#!/bin/bash

pod=$(kubectl -n jarvice-system get pods -l component=jarvice-db -ojson | \
        jq -r '.items[] | select(.status.phase=="Running") | .metadata.name')
kubectl -n jarvice-system exec $pod -- \
        mysqldump --user=root --password="Pass1234" \
        nimbix >jarvice-db.sql
```

### Customize JARVICE files via a ConfigMap

Some JARVICE files can be updated via a ConfigMap.  The files found
in `jarvice-helm/jarvice-settings` represent
all of those files which may optionally be updated from the setting of a
ConfigMap.

The portal may be "skinned" with a custom look and feel by providing
replacements for `default.png`, `favicon.png`, `logo.png`, `palette.json`,
or `eula.txt`.

Instead of editing the `jarvice_dal.env.JARVICE_CFG_NETWORK` and
`jarvice_scheduler.env.MAIL_CONF` settings as found in the `values.yaml` file,
it may be preferable to override them with the `cfg.network` and `mail.conf`
files respectively.

#### Step-by-step customization procedure for the aforementioned JARVICE settings:

Create directory for setting the JARVICE customizations:
```bash
$ mkdir -p jarvice-helm/jarvice-settings-override
```

In `jarvice-helm/jarvice-settings-override`, it will only be necessary to
create those files which are to be customized.  The defaults found in
`jarvice-helm/jarvice-settings` may be copied and edited as desired.

Load the new JARVICE settings by creating a ConfigMap:
```bash
$ kubectl --namespace jarvice-system \
    create configmap jarvice-settings \
    --from-file=jarvice-helm/jarvice-settings-override
```

Reload jarvice-dal pods (only to apply cfg.network update):
```bash
$ kubectl --namespace jarvice-system set env \
    deployment/jarvice-dal JARVICE_PODS_RELOAD=$(date +%s)
```

Reload jarvice-scheduler pods (only to apply mail.conf update):
```bash
$ kubectl --namespace jarvice-system set env \
    deployment/jarvice-scheduler JARVICE_PODS_RELOAD=$(date +%s)
```

Reload jarvice-mc-portal pods (only to apply default.png, favicon.png,
logo.png, palette.json, or eula.txt updates):
```bash
$ kubectl --namespace jarvice-system set env \
    deployment/jarvice-mc-portal JARVICE_PODS_RELOAD=$(date +%s)
```

### View status of the installed kubernetes objects

To get the status for all of the kubernetes objects created in the
`jarvice-system` namespace:

```bash
$ kubectl --namespace jarvice-system get all
```

### Retreive IP addresses for accessing JARVICE

The LoadBalancer IP addresses for the MC portal and the API endpoint can be
found with the following commands:

```bash
$ PORTAL_IP=$(kubectl --namespace jarvice-system get services \
    jarvice-mc-portal-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
$ API_IP=$(kubectl --namespace jarvice-system get services \
    jarvice-api-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Then use https://`$PORTAL_IP`/ to initialize and/or log into JARVICE.

------------------------------------------------------------------------------

# Additional Resources

- [JARVICE System Configuration Notes](Configuration.md)
- [Release Notes](ReleaseNotes.md)
- [JARVICE Developer Documentation (jarvice.readthedocs.io)](https://jarvice.readthedocs.io)


