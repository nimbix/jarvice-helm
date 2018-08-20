# JARVICE cloud platform

This is the Helm chart for installation of JARVICE into a kubernetes cluster.

------------------------------------------------------------------------------

## Installation Prerequisites

### Helm (with Tiller) package manager for kubernetes (https://helm.sh/):

The installation requires that the helm command line be installed on a client
machine and that Tiller is installed/initialized in the target kubernetes
cluster.  Please see the Quckstart/Installation guide:

https://docs.helm.sh/using_helm/#quickstart-guide

After Tiller is initialized, it may be necessary to create a tiller service
account with a cluster-admin role binding.  The `tiller-sa.yaml` file can be
used for this.  Modify as necessary for your cluster and issue the following
commands:

```bash
$ kubectl --namespace kube-system create -f jarvice-helm/extra/tiller-sa.yaml
$ helm init --upgrade --service-account tiller
```

### Kubernetes network plugin:

As of this writing, weave is the only known plugin to work out-of-the-box
on multiple architectures (amd64, ppc64le, arm64).  As such, it is recommended
that kubernetes installations use the weave plugin if intending to run jobs in
a multiarch environment.

### Kubernetes load balancer:

A load balancer is required for making the JARVICE services and apps externally
available/accessible from outside of the kubernetes cluster.  Currently,
MetalLB (https://metallb.universe.tf/) is a good solution.  After installing
helm, MetalLB can quickly be quickly be installed via helm commands.  However,
it will be necessary to configure MetalLB specifically for your cluster.

Please execute the following to get more details on MetalLB configuration and
installation:

```bash
$ helm inspect stable/metallb
```

### Kubernetes device plugins:

If the cluster nodes have NVIDIA GPU devices installed, it will be necessary
to install the device plugin in order for JARVICE to make use of them.  Please
see the following link for plugin installation details:
https://github.com/NVIDIA/k8s-device-plugin

If the cluster nodes have RDMA capable devices installed, it will be necessary
to install the device plugin in order for JARVICE to make use of them.  Please
see the following link for plugin installation details:
https://github.com/nimbix/k8s-rdma-device-plugin

### Kubernetes persistent volumes (for non-demo installation):

For those sites that do not wish to separately install/maintain a MySQL
database and docker registry, this helm chart provides installations for them
via the jarvice-db and jarvice-registry deployments/services.  If you wish to
use jarvice-db and jarvice-registry as is provided from this helm chart,
persistent volumes will be required for the kubernetes cluster in order to
maintain state for the JARVICE database and applications registry.  This will
be addressed below, but the full details on the setup and management of
persistent volumes in kubernetes is beyond the scope of this document.

Please see the kubernetes documentation for more details:
https://kubernetes.io/docs/concepts/storage/persistent-volumes/

------------------------------------------------------------------------------

## Installation Recommendations

### kubernetes-dashboard:

While not required, to ease the monitoring of JARVICE in the kubernetes
cluster, it is recommended that the kubernetes-dashboard is installed into
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

After the dashboard is installed, it may be necessary to give it a
cluster-admin role binding so that it can access the necessary kubernetes
cluster components.  The `kubernetes-dashboard-crb.yaml` file can be
used for this.  Modify as necessary for your cluster and issue the following
commands:

```bash
$ kubectl --namespace kube-system create -f jarvice-helm/extra/kubernetes-dashboard-crb.yaml
```

In order to access the dashboard from outside of the cluster, it will be
necessary to expose the deployment.  Here is an example:

```bash
$ kubectl --namespace kube-system expose deployment kubernetes-dashboard \
    --type=LoadBalancer --name kubernetes-dashboard-lb
```

The login token for the dashboard can be retrieved via kubectl:

```bash
$ secret=$(kubectl --namespace kube-system get secret -o name | \
    grep 'kubernetes-dashboard-token-')
$ kubectl --namespace kube-system describe $secret | grep '^token:' | awk '{print $2}'
```

------------------------------------------------------------------------------

## JARVICE Quick Installation (Demo without persistence)

### Code repository of the JARVICE helm chart

It is first necessary to clone this git repository to a client machine that
has access to the kubernetes cluster and has helm installed.

```bash
$ git clone https://github.com/nimbix/jarvice-helm.git
```

### Quick install command with helm

Once cloned, JARVICE can be quickly installed via the following helm command:

```bash
$ helm install \
    --set jarvice.imagePullSecret.username="<jarvice_quay_io_user>" \
    --set jarvice.imagePullSecret.password="<jarvice_quay_io_pass>" \
    --set jarvice.JARVICE_LICENSE_LIC="<jarvice_license_key>" \
    --name jarvice --namespace jarvice-system ./jarvice-helm
```

------------------------------------------------------------------------------

## JARVICE Standard Installation

### Persistent volumes

As mentioned in the installation requirements above, the JARVICE database
(jarvice-db) and the JARVICE application registry (jarvice-registry) services
require a that the kubernetes cluster have persistent volumes configured for
their use.

By default, the deployments of these services look for storage class names of
"jarvice-db" and "jarvice-registry" respectively.  These defaults can be
modified in the configuration values YAML or with `--set` on the helm install
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

Also by default, persistence is disabled for jarvice-db and jarvice-registry,
so note that the persistence settings are required to enable use of
persistent volumes by the JARVICE helm chart.

If kubernetes persistent volumes were created which do no match the default
storage classes, it will be necessary to also `--set` the following values to
match the persistent volume storage classes that you wish to use:

- `jarvice.jarvice_db.persistence.storageClass`
- `jarvice.jarvice_registry.persistence.storageClass`

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

The helm upgrade command can be used to tweak JARVICE after the initial
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

### Non-JARVICE specific services (jarvice-db, jarvice-registry)

- MySQL database (jarvice-db)

If there is an already existing MySQL installation that you wish to use with
JARVICE, it will be necessary to create an `override.yaml` file (shown above)
and edit the settings in the jarvice_dal environment stanza
(`JARVICE_SITE_DBHOST`, `JARVICE_SITE_DBUSER`, `JARVICE_SITE_DBPASSWD`).

If there is not an existing MySQL installation, but wish to maintain the
database in kubernetes and outside of the JARVICE helm chart, execute the
following to get more details on using helm to perform the installation:

```bash
$ helm inspect stable/mysql
```

When using a database outside of the JARVICE helm chart, it will be necessary
to disable it in the JARVICE helm chart.  This can be done either in an
`override.yaml` file or via the command line with:

`--set jarvice_db.enabled=false`

Note that the MySQL installation will require a database named 'nimbix'.

- Docker registry (jarvice-registry)

As with the database, you may already have or wish to use a docker registry
outside of the control of the JARVICE helm chart.  If doing so, it will
be necessary to set the `JARVICE_LOCAL_REGISTRY` from the `values.yaml` to
point to the hostname/IP of the docker registry.  (Currently, the default
registry setting points to `docker.io`)

To use the registry provided with this helm chart, use the following setting:

When using a registry provided withe the JARVICE helm chart, it will be
necessary to enable it in the JARVICE helm chart.  This can be done either in
an `override.yaml` file or via the command line with:

`--set jarvice_registry.enabled=true`
`--set jarvice.JARVICE_LOCAL_REGISTRY=jarvice-registry:5000`

The registry can be exposed for access from outside the cluster via:

`--set jarvice_registry.external=true`

Please note, that the default TLS certificate and key will not match your
domain/IP and will either need to be updated or used as an "insecure"
docker registry.  Please see the docker documention for more information:

https://docs.docker.com/registry/insecure/

There is also a docker-registry specific helm chart available for deployment.
Use the helm inspect command for details:

```bash
$ helm inspect stable/docker-registry
```

------------------------------------------------------------------------------

## JARVICE Configuration Values Reference

More information on the specific JARVICE configuration options can be found
in the commments found in the `values.yaml` file.  Please refer to that as
it's own configuration reference.

------------------------------------------------------------------------------

## JARVICE Post Installation

### Optionally, customize the JARVICE portal with a new "skin" and/or SSL certificate/key pair

- Copy the `jarvice-mc-portal-skin` directory to `jarvice-mc-portal-skin-override`.
- Update the image files and/or JSON settings of the color palette in the
  `jarvice-mc-portal-skin-override directory`.
- Create a kubernetes ConfigMap from the `jarvice-mc-portal-skin-override`
  directory.

- Copy the `jarvice-mc-portal-ssl` directory to `jarvice-mc-portal-ssl-override`.
- Update the certificate and key files in the `jarvice-mc-portal-ssl-override`
  directory.
- Create a kubernetes ConfigMap from the `jarvice-mc-portal-ssl-override`
  directory.

- Update the portal deployment environment to force a rolling update of the
  pods with the new skin and/or SSL certificate and key.

Example step-by-step customization procedure for the JARVICE portal:

Skin configuration:
```bash
$ cp -a jarvice-helm/jarvice-mc-portal-skin \
    jarvice-helm/jarvice-mc-portal-skin-override
<update files in jarvice-helm/jarvice-mc-portal-skin-override>
$ kubectl --namespace jarvice-system \
    create configmap jarvice-mc-portal-skin \
    --from-file=jarvice-helm/jarvice-mc-portal-skin-override
```

Certificate configuration:
```bash
$ cp -a jarvice-helm/jarvice-mc-portal-ssl \
    jarvice-helm/jarvice-mc-portal-ssl-override
<update files in jarvice-helm/jarvice-mc-portal-ssl-override>
$ kubectl --namespace jarvice-system \
    create configmap jarvice-mc-portal-ssl \
    --from-file=jarvice-helm/jarvice-mc-portal-ssl-override
```

Reload pods:
```bash
$ kubectl --namespace jarvice-system set env \
    deployment/jarvice-mc-portal JARVICE_PODS_RELOAD=$(date +%s)
```

### View status of the installed kubernetes objects

To get the status for all of the kubernetes objects created in the
"jarvice-system" namespace:

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

