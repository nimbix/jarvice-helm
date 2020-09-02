# JARVICE Release Notes

* [General](#general)
* [Known Issues, Anomalies, and Caveats](#known-issues-anomalies-and-caveats)
* [Changelog](#changelog)

---
## General

- Singularity containers are not supported; JARVICE can only refer to Docker containers on Kubernetes.  If the container runtime can pull from Docker registries and is OCI compliant, this should be transparent to JARVICE as well.
- JARVICE and its applications refers to "CPU cores" but it can work with hyperthreading and SMT as well; in this case, treat the threads themselves as cores when configuring machine types, etc.  Note that many HPC applications explicitly recommend against using SMT, so consider setting up non-SMT nodes for these applications (they can be targeted with labels)
- The full JSON for all pods in a job can be downloaded via the *DOWNLOAD STDERR* button in the *Job data* for any given job in the *Jobs* view of the *Administration* tab; this should be used to troubleshoot failures by checking the actual Kubernetes status conditions.  Note that pods are deleted and garbage collected automatically once jobs end, so this is the only persistent record of what was specified and what the actual statuses were during the lifecycle.

### Kubernetes Support

The following assumes the latest version of JARVICE is in use; this version will appear at the top of the [Changelog](#changelog), while version-specific items will be noted in their respective sections.

#### Latest Version Supported

Kubernetes **1.18**; newer versions are not explicitly supported.  Using the latest patch release of each version is recommended but not required.

#### Previous Version(s) Supported

Up to 3 previous minor revisions (from the one indicated in [Latest Version Supported](#latest-version-supported)) will be supported at any given time, unless otherwise noted.  Currently this list is limited to:

* Kubernetes **1.17**
* Kubernetes **1.16**
* Kubernetes **1.15**


---
## Known Issues, Anomalies, and Caveats

### JARVICE HPC Pod Scheduler (jarvice-pod-scheduler)

- Custom resource weighting is not yet implemented; all resource multipliers are set to 1 automatically.
- Pod affinity, local volumes, or any mechanism that pins pods to specific nodes in the cluster is not supported; use node labels as machine properties to direct pods to sets of nodes instead, and use network-attached persistent storage only

### Downstream Deployments

- The `jarvice.JARVICE_SCHED_SERVER_KEY` is _required_ and must have a value.
- Overriding in-container identity downstream using `jarvice_k8s_scheduler.env.JARVICE_SCHED_JOB_UID` and `jarvice_k8s_scheduler.env.JARVICE_SCHED_JOB_GID` only works if the identity is mapped upstream for that user (e.g. using `jarvice-idmapper`); as a best practice, the UID/GID override of `505/505` should be used to avoid all issues, if overriding at all.  Further, downstream override should only be used if the downstream cluster is on a different zone than the upstream, to avoid mixing permissions on storage that is accessible by multiple clusters.

### Deployments with Terraform

- Compute node labels will have `true` as the value rather than blank, so ensure machine definitions are correct.  For example, to target work to compute nodes, use `node-role.jarvice.io/jarvice-compute=true` in the *properties* field of the machine definition.
- Persistent volumes **do not** persist after the cluster is destroyed with the `terraform destroy` command.


### Web Portal

- The *Nodes* view in *Administration* should not be used in this version of JARVICE
- It is not currently possible to add users via the web portal without sending them an email to complete a registration; the cluster should be configured to send email and users should have real email addresses.  If this is not possible, you can still create users manually from the shell in any `jarvice-dal-*` pod in the JARVICE system namespace by running the command `/usr/lib/jarvice/bin/create-user` (run without arguments for usage).
- When creating vaults for users, do not use the *SINGLE VOLUME BLOCK* and *BLOCK VOLUME ARRAY* types, as these are not supported and can result in bad vaults that can't be deleted.  Use *FILE SYSTEM VAULT* for `ceph` filesystem mounts only, *NFS* for `nfs` mounts, and *PVC* for everything else (via `PersistentVolume` class and/or name)
- JARVICE does not apply any password policy for LDAP/Active Directory logins; instead, it performs a bind with the user's full DN and the supplied password to validate these as the final step of the login.  It's up to the LDAP administrator to apply policies on binds to help prevent DDoS or brute force login attacks.

### PushToCompute

- It is not necessary to explicitly pull in this version of JARVICE, as Kubernetes will do that implicitly, unless you are using a local registry (via `${JARVICE_LOCAL_REGISTRY}`); however it is a best practice, and is highly recommended so that application metadata can be updated in the service catalog.  If your container has JARVICE objects in it such as an `AppDef`, consider explicit pulls mandatory.
- Complete logs for pulls and builds are available in the `${JARVICE_PULLS_NAMESPACE}` and `${JARVICE_BUILDS_NAMESPACE}` respectively, for pods called `dockerpull--<user>-<app>` and `dockerbuild--<user>-<app>`, where `<user>` is the user who initiated the pull or build, and `<app>` is the application target ID that was built or pulled into; these pods are not garbage collected so that errors can be troubleshooted more effectively.  It is safe to delete them manually if desired.
- JARVICE manages pull secrets automatically for user apps, across any clusters it manages; if the user logs in to a Docker regsitry successfully in the web portal, JARVICE automatically generates and uses a pull secret for all associated app containers owned by that user; if the user logs out, JARVICE removes the pull secret.  Creation, patching, and removal of pull secrets happens at job submission time only.  These pull secrets are managed in the "jobs" namespace (controlled by `${JARVICE_JOBS_NAMESPACE}`).  As a best practice, once an app is set to public, the system administrator should create a permanent pull secret named `jarvice-docker-n`, where *n* is an integer, 0-9, in the `${JARVICE_JOBS_NAMESPACE}`.  This way, if the app owner logs out of the Docker registry for that container, the public app can still be used.
- Creating a new app target as a system admin switched into the *None* zone and then attempting to click on that app card may result in a pop-up error indicating that the application is disabled because there are no valid values in its machine list; refresh the browser page to clear this error.
- The *Build* function may not be supported on some managed Kubernetes systems such as Amazon EKS, resulting in container build failures when used.
- Attempting to create an app target with an ID that already exists results in undefined behavior.

### Resource Limits and Cost Controls

- Resource limit changes do not apply retroactively to jobs that are already queued; any queued jobs will be executed as soon as capacity becomes available.  Constraining resource limits after jobs are in the regular queue has no effect on them.  However, increasing resource limits will allow jobs that are being held due to account settings to move to regular queue if the new limits permit that.

### PersistentVolume Vaults

#### General

- When using a PersistentVolume vault ("PVC" type), users will experience a slight delay when navigating file lists for file arguments in the task builder; on average this will a few seconds each time a directory is clicked.  This is becauase JARVICE cannot mount the storage directly and must instead schedule a pod to get file listings using a PersistentVolumeClaim.  As will all PVC vault types, JARVICE manages the PersistentVolumeClaim objects themselves.
- Before an application with a file selection in the task builder can work, at least one job with the PVC vault attached must be run; typically this will be the *JARVICE File Manager*, which is used to transfer files to and from the storage.
- The name of the PersistentVolumeClaim that JARVICE generates for a PVC vault is derived from the PVC vault name in JARVICE itself - however, it is case insensitive.  This means that `testVault` and `testvault` will result in the same storage claim, for example.
- When using an unzoned PVC vault, or a zoned PVC vault in a zone with multiple clusters, file selection in the task builder may fail even if a job with this vault attached has already been run.

#### ReadWriteOnce PersistentVolumes

- Persistent volumes with RWO access mode, such as block devices, are automatically fronted with a filer service that allows multiple pods (multiple jobs with one or more pods each) to share the device in a consistent way.  Note that the first consumer will experience latency in starting as the filer service must start first.  The filer service runs as a StatefulSet with a single pod.  Note that only 1 filer service will run at any given time regardless of how many jobs access it (since the storage access mode is RWO).
- JARVICE calls the filer pod *`jarvice-<user>-<vault>-0`*, in the "jobs" namespace; for example, for the user `root` with a vault named `pvcdata`, the filer pod would be called `jarvice-root-pvcdata-0` in the "jobs" namespace.  The `-0` is actually generated automatically by Kubernetes as part of the StatefulSet.  Never delete this pod manually as it can lead to data corruption and certain job failure of any job consuming it.  It is garbage collected automatically when not used.
- For information about resizing PersistentVolumes and related StorageClass configuration, please see [Resizing Persistent Volumes using Kubernetes](https://kubernetes.io/blog/2018/07/12/resizing-persistent-volumes-using-kubernetes/).  Note that JARVICE terminates the filer pod after all jobs of that storage complete.
- RWO-backed vaults are still presented as *FILE* type to JARVICE applications, since this is the behavior they emulate; this also increases application compatibility.

##### Advanced

- JARVICE uses guaranteed QoS for filer pods.  By default it requests 1 CPU and 1 gigabyte of RAM.  The filer pod runs a userspace NFS service which may benefit from additional resources for larger deployments.  To adjust, set the environment variables `${JARVICE_UNFS_REQUEST_MEM}` and `${JARVICE_UNFS_REQUEST_CPU}` in the `jarvice-scheduler` deployment.  Note that the memory request is in standard Kubernetes resource format, so 1 Gigabyte is expressed as `1Gi`.
- JARVICE runs filer pods with the node selector provided in `${JARVICE_UNFS_NODE_SELECTOR}`; when using the Helm chart, the values default to the "system" node selector(s), unless `jarvice_dal` has a node selector defined.

### JARVICE API

- The JARVICE API now limits the number of incoming requests to preserve system stability. Requests that can not be processed will receive Service Unavailable (503) HTTP status code. Each API pod will apply a timeout for each request and limit the number of concurrent request processed at a time. This limiting behavior is set by using JARVICE_API_TIMEOUT and JARVICE_API_MAX_CNCR environment variables.
- JARVICE_API_TIMEOUT is the number of milliseconds a given request can stay queued before receiving Service Unavailable (503). The default value is 500ms
- JARVICE_API_MAX_CNCR is the total number of request that can be processed in parallel on each API pod. The default value is 8
- The JARVICE API deployment can be scaled out to increase the number of requests processed. Future guidance will be given for the appropriate values to use for JARVICE_API_TIMEOUT and JARVICE_API_MAX_CNCR to maximize system throughput and availability.

### Clusters and Zones

- Deleting a cluster that has machines assigned to it will result in an unhandled referential integrity error and may render the web portal inoperable; the best practice is to ensure no machine definitions are assigned to the cluster before deleting it.
- Deleting a zone that has clusters or vaults assigned to it will result in an unhandled referential integrity error and may render the web portal inoperable; the best practice is to ensure no clusters and no user vaults are assigned to the zone before deleting it.

### Miscellaneous

- Jobs that run for a very short period of time and fail may be shown as *Canceled* status versus *Completed with Error*; in rare cases jobs that complete successfully may also show up as *Canceled* if they run for a very short period of time (e.g. less than 1 second).
- Account variables for a given user account must be referenced in an application AppDef in order to be passed into the container.  Please see [Application Definition Guide](https://jarvice.readthedocs.io/en/latest/appdef/) for details.
- *NetworkPolicy* may not work with all Kubernetes network plugins and configurations; if JARVICE system pods do not enter ready state as a result of failed connectivity to the `jarvice-db` or `jarvice-dal` service, consider disabling this in the Helm chart
- Automatic mapping of user network home directories into container user home directory if `idmapper` is deployed has been removed.
- If attempting to run compute jobs on hosts in SELinux "enforcing" mode, please see [SELinux Configuration for JARVICE](SELinux.md) for important information.

---


# Changelog

## 3.0.0-1.20190405.1502

* (1584) Job queuing at resource limits (phase 3)
* (1619) Updated default and made configurable notification emails and templates
* (1634) `/jarvice/teamjobs` API endpoint (new); see [/jarvice/teamjobs in The JARVICE API](https://jarvice.readthedocs.io/en/latest/api/#jarviceteamjobs) for details

## 3.0.0-1.20190321.2116

* (1580) Support for automatic vault creation of dynamically provisioned Persistent Volumes (Kubernetes only) - see the `jarvice.JARVICE_PVC_VAULT_*` variables in [values.yaml](values.yaml) for more information
* (1583) Self-service resource limits and cost controls (phase 2) for team payers and team admins
* (1596) Support for Google Kubernetes Engine (GKE) is now GA; see [JARVICE Helm chart deployment scripts](scripts/README.md) for details
* (1603) Ability to control in-container web service URL via AppDef rather than just `/etc/NAE/url.txt`
* (1610) Ability to secure in-container web services via GET URLs with machine-generated tokens; see [Jupyter Demo](https://github.com/nimbix/jupyter-demo) for an example application illustrating this functionality

## 3.0.0-1.20190308.1643

* (1571) Authoritative billing code and discounts for job submissions, and improved billing report accuracy by billing code
* (1572) Active Directory documentation updates (see [Active Directory Authentication Best Practices](ActiveDirectory.md))
* (1573) Automatic schema migration for containerized DALs
* (1582) System administrator-controlled resource limits (phase 1) by billing code range, with payer override
* (1590) Experimental support for Google Kubernetes Engine (GKE)
* (1592) Hide pricing in web portal if not set

## 3.0.0-1.20190222.1004

* (1555) Site integration with shared storage best practices to enable "strong" identity in containers
* (1556) Support for LDAP DN substrings used as machine and app privileges to authorize by DN
* (1558) In container identity defaults control for team payers and team admins
* (1563) Support for Active Directory login via UPN (with or without domain suffix) when service account used

