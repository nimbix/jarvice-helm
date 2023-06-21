# JARVICE Slurm Scheduler Overview

JARVICE supports both upstream and downstream Slurm scheduler deployments to dispatch JARVICE jobs
to existing Slurm clusters.

The Slurm scheduler head node must have a public or private IP address that is reachable from
a JARVICE control plane and meet the following dependencies:
* Recent Slurm version - tested with 22.05.4
* Singularity 3.x or higher - tested with 3.8, and 3.10.4
    * `singularity` command should be able to reach remote containers via the Internet (e.g. to pull containers); this can happen via a proxy if the login environment is automatically configured to use one
* Non-root Linux user that can run `singularity` command
    * Home directory for this user should be network-mounted and consistent on all compute nodes (as well as login node if this is the entry point for job submissions)
    * Filer providing shared home directory should support POSIX (advisory) file locking - e.g. via the `flock(1)` command

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
`JARVICE_SLURM_OVERLAY_SIZE`|integer|Overlay size of running singularity images
`JARVICE_SINGULARITY_VERBOSE`|boolean|Verbosity flag of singularity jobs execution

### Singularity builds and setuid

By default, singularity ships setuid flag, allowing usage of overlayfs for standard users.
However, if singularity was built without setuid feature, overlayfs is no more available.

The slurm scheduler provides a degraded mode for such singularity builds, using writable-tmpfs feature instead of overlayfs. Be aware that not all applications of HyperHub will be compatible with this mode.

To enable such feature:

* `JARVICE_SLURM_OVERLAY_SIZE` **must** be set to `0`
* singularity version **must** be at least 3.11.3
* `sessiondir max size` in singularity.conf file must be set to at least `640`

#### Example Helm Values

##### Upstream

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

##### Downstream 

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
