# JARVICE KNS Scheduler Overview

KNS, for Kubernetes Nested Scheduler, allows to launch Kubernetes based apps as jobs.

## Important

Please understand that for now, KNS scheduler needs cluster-admin rights on the target cluster to run properly.
It is STRONGLY recommanded to run the KNS in a dedicated K8S cluster, not the same than Jarvice upstream.

## Configuration

### KNS Scheduler Environment Variables

Environment|Value|Description/Notes
---|---|---
`JARVICE_KNS_KEEP_VCLUSTERS`|string|This is a debug feature. Default is `false`. If set to `true`, job garbage collector will not be called, and all resources, including vcluster, will remain as it after job is terminated. This helps a lot investigating issues during starting cycle or life of jobs.
`JARVICE_KNS_DEFAULT_LIMIT_RANGE`|string|This set the default limit range of job's namespace (so propagated to vcluster pods). Default is `{"default":{"cpu": 1, "memory": "1Gi"}, "default_request":{"cpu": "200m", "memory": "256Mi"}, "type":"Container"}`. Note that this value is overwritten by app AppDef.json limit range if set.
`JARVICE_KNS_VCLUSTER_SPAWN_DELAY`|integer|This is the maximum time in seconds a vcluster should take to spawn. This is impacted by cluster scale up. Note that this is the delay of a vcluster start only, between the vcluster create command and the time vcluster reports the vcluster to be running not the time of in-init templates apply. Default is `300`.
`JARVICE_KNS_INIT_IMAGE`|string|Repo/image from which to grab KNS init image. Default is `us-docker.pkg.dev/jarvice/images/init-kns`. Note that if no tag is provided in this url, JARVICE_IMAGES_TAG is used. Tag to use is defined by Jarvice native `JARVICE_IMAGES_TAG` value.
`JARVICE_KNS_ALLOW_GOTTY_SHELL`|string|Allow or not, at admin level, usage of the gotty shell when launching a KNS job. Note that for a gotty shell to start, both admin and app's AppDef.json must allow it. Default is `false`.
`JARVICE_KNS_GOTTY_IMAGE`|string|Repo/image from which to grab KNS gotty image. Default is `us-docker.pkg.dev/jarvice/images/kns-gotty`. Note that if no tag is provided in this url, JARVICE_KNS_GOTTY_IMAGE_TAG is used.
`JARVICE_KNS_GOTTY_IMAGE_TAG`|string|Jarvice image tag for gotty image. Default is `n1.3.0`.

The KNS also need the following standard Jarvice values:
* `JARVICE_JOBS_DOMAIN`: domain name to use for job's ingress (downstream domain name).
* `JARVICE_JOBS_INGRESS_CLASS`: ingress class (default is no specific class set for ingress).

### Configuring distant K8S cluster

#### Compute nodes taints

The KNS will run vclusters resources in dedicated nodes, using tolerations. Nodes taints must be set accordingly.

Hard coded tolerations are:

* `node-role.jarvice.io/jarvice-vcluster`
* `node-role.kubernetes.io/jarvice-vcluster`

If using GPU nodes, the following taint must also be set:

* `nvidia.com/gpu`