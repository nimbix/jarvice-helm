# JARVICE Slurm Scheduler Overview

JARVICE supports both upstream and downstream Slurm scheduler deployments to dispatch JARVICE jobs
to existing Slurm clusters.

The Slurm scheduler head node must have a public or private IP address that is reachable from
a JARVICE control plane and meet the following dependencies:
* Recent Slurm version - tested with 22.05.4
* Singularity 3.x or higher - tested with 3.8, and 3.10.4
    * 3.11.3+ is required if not using overlayfs (setuid)
    * `singularity` command should be able to reach remote containers via the Internet (e.g. to pull containers); this can happen via a proxy if the login environment is automatically configured to use one
* Non-root Linux user that can run `singularity` command
    * Home directory for this user should be network-mounted and consistent on all compute nodes (as well as login node if this is the entry point for job submissions)
    * Filer providing shared home directory should support POSIX (advisory) file locking - e.g. via the `flock(1)` command

## Architecture

The main architecture is simple:

                    K8S                            K8S                            Bare Metal
            ┌──────────────────┐        ┌──────────────────────────┐        ┌─────────────────────┐
            │                  │        │                          │        │                     │
            │ Jarvice Upstream ├───────►│ Jarvice Slurm Downstream ├───────►│ Slurm cluster login │
            │                  │  http  │                          │  ssh   │                     │
            └──────────────────┘        └──────────────────────────┘        └───┬─────────────────┘
                                                                                │
                                                                                ├─► submit via sbatch
                                                                                └─► check via squeue

Jarvice upstream submit jobs/get jobs status/etc to Jarvice Slurm downstream via http request. Then, Slurm downstream translate queries (new job, job status, etc) and uses ssh connection to execute slurm commands on the target Slurm cluster, then answers upstream requests with commands results.

When user requests an interactive job, a specific proxy pod is running on the Slurm downstream K8S, that acts as a proxy between the compute node executing the job and exposing an http server (gotty shell, novnc, etc.) and the user, using a socat command on Slurm login node to pipeline http through ssh.

             ┌──────────────────┐        ┌──────────────────────────┐        ┌─────────────────────┐        ┌─────────────────────┐
             │                  │  http  │                          │  ssh   │                     │        │                     │
             │ Jarvice Upstream ├───────►│ Jarvice Slurm Downstream ├───────►│ Slurm cluster login │        │ Slurm job worker    │
             │                  │        │                          │        │                     │        │                     │
             │                  │ ┌──────┼──   job proxy pod   ◄────┼────────┼──────   socat     ◄─┼────────┼─ http (novnc/gotty) │
             │                  │ │ http │                          │  ssh   │                     │        │                     │
             └──────────────────┘ │      └──────────────────────────┘        └─────────────────────┘        └─────────────────────┘
                          user  ◄─┘
                           \o/

## Configuration

A JARVICE system admin can add multiple Slurm schedulers to an upstream control plane by registering
each Slurm scheduler URL returned by the jarvice-helm Helm chart into the
`Administration->Clusters` page on the portal. Each Slurm Cluster is required to have
a non-root Linux user's private SSH key to enable communication with the control plane.
The public SSH key should be added to the Slurm clusters authorized keys file.

### External job access via ingress

Ingress is automatically setup on upstream deployments based on the `jarvice-k8s-scheduler` jobs configuration.

If external access will be provided by ingress from a downstream Slurm scheduler, it will be
necessary to set `ingressHost` for each Slurm scheduler defined under the `schedulers` key of the helm chart.

### Slurm Scheduler Environment Variables

Environment|Value|Description/Notes
---|---|---
`JARVICE_SLURM_CLUSTER_ADDR`|string|IPv4 address or hostname for Slurm HPC cluster login node (`x.x.x.x`)
`JARVICE_SLURM_CLUSTER_PORT`|integer|Slurm login node SSH port
`JARVICE_SLURM_SCHED_LOGLEVEL`|integer|Python style debug level (10, 20, 30, etc)
`JARVICE_SLURM_HTTPS_PROXY`|string|`https_proxy` value to apply to Slurm cluster to pull images **from computes nodes**
`JARVICE_SLURM_HTTP_PROXY`|string|`http_proxy` value to apply to Slurm cluster to pull images **from computes nodes**
`JARVICE_SLURM_NO_PROXY`|string|`no_proxy` value to apply to Slurm cluster
`JARVICE_SINGULARITY_TMPDIR`|string|Override tmp directory used by singularity (prevent usage of /tmp for diskless compute nodes for example)
`JARVICE_SLURM_OVERLAY_SIZE`|integer|Overlay size of running singularity images. If set to `0`, singularity will use writable tmpfs instead (with some limitations)
`JARVICE_SINGULARITY_VERBOSE`|boolean|Verbosity flag of singularity jobs execution

### Singularity builds and setuid

By default, singularity ships setuid flag, allowing usage of overlayfs for standard users.
However, if singularity was built without setuid feature, overlayfs is no more available.

The slurm scheduler provides a degraded mode for such singularity builds, using writable-tmpfs feature instead of overlayfs. Be aware that not all applications of HyperHub will be compatible with this mode.

To enable such feature:

* `JARVICE_SLURM_OVERLAY_SIZE` **must** be set to `0`
* singularity version **must** be at least 3.11.3
* `sessiondir max size` in singularity.conf file must be set to at least `640`

### Configuring distant slurm cluster

#### SelectType

Jarvice requires that at least SelectType be based on CPU/GPU/Memory to allow resources allocation and restrictions.

This means at least:

```
SelectType=select/cons_tres
```

Note that currently, Jarvice does not cover the concept of sockets, core per socket, etc. Jobs are CPU core, GPU and Memory limited only.

#### ID mapping

When using user ID mapping, and when `PrivateData` restrictions are set on the target Slurm cluster, users cannot any more see other users jobs via squeue command. Only **coordinators** of accounts can see account associated jobs.
In such restrictive configuration, the main jarvice user (the user used to execute squeue commands) needs to be **coordinator** of every account used by users using Jarvice, to be able to see these users jobs.

#### Identify jarvice jobs

Jarvice jobs are always prefixed by `jarvice_` string. Slurm cluster administrators (root) can easily filter *squeue* output to identify Jarvice jobs. Jarvice jobs name also contain submission date, user name, and application requested.

### Debug

#### Basic

First step is to ensure all Slurm downstream parameters are properly set.

To do so, check deployment settings using (and assuming your deployment was made as jarvice-slurm-scheduler into jarvice-system namespace):

```
kubectl describe deployment -n jarvice-system jarvice-slurm-scheduler
```

Then check that everything is running fine, and check your environment settings:

```
    Environment:
      JARVICE_SLURM_CLUSTER_ADDR:        XXX.XXX.XXX.XXX
      JARVICE_SLURM_CLUSTER_PORT:        XXXX
      JARVICE_SLURM_SSH_USER:            <set to the key 'user' in secret 'jarvice-slurm-scheduler'>  Optional: false
      JARVICE_SLURM_SSH_PKEY:            <set to the key 'pkey' in secret 'jarvice-slurm-scheduler'>  Optional: false
      JARVICE_SLURM_SCHED_LOGLEVEL:      10
      JARVICE_SLURM_OVERLAY_SIZE:        640
      JARVICE_SYSTEM_K8S:                true
      JARVICE_EXPERIMENTAL:              false
      JARVICE_CLUSTER_TYPE:              upstream
      JARVICE_DAL_URL:                   http://jarvice-dal:8080
      JARVICE_SCHED_URL:                 https://jarvice-scheduler:9443
      JARVICE_JOBS_NAMESPACE:            jarvice-system-jobs
      JARVICE_SYSTEM_NAMESPACE:          jarvice-system
      JARVICE_SYSTEM_REGISTRY:           us-docker.pkg.dev
      JARVICE_SYSTEM_REPO_BASE:          jarvice-system/images
      JARVICE_IMAGES_TAG:                jarvice-3.21.9-1.202309110832
      JARVICE_LOCAL_REGISTRY:            
      JARVICE_LOCAL_REPO_BASE:           jarvice
      JARVICE_JOBS_DOMAIN:               jarvice.cloud.nimbix.net/job$
      JARVICE_JOBS_INGRESS_CLASS:        traefik
      JARVICE_JOBS_INGRESS_ANNOTATIONS:  
      JARVICE_JOBS_INGRESS_CERT_ISSUER:  letsencrypt-prod
      JARVICE_SLURM_HTTPS_PROXY:         
      JARVICE_SLURM_HTTP_PROXY:          
      JARVICE_SLURM_NO_PROXY:            
      JARVICE_SINGULARITY_VERBOSE:       false
      JARVICE_SINGULARITY_TMPDIR:   
```

If you face issues, please increase `JARVICE_SLURM_SCHED_LOGLEVEL` to **10** for the next steps.

Also, during pod start, Jarvice Slurm Downstream will display some important information, and attempt an ssh connection to the target cluster. Querying logs of one of the pods of the deployment should help identify possible issues. Just grab all logs between `INFO +----- Slurm Scheduler init report -----+` and `INFO Init done. Entering main loop.` and check of all went well, to confirm scheduler was able to connect over ssh to remote cluster.

```
2023-09-12 09:08:04,204 [1] INFO +----- Slurm Scheduler init report -----+
2023-09-12 09:08:04,205 [1] INFO |-- SSH connection to target cluster:
2023-09-12 09:08:04,205 [1] INFO |     host: XXXXXXXXXXXXXXXXX
2023-09-12 09:08:04,205 [1] INFO |     port: XXXX
2023-09-12 09:08:04,205 [1] INFO |     user: nimbix
2023-09-12 09:08:04,205 [1] INFO |-- Script environment:
2023-09-12 09:08:04,205 [1] INFO |     scratch dir: 
2023-09-12 09:08:04,205 [1] INFO |     http_proxy:
2023-09-12 09:08:04,205 [1] INFO |     https_proxy:
2023-09-12 09:08:04,205 [1] INFO |     no_proxy: 
2023-09-12 09:08:04,205 [1] INFO |-- Singularity environment:
2023-09-12 09:08:04,205 [1] INFO |     tmp work dir: /scratch
2023-09-12 09:08:04,205 [1] INFO |     verbose mode: true
2023-09-12 09:08:04,205 [1] INFO |     overlay size: 128
2023-09-12 09:08:04,205 [1] INFO +---------------------------------------+
2023-09-12 09:08:04,205 [1] INFO 
2023-09-12 09:08:04,205 [1] INFO  Now testing connectivity to target cluster...
2023-09-12 09:08:11,774 [1] INFO Connected (version 2.0, client OpenSSH_8.0)
2023-09-12 09:08:12,484 [1] INFO Authentication (publickey) successful!
2023-09-12 09:08:12,866 [1] INFO Init done. Entering main loop.
```

#### Interactive jobs

A common issue is ability to run standard jobs, but failure to connect to an interactive job.

There are multiple things that could conflict with an interactive job, like firewall or network restrictions.
A first step is to check that socat proxy pod is running fine. Every interactive job have a dedicated socat proxy running on the Jarvice Slurm Downstream K8S cluster.

Check pod is running using:

```
:~$ kubectl get pods -n jarvice-system-jobs
NAME                                        READY   STATUS    RESTARTS   AGE
jarvice-job-proxy-123156-7c5848c9b7-d65dx   1/1     Running   0          36s
:~$ 
```

Then investigate pod logs in case of connectivity issues.

Before the first connection in the portal:

```
:~$ kubectl logs -n jarvice-system-jobs jarvice-job-proxy-123156-7c5848c9b7-d65dx
/main:21: DeprecationWarning: 'cgi' is deprecated and slated for removal in Python 3.13
  from JarviceScheduler import ForkedSchedPluginServer
2023-09-12 13:08:41,504 [1] INFO Started proxy to 10.128.0.76:63913 via SSH XXX.XXX.XXX.XXX:XXXX
:~$
```

Then once a connection has been done, you should see a lot more logs if debug was enabled. These logs should help you debug possible issues.

Another common issue is a bad definition of `JARVICE_JOBS_DOMAIN`. Check it matchs your cluster domain name.

### Example Helm Values

#### Upstream

```
jarvice_slurm_scheduler:
  enabled: true
  schedulers:
  - name: default
    env:
      JARVICE_SLURM_CLUSTER_ADDR: "8.8.8.8"
      JARVICE_SCHED_SERVER_KEY: "slurm-upstream:Pass1234"
      JARVICE_SLURM_SCHED_LOGLEVEL: "10"
    sshConf:
      user: nimbix
      pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.
  - name: backup
    env:
      JARVICE_SLURM_CLUSTER_ADDR: "4.4.4.4"
    sshConf:
      user: slurm
      pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.      
```

#### Downstream 

```
jarvice_slurm_scheduler:
  enabled: true
  schedulers:
  - name: default
    ingressHost: "jarvice-slurm-downstream.example.com"
    env:
      JARVICE_SLURM_CLUSTER_ADDR: "8.8.8.8"
      JARVICE_SCHED_SERVER_KEY: "slurm-downstream:Pass1234"
      JARVICE_SLURM_SCHED_LOGLEVEL: "10"
    sshConf:
      user: nimbix
      pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.
```
