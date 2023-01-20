# JARVICE Slurm Scheduler Overview

JARVICE supports both upstream and downstream Slurm scheduler deployments to dispatch JARVICE jobs
to existing Slurm clusters.

The Slurm scheduler head node must have a public or private IP address that is reachable from
a JARVICE control plane and meet the following dependencies:
* Recent Slurm version - tested with 22.05.4
* `socat(1)` should be installed and in `${PATH}` for the SSH user
* `resize2fs(8)` should be installed and in `${PATH}` for the SSH user; note that this is used only on overlay files, as non-root
* Singularity 3.x or higher - tested with 3.6, 3.8, and 3.10.4
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
`JARVICE_SLURM_CLUSTER_ADDR`|string|IP address for Slurm headnode (`x.x.x.x`)
`JARVICE_SLURM_CLUSTER_PORT`|integer|Slurm headnode SSH port
`JARVICE_SLURM_SCHED_LOGLEVEL`|integer|Python style debug level (10, 20, 30, etc)
`JARVICE_SLURM_HTTPS_PROXY`|string|`https_proxy` value to apply to Slurm cluster 
`JARVICE_SLURM_HTTP_PROXY`|string|`http_proxy` value to apply to Slurm cluster
`JARVICE_SLURM_NO_PROXY`|string|`no_proxy` value to apply to Slurm cluster
`JARVICE_SINGULARITY_TMPDIR`|string|override tmp directory used by singularity
`JARVICE_SLURM_OVERLAY_SIZE`|integer|overlay size of running singularity images
`JARVICE_SINGULARITY_VERBOSE`|boolean|verbosity flag

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