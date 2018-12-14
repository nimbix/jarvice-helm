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
installing helm, MetalLB can quickly be quickly be installed via helm commands.
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
supported by JARVICE.  After installing helm, Traefik can quickly be quickly
be installed via helm commands.  However, it will be necessary to configure
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
    --set ssl.enabled=true \
    --set ssl.enforced=true \
    --set ssl.permanentRedirect=true \
    --set ssl.insecureSkipVerify=true \
    --set ssl.defaultCert="$(cat site.localdomain.crt | base64 -w 0)" \
    --set ssl.defaultKey="$(cat site.localdomain.key | base64 -w 0)" \
    --set rootCAs="$(cat rootCA.crt)" \
    --set dashboard.enabled=true \
    --set dashboard.domain=traefik-dashboard.<domain> \
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

### JARVICE license and credentials

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

Retreieve the IP address from the `kubernetes-dashboard-lb` service:
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

### Node label for `jarvice-dockerpull` and `jarvice-compute`

In order to take advantage of docker layer caching when pulling
application images into JARVICE, it is recommended that a node in the
kubernetes cluster be labeled for those operations.  Use a command similar
to the following to do so:
```bash
$ kubectl label nodes <node_name> node-role.jarvice.io/jarvice-dockerpull=
```

Cluster requirements may also make it desirable to designate a set of nodes
specifically for running JARVICE jobs:
```bash
$ kubectl label nodes <node_names> node-role.jarvice.io/jarvice-compute=
```

After setting the above label, it will be necessary to add a matching
`node-role.jarvice.io/jarvice-compute=` string to the `properties` field of
the machine definitions found in the JARVICE console's "Administration" tab.
This string will be used as a kubernetes node selector when assigning jobs.

Further details on node labels and selectors can be found below.

------------------------------------------------------------------------------

## JARVICE Quick Installation (Demo without persistence)

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

### Node labels and selectors

This helm chart utilizes a node selector which is applied to all of the JARVICE
components (`jarvice.nodeSelector`), as well as node selectors for each
individual JARVICE component.  These can be set in an `override.yaml` file or
on the `helm` command line.

Note that node selectors are specified using JSON syntax.  When using `--set`
on the `helm` command line, special characters must be escaped.  Also,
individual component selectors will override `jarvice.nodeSelector`.  They are
not additive.

For example, if both
`--set jarvice.nodeSelector="\{\"node-role.jarvice.io/jarvice-system\": \"\"\}"` and
`--set jarvice_dockerpull.nodeSelector="\{\"node-role.jarvice.io/jarvice-dockerpull\": \"\"\}"`
are set on the `helm` command line, `node-role.jarvice.io/jarvice-system` will not be
applied to `jarvice_dockerpull.nodeSelector`.  In the case that both node
selectors are desired for `jarvice_dockerpull.nodeSelector`, use
`--set jarvice_dockerpull.nodeSelector="\{\"node-role.jarvice.io/jarvice-system\": \"\"\, \"node-role.jarvice.io/jarvice-dockerpull\": \"\"\}"`.

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

### Customize JARVICE files via a ConfigMap and Secret

Some JARVICE files can be updated via a ConfigMap and Secret.  The files found
in `jarvice-helm/jarvice-settings` and `jarvice-helm/jarvice-secrets` represent
all of those files which may optionally be updated from the setting of a
ConfigMap and Secret.

The portal may be "skinned" with a custom look and feel by providing
replacements for `default.png`, `favicon.png`, `logo.png`, `palette.json`,
or `eula.txt`.

The portal SSL certificate and key may be updated by providing replacements
for `jarvice-mc-portal.crt` and `jarvice-mc-portal.key` to override the
`jarvice_mc_portal.env.JARVICE_MC_PORTAL_CRT` and
`jarvice_mc_portal.env.JARVICE_MC_PORTAL_KEY` settings found in `values.yaml`.

Instead of editing the `jarvice_dal.env.JARVICE_CFG_NETWORK` and
`jarvice_scheduler.env.MAIL_CONF` settings as found in the `values.yaml` file,
it may be preferable to override them with the `cfg.network` and `mail.conf`
files respectively.

#### Step-by-step customization procedure for the aforementioned JARVICE settings:

Create directory for setting the JARVICE customizations:
```bash
$ mkdir -p jarvice-helm/jarvice-settings-override
$ mkdir -p jarvice-helm/jarvice-secrets-override
```

In `jarvice-helm/jarvice-settings-override` and
`jarvice-helm/jarvice-secrets-override`, it will only be necessary to
create those files which are to be customized.  The defaults found in
`jarvice-helm/jarvice-settings` and `jarvice-helm/jarvice-secrets` may be
copied and edited as desired.

Load the new JARVICE settings by creating a ConfigMap and Secret:
```bash
$ kubectl --namespace jarvice-system \
    create configmap jarvice-settings \
    --from-file=jarvice-helm/jarvice-settings-override
$ kubectl --namespace jarvice-system \
    create secret generic jarvice-secrets \
    --from-file=jarvice-helm/jarvice-secrets-override
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

# Additional Resources

- [JARVICE System Configuration Notes](Configuration.md)
- [Release Notes](ReleaseNotes.md)
- [JARVICE Developer Documentation (jarvice.readthedocs.io)](https://jarvice.readthedocs.io)


