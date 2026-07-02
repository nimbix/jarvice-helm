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
`JARVICE_SLURM_CLIENT`|string|Slurm client backend to use. `ssh_client` (default) submits jobs via SSH; `slurmrestd_client` uses the Slurm REST API
`JARVICE_SLURMRESTD_URL`|string|Base URL of the `slurmrestd` daemon (e.g. `http://slurm-login:6820`). Required when `JARVICE_SLURM_CLIENT=slurmrestd_client`
`JARVICE_SLURM_SA_TOKEN`|string|Static bearer token for `slurmrestd` authentication. Used directly if set; otherwise a Keycloak service account token is obtained automatically
`JARVICE_KEYCLOAK_TOKEN_URL`|string|Full Keycloak token endpoint URL used to obtain a service account token (e.g. `https://keycloak.example.com/realms/myrealm/protocol/openid-connect/token`). Auto-derived from `jarvice_bird.env.KEYCLOAK_URL` and `KEYCLOAK_REALM` when left empty
`JARVICE_KEYCLOAK_CLIENT_ID`|string|Keycloak client ID used for service account token requests. Defaults to `nimbix-slurm-sched-client`
`JARVICE_KEYCLOAK_CLIENT_SECRET`|string|Keycloak client secret. When left empty the secret is read from the `jarvice-slurm-keycloak-client` Kubernetes Secret (auto-managed by the Helm hook when `create_keycloak_client: true`)
`JARVICE_SLURM_USERNAME_CLAIM`|string|JWT claim from which the end-user's Slurm username is extracted. Defaults to `preferred_username`. This should match with the value of `userclaimfield` set in the SLURM configuration.
`JARVICE_CHOWN_WRAPPER`|string|Custom command or path to use instead of `chown` on the Slurm nodes (useful to limit `nimbix`'s user `chown` permissions to only inside the `SCRATCH` directory )

### Slurmrestd Client

In addition to the default SSH-based client, the Slurm scheduler supports submitting and managing jobs via the Slurm REST API (`slurmrestd`). Set `JARVICE_SLURM_CLIENT` to `slurmrestd_client` to enable this mode.

#### Jobs ownership

A key difference from the SSH client is how Slurm jobs are owned:

- **SSH client (default)** — all jobs are submitted as the single user `nimbix` regardless of which JARVICE user initiated the job.
- **Slurmrestd client** — jobs are submitted **on behalf of the actual JARVICE user**. The scheduler extracts the end-user's username from the JWT claim defined by `JARVICE_SLURM_USERNAME_CLAIM` (default: `preferred_username`) and passes it to `slurmrestd` as the job owner.

This means with `slurmrestd_client`, Slurm job accounting, quotas, and fair-share policies apply per real user rather than being aggregated under a single account.

```
jarvice_slurm_scheduler:
  env:
    JARVICE_SLURM_CLIENT: "slurmrestd_client"
    JARVICE_SLURMRESTD_URL: "http://slurm-login.example.com:6820"
```

##### User Mapping

When `slurmrestd_client` is used, the scheduler submits jobs on behalf of the end user by extracting the username from the JWT token. The claim field used is controlled by `JARVICE_SLURM_USERNAME_CLAIM` (default: `preferred_username`). This value **must** be consistent with what Slurm is configured to look for.

Slurm identifies the job owner via the [`AuthAltParameters=userclaimfield`](https://slurm.schedmd.com/slurm.conf.html#OPT_userclaimfield=) setting in `slurm.conf`. If this is not aligned with `JARVICE_SLURM_USERNAME_CLAIM`, job submissions will fail with an authentication or user resolution error.

**Option 1** — Set `userclaimfield` in Slurm to match the claim used by Keycloak (recommended when using the default Keycloak token configuration):

```
AuthAltParameters=jwks=/local/path/to/jwks.json,userclaimfield=preferred_username
```

Then set `JARVICE_SLURM_USERNAME_CLAIM` to the same value:

```yaml
jarvice_slurm_scheduler:
  env:
    JARVICE_SLURM_USERNAME_CLAIM: "preferred_username"
```

**Option 2** — Configure Keycloak to include the `sun` claim in the token, matching Slurm's default. In Keycloak 25.0, this is done under **Clients → Client details → Dedicated scopes → Mapper details** by adding a mapper that maps the username to the `sun` token claim. Make sure the `JARVICE_SLURM_USERNAME_CLAIM` is set it to `sun`, and omit `userclaimfield` from `AuthAltParameters` in `slurm.conf` since it's the default value.


#### Authentication

Two authentication methods are supported for `slurmrestd`:

1. **Static token** — set `JARVICE_SLURM_SA_TOKEN` to a pre-generated bearer token. The scheduler uses it as-is on every request.
2. **Keycloak service account token** — when `JARVICE_SLURM_SA_TOKEN` is empty, the scheduler automatically fetches and refreshes a short-lived token from Keycloak using the configured client credentials. This requires `JARVICE_KEYCLOAK_TOKEN_URL`, `JARVICE_KEYCLOAK_CLIENT_ID`, and `JARVICE_KEYCLOAK_CLIENT_SECRET` to be set.

#### Keycloak Integration

The Helm chart can automatically create the required Keycloak service account client (`nimbix-slurm-sched-client` by default) via a post-install/post-upgrade hook. To enable it, set `create_keycloak_client: true` and ensure `jarvice_bird.env` contains valid Keycloak admin credentials:

```yaml
jarvice_slurm_scheduler:
  create_keycloak_client: true   # run the Keycloak client provisioning Job on install/upgrade
  env:
    JARVICE_SLURM_CLIENT: "slurmrestd_client"
    JARVICE_SLURMRESTD_URL: "http://slurm-login.example.com:6820"
    JARVICE_KEYCLOAK_CLIENT_ID: "nimbix-slurm-sched-client"  # default, can be omitted
    # JARVICE_KEYCLOAK_CLIENT_SECRET: ""  # leave empty to auto-generate

jarvice_bird:
  env:
    KEYCLOAK_URL: "https://keycloak.example.com"
    KEYCLOAK_REALM: "jarvice"
    JARVICE_KEYCLOAK_ADMIN_USER: "admin"
    JARVICE_KEYCLOAK_ADMIN_PASS: "adminpass"
```

The hook behaviour:

- The client secret is **auto-generated** on the first install (`randAlphaNum 32`) and stored in the `jarvice-slurm-keycloak-client` Kubernetes Secret.
- On upgrades the existing secret value is **reused** (looked up from the cluster), so the Keycloak client configuration remains stable.
- To provide your own secret instead, set `JARVICE_KEYCLOAK_CLIENT_SECRET` in values — it takes priority over both the lookup and the auto-generated value.
- The Keycloak provisioning Job only runs when `create_keycloak_client: true`. The Kubernetes Secret is created whenever `create_keycloak_client: true` **or** `JARVICE_KEYCLOAK_CLIENT_SECRET` is explicitly set in values.
- `JARVICE_KEYCLOAK_CLIENT_SECRET` is only injected into the scheduler deployment when `JARVICE_SLURM_CLIENT: slurmrestd_client`.

### Singularity builds and setuid

By default, singularity ships setuid flag, allowing usage of overlayfs for standard users.
However, if singularity was built without setuid feature, overlayfs is no more available.

The slurm scheduler provides a degraded mode for such singularity builds, using writable-tmpfs feature instead of overlayfs. Be aware that not all applications of HyperHub will be compatible with this mode.

To enable such feature:

* `JARVICE_SLURM_OVERLAY_SIZE` **must** be set to `0`
* singularity version **must** be at least 3.11.3
* `sessiondir max size` in singularity.conf file must be set to at least `640`

### Configuring distant slurm cluster

#### Execution environment

##### Custom environment

It is possible for the admin to set a custom environment automatically (like loading modules to launch singularity, etc).

When job is executed, BEFORE singularity execution, the job script will look for an existing `$HOME/.jarvice_custom_env` executable file, and source it if present.

Small tip: adding `set -x` in this file as command will enable verbose tracing for the remaining of the jobs, which can help debugging in case of needs.

##### CUDA environment

When using GPU nodes, the `--nv` parameter is passed to singularity at app execution. In order for singularity to be able to mount CUDA environment (libs, binaries, etc) into the running container, admin can define a small script at `$HOME/.jarvice_cuda_env`, which will be sourced before executing singularity, to load the desired CUDA toolkit.

See `https://docs.sylabs.io/guides/3.5/user-guide/gpu.html` for more details on how singularity uses CUDA.

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

#### Downstream (slurmrestd client with Keycloak)

```yaml
jarvice_slurm_scheduler:
  enabled: true
  create_keycloak_client: true   # create Keycloak client on install/upgrade
  env:
    JARVICE_SLURM_CLIENT: "slurmrestd_client"
    JARVICE_SLURMRESTD_URL: "http://slurm-login.example.com:6820"
    JARVICE_SLURM_CLUSTER_ADDR: "slurm-login.example.com"
    JARVICE_SLURM_SCHED_LOGLEVEL: "10"
    JARVICE_SLURM_USERNAME_CLAIM: "preferred_username"  # claim used by slurm to extract uid
  schedulers:
  - name: default
    sshConf:
      user: nimbix
      pkey: # base64 encoded private ssh key
```
