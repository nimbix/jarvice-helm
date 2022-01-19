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

Kubernetes **1.21**; newer versions are not explicitly supported.  Using the latest patch release of each version is recommended but not required.

#### Previous Version(s) Supported

Up to 3 previous minor revisions (from the one indicated in [Latest Version Supported](#latest-version-supported)) will be supported at any given time, unless otherwise noted.  Currently this list is limited to:

* Kubernetes **1.20**
* Kubernetes **1.19**
* Kubernetes **1.18**

### External S3-compatible Object Storage Service Compatibility

At the time of this writing, JARVICE supports the following service/providers:
* **radosgw** (REST gateway for RADOS object store, part of Ceph)
* AWS S3
* GCP Cloud Storage

Other providers may or may not be compatible, and are not officially supported.

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
- When using a dynamically provisioned *PersistentVolume* underneath a PVC-type vault, it cannot be linked to another user via the *VAULTS* function of the *Administrator->Users* view.  Doing so will result in failures when launching jobs that consume the linked vault.  To share a dataset, it should be done at the team level only when using these types of PVC vaults.

#### ReadWriteOnce PersistentVolumes

- Persistent volumes with RWO access mode, such as block devices, are automatically fronted with a filer service that allows multiple pods (multiple jobs with one or more pods each) to share the device in a consistent way.  Note that the first consumer will experience latency in starting as the filer service must start first.  The filer service runs as a StatefulSet with a single pod.  Note that only 1 filer service will run at any given time regardless of how many jobs access it (since the storage access mode is RWO).
- JARVICE calls the filer pod *`jarvice-<user>-<vault>-0`*, in the "jobs" namespace; for example, for the user `root` with a vault named `pvcdata`, the filer pod would be called `jarvice-root-pvcdata-0` in the "jobs" namespace.  The `-0` is actually generated automatically by Kubernetes as part of the StatefulSet.  Never delete this pod manually as it can lead to data corruption and certain job failure of any job consuming it.  It is garbage collected automatically when not used.
- For information about resizing PersistentVolumes and related StorageClass configuration, please see [Resizing Persistent Volumes using Kubernetes](https://kubernetes.io/blog/2018/07/12/resizing-persistent-volumes-using-kubernetes/).  Note that JARVICE terminates the filer pod after all jobs of that storage complete.
- RWO-backed vaults are still presented as *FILE* type to JARVICE applications, since this is the behavior they emulate; this also increases application compatibility.
- The dynamic filer used to front RWO-backed vaults does not support distributed NFS locking; use caution when using the same datasets across multiple jobs, as file locking cannot be relied upon for synchronization.

##### Advanced

- JARVICE uses guaranteed QoS for filer pods.  By default it requests 1 CPU and 1 gigabyte of RAM.  The filer pod runs a userspace NFS service which may benefit from additional resources for larger deployments.  To adjust, set the environment variables `${JARVICE_UNFS_REQUEST_MEM}` and `${JARVICE_UNFS_REQUEST_CPU}` in the `jarvice-scheduler` deployment.  Note that the memory request is in standard Kubernetes resource format, so 1 Gigabyte is expressed as `1Gi`.
- JARVICE runs filer pods with the node selector provided in `${JARVICE_UNFS_NODE_SELECTOR}`; when using the Helm chart, the values default to the "system" node selector(s), unless `jarvice_dal` has a node selector defined.

#### Multi-tenant Storage Isolation

If using tenant (payer) account storage parameters, the best practice is to not set up system defaults for PVC storage.  Instead, storage parameters should be set per tenant (payer) at the time of account invite.

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

## 3.21.9-1.202201191724

* (JAR-4866) Added support for adding ingress annotations for jobs; see [Additional Ingress annotation for jobs](README.md#additional-ingress-annotation-for-jobs) for details.
* (JAR-4882) Added suggestion box in addition to dropdown for selecting users to add to projects in *Account->Projects* view.
* (JAR-4888) Improved performance of the `/jarvice/events` API endpoint, in addition to the "Active Jobs" detail in the portal's *Administrator->Jobs* view.

## 3.21.9-1.202112081812

* (JAR-4795) Support for automated license feature computation on job submission via hook script; see [Advanced: Automatic License Feature Computation](LicenseManager.md#advanced-automatic-license-feature-computation) for details.
* (JAR-4804) Support for signaling processes in running jobs (e.g. to suspend or resume jobs) via the JARVICE API; see the [/jarvice/signal](https://jarvice.readthedocs.io/en/latest/api/#jarvicesignal) API documentation for details.
* (JAR-4809) Support for deploying JARVICE clusters behind HTTP(s) proxy servers; see the values `jarvice.JARVICE_HTTP_PROXY`, `jarvice.JARVICE_HTTPS_PROXY`, and `jarvice.JARVICE_NO_PROXY` in [values.yaml](values.yaml) for details; note that proxy configuration may be set independently for upstream and downstream clusters in multi-cluster configuration.
* (JAR-4838) Preemptible license feature configuration in *Administration->License Manager* view; **note that this feature is currently incomplete and will not impact scheduling until a future release**.


## 3.21.9-1.202111241749

* (JAR-4654) Added the ability to specify availability zones for node groups separately from the control plane on EKS and AKS deployments.  Use the `zones` key in the respective node group Terraform configuration to specify a different value than that of the system nodes.
* (JAR-4805) Added suspended job substatuses for future functionality.
* (JAR-4808) Fixed bug where invalid AppDef was preventing the ability to retrive a PushToCompute log.
* (JAR-4810) Migration of JARVICE system containers to Google Artifact Repository (AR) due to deprecation of gcr.io
* (JAR-4824) Added `hostbatch` pseudo-device in machine definitions to allow non-interactive batch jobs to run in host network namespace.  This feature should only be used as part of a support recommendation.

## 3.21.9-1.202111101808

* (JAR-4756) Improved PushToCompute build mechanism.  For details, please see [PushToCompute (`jarvice-dockerbuild`) Configuration](README.md#pushtocompute-jarvice-dockerbuild-configuration).

## 3.21.9-1.202110271630

* (JAR-4699) Increased job label character limit to 255 (from 50).
* (JAR-4703) Support for multiple license daemons per server entry in JARVICE License Manager.  See [Advanced: Multiple License Server Addresses](LicenseManager.md#advanced-multiple-license-server-addresses) for additional details.
* (JAR-4704) Allow omission of `job_project` key in the `/jarvice/submit` API payload if a non-administrative user is assigned to only 1 project.
* (JAR-4710) Kubernetes 1.20 support.  See [Kubernetes Support](#kubernetes-support) for the latest list of supported Kubernetes versions.
* (JAR-4744) Hide job project selection in task builder if a user is assigned to only 1 project.

## 3.21.9-1.202110141638

* (JAR-130) Fixed minor failed login attempt lockout logic bug.
* (JAR-158) Added maximum queue time column to the *Administration->Stats* view.
* (JAR-159) Added the ability to calculate machine statistics within a time of day range in hours, in the *Administration->Stats* view.
* (JAR-4645) Fixed bug where non-administrative team user was able to see the project editor in the *Account->Projects* view.
* (JAR-4653) Fixed AWS EFA container address in GovCloud deployments to use the appropriate zone.
* (JAR-4667) Fixed bug where portal *Dashboard* view was not updating when only job substatus changed.

## 3.21.9-1.202109301638

* (JAR-153) Fixed bug with `%VNAME%` substitution in AppDefs and shared vaults.
* (JAR-160) Added average queue time granularity around infrastructure, limits, and licensing in the downloadable CSV report from the *Administration->Stats* view.
* (JAR-4576) Fixed bug with size field when cancelling PVC vault creation for users in the *Administration->Users* view.
* (JAR-4585) Fixed portal reload on version update.
* (JAR-4587) Fixed bug with checkbox state for not encoding generated passwords as URLs in the *Account->Team* view.
* (*contributed*) Added AWS AS tags for resources. When scaling from 0 the AS needs resources called out as tags to know they are present on the AS group. This should solve for that.

## 3.21.9-1.202109171659

* (JAR-102) Fixed bug where `jarvice-license-manager` was not taking existing project license requests into account when limiting license features by project.
* (JAR-4482) Fixed bug where vault creation from *Administration->Users* left a stray comma on access modes when canceled.
* (JAR-4496) Fixed verbiage in project selection for team admins to show blank entry rather than "no project".
* (JAR-4500) Added configuration GUI for `jarvice-license-manager`, in the *Administration->License Manager* view.
* (JAR-4501) Changed the best practice for configuring `jarvice-license-manager` to GUI from *configMap*.
* (JAR-4541) Added the ability to report on users with access to specific zones via the *Administration->Users By Zone* view.
* (JAR-4542) Added support for AWS GovCloud regions via TerraForm deployments.

## 3.21.9-1.202108181638

* (JAR-113) Improved object cleanup upon user deletion; note that deleting users **is not** considered a best practice.
* (JAR-116) Added automatic "long-running job" notifications; see [Long-running Job Notification Configuration](LRJ.md) for details on how to enable and configure this feature.
* (JAR-123) Added *About* page in portal with version information for ordinary users, and additional license information for system administrators.
* (JAR-4484) Ensure all user account creation failures clean up any intermediate data.
* (JAR-4496) Improved clarity for team admin project selection.

## 3.21.9-1.202107211903

* (JAR-87) Added support for system-wide notifications on user logins, using the *NOTIFICATIONS* button in the *Administration->Users* view.
* (JAR-122) Added detailed file listing and sorting in the file picker for workflows with file inputs.
* (JAR-4395) Fixed bug with SAML assertions and Ingress.
* (JAR-4420) Made `/dev/infiniband/rdma_cm` optional for passthrough using the `jarvice-rdma-device-plugin` DaemonSet.
* (JAR-4422) Added support for passing environment variables into application containers via machine definition, using the `$<key>=<value>` pseudo-device type.  See the [Devices](Configuration.md#devices) section in *JARVICE System Configuration Notes* for details.

## 3.21.9-1.202107121913

* (JAR-4385) Validated support for in-container MPI fabric detection and environment preparation, along with platform-provided Open MPI, `libfabric`, and `rdma-core` stack.  Please see [Configuring for MPI Applications](Configuration.md#configuring-for-mpi-applications) in *JARVICE System Configuration Notes* (for system administration), and [MPI Application Configuration Guide](https://jarvice.readthedocs.io/en/latest/mpi/) (for application development), for details.

## 3.21.9-1.202107071928 *(TECHNOLOGY PREVIEW RELEASE)*

* (JAR-96) Allow in-container identity to inherit multiple group membership from host-bound `/etc/group` file, if configured. See [Advanced: Applying Multiple Group Membership to Users](Identity.md#advanced-applying-multiple-group-membership-to-users) in *In-container Identity Settings and Best Practices* for details.
* (JAR-4294) In-container MPI fabric detection and environment preparation, along with platform-provided Open MPI, `libfabric`, and `rdma-core` stack.  Please see [Configuring for MPI Applications](Configuration.md#configuring-for-mpi-applications) in *JARVICE System Configuration Notes* (for system administration), and [MPI Application Configuration Guide](https://jarvice.readthedocs.io/en/latest/mpi/) (for application development), for details.

## 3.21.9-1.202106231923

* (JAR-163) Fixed possible race condition in `jarvice-pod-scheduler` with pod binding, as well as recovery from legitimate pod binding failures not resulting in automatic job termination.
* (JAR-4327) Fixed bug in portal that didn't show a user's default vault in the *Administration->Users* view's *VAULTS* dialog.
* (JAR-4361) Fixed bug in portal with row selection not being shown properly in the *Administration->Metadata* view.

## 3.21.9-1.202106161847

* (JAR-214) Fixed bug where cloning a job after an application's AppDef changed could cause a browser hang.
* (JAR-4279) Added automation for ingress using certificates and/or external DNS in Terraform deployments.  See [Ingress TLS certificate configuration](Terraform.md#ingress-tls-certificate-configuration) and [Ingress DNS configuration](Terraform.md#ingress-dns-configuration) for details on the available options.
* (JAR-4292) Fixed inconsistent state bug in task builder optional checkbox to use the first file name parameter as the job label.
* (JAR-4293) Added support for `devshm`, `hugepages2mi`, and `hugepages1gi` pseudo-devices, as well as `CAP_SYS_PTRACE` for running jobs in order to better support certain MPI fabrics and modes.  See [Devices](Configuration.md#devices) in *JARVICE System Configuration Notes* for details.
* Amazon Elastic Fabric Adapter (EFA) support in the EKS provider for Terraform.  See example in the `eks` `compute_node_pools` section of [terraform.tfvars](terraform/terraform.tfvars) for details on how to enable.  Note that using EFA requires setting either `hugepages2mi` or `hugepages1gi` to take advantage of huge pages in the corresponding JARVICE machine definition.

## 3.21.9-1.202104281919

* (JAR-108) Allow team administrators to optionally set per-user CPU limits rather than team-wide CPU limits in the *Account->Limits* view.
* (JAR-4205) Allow system administrators to edit ephemeral vaults in order to change zone in the *Administration->Users* view.
* (JAR-4242) Added optional `vault` parameter to the `/jarvice/machines` public API call, in order to return lists of machines that are compatible (by zone) with specific vaults.  See [The JARVICE API](https://jarvice.readthedocs.io/en/latest/api/#jarvicemachines) for details.
* (JAR-4245) Removed empty black box for jobs that are queued in the *Dashboard* view.

## 3.21.9-1.202104192100

* (JAR-4236) Fixed job submission regression when not using `jarvice-idmapper`.

## 3.21.9-1.202104151840

* (JAR-105) Full support for local Docker cache proxy for system and most application containers. See [Docker registry proxy/cache (`jarvice-registry-proxy`)](README.md#docker-registry-proxycache-jarvice-registry-proxy) for details.
* (JAR-110) Added new *Dashboard-By Label* view in portal to view and act on running jobs grouped by label (when labels are specified during job submission).
* (JAR-4125) Fixed bug where PVC vault subpath substitutions (e.g. `%IDUSER%`, etc.) were incorrect when sharing vaults between users in a team.

## 3.21.9-1.202104011842

* (JAR-4124) Reduced the number of runtime tail and screenshot requests from the portal to only the app cards visible in view at any given time.
* (JAR-4126) Added pagination, filtering, and column search to *Administration->Metadata* view.
* (JAR-4165) Fixed bug with downloading job output from the *Dashboard->History* view.

## 3.21.9-1.202103171856

* (3073) Support for parallel authorized application synchronization from `/jarvice/apps` endpoint in `jarvice-api` (EXPERIMENTAL)
* (4048) (4049) Support for per-tenant (payer) storage configuration overrides for default persistnet and ephemeral PVC vaults.  See [Other Topics](Storage.md#other-topics) in *User Storage Patterns and Configuration* and [Zone Isolation](MultiTenant.md#zone-isolation) in *JARVICE Multi-tenant Overview* for additional details.
* (4050) Added new *Administration->Metadata* view in portal to manage user metadata keys.
* (4052) (4053) (4057) Support for optionally using S3-based object storage to host job output rather than database.  See [Using an External S3-compatible Object Storage Service for Storing Job Output](S3.md) for details.
* (4087) Fixed bug when pulling containers with multiple path elements in their address (e.g. `xyz.io/bucket/name/repo` versus `xyz.io/name/repo`)

## 3.21.9-1.202103031953

* (4023) Support for using a gcr.io registry proxy for JARVICE system and DaemonSet containers, in order to reduce network downloads on large clusters; see [Docker registry proxy/cache](README.md#docker-registry-proxycache-jarvice-registry-proxy) for details on how to configure.
* (4047) Fixed portal bug where cloning jobs was not including any wall time values from the *OPTIONAL* parameters in the Task Builder.

## 3.21.9-1.202102222036

* (1211) Updated React.js components on the front-end.
* (3710) Support for port range settings in AppDefs, for exposing non-standard ports on *LoadBalancer* services.  See the `ports` parameter in the [commands Object Reference](https://jarvice.readthedocs.io/en/latest/appdef/#commands-object-reference) for details.
* (3711) Support for external services (e.g. for static IP address support for jobs), as documented in [Using External Services for Interactive User Jobs](ExternalService.md).
* (3760) Kubernetes 1.19 support.  See [Kubernetes Support](#kubernetes-support) for the latest list of supported Kubernetes versions.
* (3964) Future support for Docker registry cache proxy for JARVICE service containers and apps.
* (4001) Fixed bug in portal where *PushToCompute* application endpoints would fail after updating AppDefs.
* (4008) Fixed scheduler bug in Kubernetes versions greater than 1.17 when encountering non-JARVICE *ConfigMap* objects in jobs namespace (e.g. *RootCAConfigMap* feature).

## 3.21.9-1.202102032013

* (2471) Fixed build and pull confirmation dialog boxes in *PushToCompute* view to include remotely accessible URLs that can be copied and used outside of portal; this "public" URL defaults to the `jarvice_api.ingressHost` (and associated `jarvice_api.ingressPath` value if applicable), but can be overridden with the `jarvice_mc_portal.env.JARVICE_API_PUBLIC_URL` value as well.
* (3680) Moved CSS into main portal site to avoid rare rendering issues if CSS cannot be loaded.
* (3891) Support for traditional HPC queues and submission clients; please see [nimbix/jarvice-hpc](https://github.com/nimbix/jarvice-hpc) on GitHub for details.
* (3909) Added ability to prevent interactive jobs from requesting *LoadBalancer* service addresses, as a downstream cluster setting, to avoid infinite queuing on clusters without LB capabilities, by setting `jarvice.JARVICE_JOBS_LB_SERVICE=never`; see [Using an Ingress controller for jobs](README.md#using-an-ingress-controller-for-jobs) for more details on this setting.
* (3910) Added feature to allow users to explicitly request an *LoadBalancer* IP address in the task builder's *OPTIONAL* tab, if the target cluster supports it, in order to allow inbound connections from protocols other than HTTP(S) via Ingress; note that this option is simply a hint for the target cluster, and may be ignored if *LoadBalancer* requests are forbidden on it (see above).
* (3950) Fixed API authentication issue.

## 3.0.0-1.202101202004

* (3391) (3917) Future support for traditional HPC queues and submission clients.
* (3609) Fixed file locking failure when using dynamic filer and RWO PVC vaults; note that distributed locking is not supported, and this storage type should be used with caution.
* (3781) License-based job queuing support.  See [JARVICE License Manager](LicenseManager.md) for details.
* (3838) Fixed `jarvice-dri-optional` DaemonSet to work properly on certain infrastructure where host drivers are not loaded before the Kubernetes kubelet is (e.g. Google GKE).

## 3.0.0-1.202101062006

* (3841) Fixed bug where refreshing users prevent row selection in *Administration->Users*

## 3.0.0-1.202012232023 - *(TECHNOLOGY PREVIEW RELEASE)*

* (3290) Finalized architecture updates in `jarvice-dal` for performance, security, and scalability.
* (3557) Documented known issue relating to linked PVC vaults; see [General](#general-1) in *PersistentVolume Vaults* under *Known Issues, Anomalies, and Caveats* for details.
* (3763) Fixed inconsistent state issues with optional use of file name as job label in portal task builder.
* (3767) Support for GPU-enabled node groups in AKS and GKE; note that GPU use on GKE is considered experimental at this time.
* (3773) Fixed bug in portal allowing blank date range selection in *Administration->Stats* view.
* (3790) Minor internal optimizations in `jarvice-pod-scheduler`.
* (3792) Use path-based ingress by default in EKS, GKE, and AKS deployments via Terraform.
* (3830) Fixed bug in *Vaults* dialog box under *Administration->Users* view related to opening successive user vaults.
* (3831) Fixed bug with clearing user search box in *Administration->Users* view.

## 3.0.0-1.202012092030 - *(TECHNOLOGY PREVIEW RELEASE)*

* (3187) Default to using mariadb rather than mysql for `jarvice-db` service.
* (3282) (3288) (3295) (3764) Architecture updates in `jarvice-dal` for performance, security, and scalability.
* (3678) Avoid bundling development components in `jarvice-mc-portal` service.
* (3712) New `jarvice-dri-optional-device-plugin` DaemonSet, deployed by default, to facilitate hardware accelerated 3D offload without requiring privileged security context for containers leveraging this feature.
* (3713) Rearchitected 3D offload feature to leverage `jarvice-dri-optional-device-plugin` DaemonSet and avoid using privileged security context for applications requesting the `egl` pseudo-device; this feature is now GA; for additional details please see [Accelerated 3D Remote Display Capabilities](3D.md).
* (3714) Use GPU-capable AMI on x86 EKS deployments by default.
* (3754) Fixed spurious JS console error when closing task builder in portal.
* (3757) Implemented horizontal pod autoscaler support in `jarvice-api`, `jarvice-dal`, and `jarvice-mc-portal` services for high CPU and memory pressure situations.

## 3.0.0-1.202012012257

* (2532) EXPERIMENTAL Technology preview for 3D offload using EGL on NVIDIA Kepler (or newer) class GPUs and driver version 450 or newer; use the `egl` pseudo-device in the machine definition to enable, but note that this currently implies `privileged`; **use with extreme caution and for testing purposes only**
* (3191) Support for MariaDB as well as MySQL in deployments by setting `jarvice_db.image` to `mariadb:10.5` in either the Helm or Terraform overrides; note that this is certified for new deployments only, and should not (yet) be changed for existing deployments or risk data corruption.  Also note that this is required for `arm64` deployments as official MySQL images are not available for that architecture.
* (3604) Added initial support for project management features in the *Account->Projects* view.
* (3654) Official support for AArch64 (`arm64`) architecture for both control plane and compute/apps.  For additional information on AWS deployment, see [Arm64 (AArch64) cluster deployment](Terraform.md#arm64-on-aws) in *JARVICE Deployment with Terraform*.
* (3668) Moved JARVICE DaemonSet container images to `gcr.io/jarvice` bucket to avoid issues with *DockerHub* limits and throttling.
* (3672) Require explicit selection of projects for users with more than one project defined in the portal task builder.
* (3673) Added project attribute reporting in team and system administration usage reports.
* (3675) Increased utilization of multi-node jobs when using fractional nodes as defined in machine definitions; `jarvice-pod-scheduler` now packs these pods, if possible, rather than spreading them across multiple worker nodes by default.
* (3706) Fixed bug where multiple properties in a machine definition were not being reflected as node selectors in jobs running on those machine types.

## 3.0.0-1.202011121727

* (3703) Fixed portal regression that prevented successfully cloning jobs from history.

## 3.0.0-1.202011112040

* (2831) Selective systemwide relaxation of warnings related to jobs submitting other jobs; set `jarvice_mc_portal.env.JARVICE_DISABLE_API_SUBST_WARNING` to any non-empty value in order to disable these warnings on job submission for any app that uses the `%APIKEY` substitution in its parameters.
* (3603) (3605) (3606) Future architecture support for project management for users and jobs.
* (3654) **EXPERIMENTAL** AArch64 (arm64) support for compute and downstream clusters; general JARVICE control plane support will be available in a subsequent release.
* (3655) Fixed button wrapping in *Administration->Users* view in the portal.
* (3666) Fixed typo in default cluster environment setting in `jarvice-dal`.
* (3679) Fixed race condition in `jarvice-scheduler` when deleting orphaned jobs downstream which was leading to jobs occasionally being deleted while still starting.

## 3.0.0-1.202010282029

* (2845) Added optional checkbox in portal task builder to automatically populate the job label with the value of the first selected input file, if any.
* (3389) (3390) Job scheduler evolution for future functionality.
* (3394) Full support for multi-tenant isolation of job pods as well as networks.  See [JARVICE Multi-tenant Overview](MultiTenant.md) for details.
* (3399) JARVICE XE system pod resource and replica adjustments, as well as scaling guide.  See [Resource Planning and Scaling Guide](Scaling.md) for details.
* (3479) Paginated view for *Administration->Users*, including advanced filtering options.
* (3555) Added *REFRESH* button to file picker in task builder to reload the current directory view.
* (3558) Fixed bug with *Account->Team Apps* view that would leave the portal unresponsive if managing users with previously deleted applications.
* (3559) Added timeout on certain runtime status calls into running jobs to work around possible Docker engine bugs on running containers.

## 3.0.0-1.202010212159

* (1498) Added configurable node resource weight multipliers settable via `${JARVICE_POD_SCHED_MULTIPLIERS}`, as a JSON dictionary; note that any resource not named there defaults to a weight of `1`.  See the value setting in [values.yaml](values.yaml) for an example to account for minor variance in node/instance capacities.
* (3596) Fixed browser clipboard compatibility in web portal when using HTTP protocol rather than HTTPS, and attempting to copy user signup invitations to clipboard.

## 3.0.0-1.202010141909

* (2955) Improved file picker performance when using PVC vaults by keeping lister pods running for up to 90 seconds of inactivity.
* (3158) Fixed bug in portal that prevented system administrator users from immediately launching apps created in their *PushToCompute* view.
* (3393) Experimental support for tenant network isolation by payer using and managing *NetworkPolicy* objects automatically.  Documentation to follow in future releases.
* (3470) Added helper example script and information for deploying "EFK" stack in order to archive JARVICE component logs.  See [Deploy "EFK" Stack](README.md#deploy-efk-stack) for details.
* (3516) Added automatic garbage collection for orphaned jobs not known upstream (e.g. partially configured jobs due to API/connectivity failures, etc.).

## 3.0.0-1.202009301931

* (2952) Added task builder hint to preselect a specific user vault for any given AppDef workflow, if available, using the `VAULT:<name>` format; please see *User-interface Hinting* in the [Application Definition Guide](https://jarvice.readthedocs.io/en/latest/appdef/#user-interface-hinting) for details.
* (3083) Fixed bug in *PushToCompute* app target editor that would show a recently created app's icon when editing a different app.
* (3148) Allow user account registration links to be optionally copied to clipboard rather than requiring email, for both system administrator invites as well as team administrator invites.
* (3149) Allow users to reset their passwords in the *Account->Profile* view from a logged in session, in addition to the password reset email from the login screen method.
* (3241) Fixed bug where occasionally queued jobs would run out of order once resources became available.
* (3398) Support configurable liveness and readiness problems in Helm Chart via the `*.readinessProbe` and `*.livenessProbe` sections in the YAML.
* (3402) Fixed bug where system administrator-initiated email invitations would leave the dialog box open after sending.
* (3405), (3406), (3407) Optimized vault file listing architecture, and eliminated the need to run `jarvice-dal` pods with `privileged` security context.
* (3415) Optimized job output download for completed jobs in portal.
* (3452) Fixed bug where email was not being sent for *PushToCompute* builds from the Nimbix Cloud.
* (3455) Fixed bug where `jarvice-pod-scheduler` would erroneously count completed or failed pods as consuming resource on nodes, artificially reducing said nodes' capacity to run jobs.
* (3466) Optimized job status mechanisms to perform much faster with large numbers of jobs pending.
* (3468) Changed `imagePullPolicy` to `IfNotPresent` for JARVICE system containers as well as `init` if using versioned tags by default.  Job-related application containers still default to `Always` policy, but can be overridden with the `jarvice.JARVICE_JOBS_IMAGE_PULL_POLICY` parameter in the Helm Chart.


## 3.0.0-1.202009041653

* (3453) Improved parallel job startup synchronization.

## 3.0.0-1.202009021933

* (3239) Fixed bug where portal would malfunction if cloning a job which referred to a previously deleted app.
* (3273) Fixed bug with password encoding for RealVNC servers when accessed directly with VNC clients rather than HTTPS.
* (3276) Fixed API status codes for failures.
* (3286) Improved performance of "high frequency" operations and reduced `jarvice-dal` bottlenecks associated with them (e.g. job utilization metrics updates, screenshots, output tail).
* (3332) Fixed bug where unprepared interactive containers (without `image-common` installed) would be inaccessible when using AWS ELB.
* (3341) Added billing reports by zone to the web portal's *Administration->Billing* view, as well as the API's `/jarvice/billing` endpoint.
* (3345) Documented best practices for deploying Kubernetes and JARVICE XE on systems with SELinux in `enforcing` mode; please see [SELinux](KubernetesInstall.md#selinux) in *Kubernetes Cluster Installation*, as well as [SELinux Configuration for JARVICE](SELinux.md) (for job-related configuration) for details.
* (3379) Added experimental support for returning a job's randomly generated public SSH key upon submission using the `gen_sshkey` boolean parameter in the `/jarvice/submit` payload.  This can be added to `.ssh/authorized_keys` on the client to allow the remote session to SSH back to it for workflows where this pattern makes sense.
* (3413) Allow system-level override of in-container UID/GID in downstream schedulers; see [Advanced: Overriding Identity UID/GID System-wide Downstream](Identity.md#advanced-overriding-identity-uidgid-system-wide-downstream) in *In-container Identity Settings and Best Practices* for details, but please use with caution and consider Known Issues for [Downstream Deployments](#downstream-deployments)!

## 3.0.0-1.202008191936

* (3194) GA Support for GKE and EKS using Terraform; please see [JARVICE Deployment with Terraform](Terraform.md) for details.
* (3269) Added PodDisruptionBudget to JARVICE job, build, and pull pods to avoid eviction when draining nodes.
* (3272) Added `%CONNECTURL%` substitution in app container help text/html for better compatibility with Ingress.
* (3278) Removed deprecated internal image code from DAL.
* (3293) Fixed bug in portal that would render dialog boxes without values after cancelling a confirmation.
* (3297) Experimental support for Kerberos logins to the potral; see [documentation](Kerberos.md) for details.
* (3329) Support for *LoadBalancer* service annotations in downstream scheduler; see [Additional LoadBalancer service annotation for jobs](README.md#additional-loadbalancer-service-annotation-for-jobs) for details.
* (3333) Updated job and UNFS3 pod tolerations to support the new `node-role.jarvice.io` domain.
* (3343) Security update for self-service team admin-initiated user invites in portal.

## 3.0.0-1.202008051905

* (3182) Experimental (undocumented) support for EKS using Terraform.
* (3243) Fixed regression with LoadBalancer-only (no ingress) clusters that prevented jobs from being submitted due to a scheduler error.

## 3.0.0-1.202007221912

* (3133) Updated Kubernetes support statement; see [Kubernetes Support](#kubernetes-support) for details.
* (3230) Improved handling of jobs with unknown status in scheduler, which was leading to auto-cancellation of queued jobs.

## 3.0.0-1.202007092149

* (3216) Fixed missing `%VNAME%` substitution in AppDef `CONST` parameters.

## 3.0.0-1.202007081950

* (3080) Added `/jarvice/teamusers` API endpoint for a team admin to query a list of users on the team (other than his/herself); please see [The JARVICE API](https://jarvice.readthedocs.io/en/latest/api/) for details.
* (3140) Added the ability to disable the use of `systemd` in application containers, to better support SELinux "enforcing" mode environments; please see [SELinux Configuration for JARVICE](SELinux.md) for details.
* (3141) Added the ability to override scheme and/or port for job ingress URLs on the front-end; please see [Custom Ingress URLs for Jobs](Ingress.md#custom-ingress-urls-for-jobs) in *Ingress Patterns and Configuration* for details.
* (3192) Added support and documentation for "air gapped" network deployments; please see [Air gapped Network Deployment](AirGapped.md) for details.

## 3.0.0-1.202006242047

* (2870) Updated documentation for multi-zoned deployments.  Please see [JARVICE Multi-cluter Overview](MultiCluster.md) for details.
* (3074) Added concurrency and request timeout limits to the API endpoints.  See [JARVICE API](#jarvice-api) in *Known Issues, Anomalies, and Caveats* above for configuration information.
* (3084) Eliminated redundant AJAX call from web portal when applications were edited in the *PushToCompute* view.
* (3121) Fixed regression in web portal when apps were reloaded in the *PushToCompute* view.
* (3124) Fixed regression in web portal that prevented team admins from inheriting the *SAML/LDAP Admin* role.
* (3129) Fixed regression in web portal that caused login events to be audit logged on page refreshes.
* (3142) Fixed web portal to sort user names in alphabetical order in drop downs involving limits and app restrictions.
* (3144) Fixed bug where system administrators could only query events for active jobs they submitted.
* (3147) Fixed bug where shared vaults could prevent users from accessing apps and machines in the default zone.

## 3.0.0-1.202006111530 (BETA)

* (2775) Added ability to selectively disable SSL certificate verification for downstream clusters via *Administration->Clusters*
* (2864) Modernized `jarvice-k8s-scheduler` component
* (2872) Added multi-zone support for the portal
* (2997) Updated recommended labels/taints to use a value of `"true"` in the Helm chart
* (3008) Fixed misleading error message on failed image pulls when using *PushToCompute* pull functionality
* (3010) Added `%MACHINETYPE%` substitution for `CONST` values in AppDefs, to extract the machine type used for job submissions.  See *Parameter Type Reference* in the [JARVICE Application Definition Guide](https://jarvice.readthedocs.io/en/latest/appdef/) reference for details.
* (3020) Fix routing of vault file listing to clusters in downstream zone; see General PersistentVolume vault [Known Issues](#general-1) for important information.
* (3021) Corrected all known issues and specification mismatches with modernized `jarvice-api` component
* (3056) Improved parsing of Docker container addresses and fixed bugs related to private registries with ports when using *PushToCompute* pull functionality
* (3064) Fixed portal regression that prevented automatic app catalog refreshes when changes were detected
* (3086) Removed `jobsub` JSON key from `/jarvice/teamjobs` API endpoint

## 3.0.0-1.202005272025

* (2866) Modernized `jarvice-scheduler` component.
* (2867) Modernized `jarvice-api` component.  **WARNING: direct use of the JARVICE API in this release may not match the specification entirely.**
* (2868) Modernized `jarvice-dockerbuild` component.
* (2869) Modernized `jarvice-dockerpull` component.
* (2879) Added Zone editor in the *Administration* section of the portal.  **NOTE:** full multi-zone functionality will be available in a future release.
* (2932) Improved performance of user logouts from the portal.
* (2953) Added `/jarvice/billing` endpoint in the JARVICE API for system administrator users.  See [The JARVICE API](https://jarvice.readthedocs.io/en/latest/api/) reference for details.
* (2991) Allow configuration of control plane nodes for Azure deployments via Terraform; see [JARVICE deployment with Terraform](Terraform.md) for details.
* (2994) Allow configuration of multiple compute node groups for Azure deployments via Terraform; see [JARVICE deployment with Terraform](Terraform.md) for details.
* (3009) Improved performance of liveness checks in system services, including reduction of unnecessary pod restarts.

## 3.0.0-1.202005151836

* (2998) Fixed regression in the per-user audit log under *Administration->Users* view.

## 3.0.0-1.202005131926

* (2871) Allow in-place editing of vault objects in the *Administration->Users* view.
* (2878) Modernized `jarvice-pod-scheduler` component.
* (2880) Official support for Microsoft Azure as either standalone or downstream platform, using Terraform deployment mechanism; see [JARVICE deployment with Terraform](Terraform.md) for details
* (2928) Fixed rendering bug in task builder where *Submit* button was obscured at lower resolutions.
* (2964) Fixed `/jarvice/jobs` API endpoint to not return downstream scheduler-specific job submission data.

## 3.0.0-1.202004292028

* (2719) Real-time scheduler events and job output available in the *Active Jobs* status filter of the *Administration->Jobs* view.
* (2832) Portal warns if files with special characters in them, such as spaces, are selected for workflows with file parameter(s), as this can cause applications to behave incorrectly or fail.
* (2833) Security fix to prevent web server directory listing in browser for interactive jobs using noVNC.
* (2858) (2859) (2876) Zoned vault model support for future functionality.
* (2860) (2861) API validation of vault and machine selection for zone compatibility.
* (2862) Removed legacy vault type support from the *Vaults* dialog in *Administration->Users*, and added zone affinity selection for new vaults.
* (2863) Modernized `jarvice-appsync` component, including standardized logging.
* (2917) Fixed regression preventing copy of job session passwords for interactive jobs to clipboard.

## 3.0.0-1.202004151913

* (2534) Fixed bug where a user logging into the portal that had previously navigated to a page that is no longer authorized, would get a blank page.
* (2602) Gray out SAML/LDAP admin role in the role editor under *Administration->Users* for any non-payer user, since this is inherited from the team payer account if set.
* (2659) Ensure *JARVICE File Manager* is enabled by default when creating rules in the *Account->Team Apps* view.
* (2718) Added underlying job submission data to job inspection popup in the *Administration->Jobs* view.
* (2760) Standardized logging for upstream and downstream schedulers now released, no longer future functionality (re: 2763)
* (2764) Fixed bug where job connection parameters including password would be shown in the dashboard for non-interactive jobs on systems using Ingress.
* (2765) Added IP address assignment audit logging for containers in the *Administration->Logs* view.
* (2774) Added configurable timeouts for downstream scheduler endpoints via the `jarvice_scheduler.JARVICE_SCHED_CLUSTERS_TIMEOUT` value in `values.yaml`.

## 3.0.0-1.202004062122

* (2843) Fixed frequent `OOMKilled` pull pod failures (e.g. `jarvice-system-pulls` namespace), which were preventing container pulls from the *PushToCompute* tab to complete.
* Patched minor regression in system and team audit log views related to sorting and category selection.

## 3.0.0-1.202004012010

* (2474) Improved LDAP error reporting when using the *TEST* button in the *Account->LDAP* view; see the troubleshooting section in [Active Directory Authentication Best Practices](ActiveDirectory.md#troubleshooting-ldap-login-failures) for details.
* (2611) Added downstream cluster configuration interface in web portal in *Administration->Clusters* view.
* (2612) Internal scheduler service and deployment updates for future capabilities
* (2613) Added downstream cluster deployment mechanisms in Helm chart; see [JARVICE Downstream Installation](README.md#jarvice-downstream-installation) for details.
* (2614) Added downstream cluster deployment automation for EKS and GKE; see "downstream" settings in the respective YAML files for these deployments.
* (2715) Added Active Jobs mode in *Administration->Jobs* view and the ability to terminate all jobs on page via the *TERMINATE ALL* button.
* (2725) Updated multicluster documentation in [JARVICE Multi-cluter Overview](MultiCluster.md)
* (2728) Fixed bug in web portal where cloning a job with an upload parameter would hang the session.
* (2761) (2762) Standardized logging for upstream scheduler (future feature to be released).
* (2763) Standardized logging for downstream scheduler (future feature to be released).

## 3.0.0-1.202003200237

* (2728) Fixed bug where cloning a job in the dashboard with UPLOAD parameters in the AppDef would hang the browser session.

## 3.0.0-1.202003181900

* (2525) Fixed bug where logout on password reset using path-based ingress resulted in a 404 error
* (2609), (2610), (2657) Internal scheduler service and deployment updates for future capabilities
* (2660) Support for new `UPLOAD` parameter for AppDefs to allow small files to be uploaded as part of job submission; please see the *`parameters` Object Reference* in the [JARVICE Application Definition Guide](https://jarvice.readthedocs.io/en/latest/appdef/#reference) for details.

## 3.0.0-1.202003041950

* (2594), (2605), (2606), (2607) Internal scheduler service and data model updates for future capabilities

## 3.0.0-1.202002202201

* (2589) Fix spurious logouts in the web portal when impersonating users as system or team administrators

## 3.0.0-1.202002192205

* (2460) Fixed bug where resource limits combining both total CPUs and specific machine types were not being enforced correctly
* (2475) Fixed web portal to not attempt to enforce password policy for LDAP logins, since this should be handled by the LDAP server itself
* (2480) Fixed bug with erroneous data in the per-user audit log in *Administration->Users*
* (2524) Fixed bug where portal was not allowing team administrators to edit LDAP and SAML settings unless they were actually the team payer
* (2533) Significant performance improvements to explicit Docker pulls in JARVICE XE, especially if images are also built by JARVICE
* (2583) Restored email sending functionality in web portal with default (built-in) SMTP server settings; JARVICE now runs an SMTP pod as a deployment within the Helm chart
* (2598) Fixed regression in web portal that prevented itemized billing reports from working

## 3.0.0-1.202002102104

* (2588) System-wide healthcheck performance optimization

## 3.0.0-1.202002051613

* (2210), (2211), (2212), (2481), (2482) Internal scheduler service updates for future capabilities
* (2371) Internal portal web service architecture updates
* (2377) Support for suppressing random passwords from job URLs (e.g. for remote desktop and for File Manager); configurable by team admins in the *Account->Team* view
* (2381) Vault info dialog shows more detail when inspecting vaults for users from the *Administrator->Users* view
* (2382) System creates an ephemeral vault by default for all new user accounts (whether invited explicitly or generated implicitly by LDAP or SAML login); if a default PVC vault is specified using `jarvice.JARVICE_PVC_VAULT_*` variables in [values.yaml](values.yaml), it will be created for all new user accounts in addition to the ephemeral one, and will be made default
* (2383) NetworkPolicy fixes for JARVICE services
* (2412) JARVICE File Manager updated to support path-based ingress
* (2423) JARVICE File Manager updated to support suppressed random session password in connection URLs
* (2429) Fixed "No such user" error if payer is not selected when saving limits in the *Administration->Limits* view
* (2456) Fixed bug in portal where apps with multiple file selectors for the task builder with different wildcards were not properly filtering listed files
* (2464) Added ability to remove team app restrictions as user overrides in the *Account->Team Apps* view; removing restrictions also enables the *PushToCompute* mechanism and allows users to build and run their own apps even in teams with restrictive default app rules
* (2528) Fixed bug in API triggered by commands with `BOOL`-type parameters presented as variables in AppDefs


## 3.0.0-1.201912212002

* (2208), (2209) Internal scheduler service updates for future capabilities
* (2215) Support for Kubernetes 1.16
* (2264) Support for subpath (including substitutions) in PVC vaults; see [User Storage Patterns and Configuration](Storage.md) for details and best practices
* (2273) Fixed bug where container pull email notifications were not being sent
* (2324) Full support for path-based ingress; see [Ingress Patterns and Configuration](Ingress.md) for details and best practices
* (2325) Path-based ingress support for Jupyter notebooks by setting `--NotebookApp.base_url=%BASEURL%`; see [nimbix/appdef-template in GitHub](https://github.com/nimbix/appdef-template) for example, or use [nimbix/notebook-common in GitHub](https://github.com/nimbix/notebook-common) for a standard pattern to create Jupyter-based application environments with
* (2326) RDMA device plugin for Kubernetes updates for 1.14 and newer
* (2338) Fixed bug where page refresh was generating additional user login audit log entries

## 3.0.0-1.201912042137

* (1938) Updated open source AppDef templates and tutorials available in [GitHub](https://github.com/nimbix/appdef-template)
* (2192) Initial [JARVICE Troubleshooting Guide](Troubleshooting.md)
* (2195) Added `ping` and `telnet` utilities to aid in pod-to-pod network troubleshooting in all system containers
* (2206) Internal scheduler service updates for future capabilities
* (2220) Experimental path-based ingress support (see `ingressPath` and `JARVICE_JOBS_DOMAIN` settings in [values.yaml](values.yaml)); note that this may not be compatible with all workflows
* (2258) Fixed bug where the portal was expanding wildcards in the `machines` key in the AppDef JSON when editing a target in the *PushToCompute* view
* (2271) Added real-time search box to file picker in the task builder for applications with file arguments
* (2274) Expanded width of user account variables editor in the *Administrator->Users* view, to better support long account variable names without wrapping
* (2276) Fixed minimum browser window "inner-height" to be 722 pixels, which is equivalent to 1920x1080 maximized browser window at 125% zoom; note that using higher zoom levels, lower resolution screens, or smaller browser windows may truncate some advanced interfaces (e.g. app editing in the *PushToCompute* view)
* (2277) Added veritcal scrollbar where needed on both side drawers rather than truncating options
* (2288) Added user login and logout events in team and system audit logs

## 3.0.0-1.20191115.2245

* (1936) Open source AppDef templates and tutorials available in [GitHub](https://github.com/nimbix/appdef-template)
* (2193) Support for deploying database volume on root-squashed NFS storage (see `jarvice_db.securityContext` in [values.yaml](values.yaml))
* (2196) Documented [User Storage Patterns and Configuration](Storage.md)
* (2197) Internal scheduler service updates for future capabilities
* (2202) Fixed bug with leading and/or trailing whitespace in account variables
* (2207) Updated documentation for Helm 3 and added comprehensive table of contents
* (2219) Ability to remove and download screenshots and EULAs from large app card
* (2221) Added new AppDef substitutions for command parameters - See examples in [GitHub](https://github.com/nimbix/appdef-template) for information on consuming these
* (2256) Platform support for Xilinx XRT 2.3 in Nimbix Cloud

## 3.0.0-1.20191101.2014

* (2159) Updated Helm chart for API deprecation and Kubernetes 1.14+
* (2205) Support for home directories searched by `jarvice-idmapper` using `sAMAccountName` rather than just UPN; this allows ID mapping in containers if the Linux username mappings are for legacy logons - both are supported (EXPERIMENTAL)

## 3.0.0-1.20191029.1917

* (2190) Support for shared PVC's across multiple users as vaults; can be enabled with both a storage class name and volume name at PVC vault creation time, and allows multiple users to share the same storage (EXPERIMENTAL)

## 3.0.0-1.20191026.1506

* (1932) Allow side loading of AppDefs in *PushToCompute* view's create or edit feature; note that when pulling a container that embeds `/etc/NAE/AppDef.json`, this will automatically replace any sideloaded AppDef
* (1934) Allow side loading of AppDefs for app owners when clicking on an app; button appears in the bottom right hand corner of the large app card; note that when pulling a container that embeds `/etc/NAE/screenshot.png`, this will automatically replace any sideloaded screenshot
* (2037) Minor audit log cosmetic improvements for system and team admins
* (2077) PushToCompute app change refresh fixes
* (2113) Support for user account email addresses with long TLD's (up to 63 characters)
* (2116) Fixed bug with automatic creation of PersistentVolumeClaims in PVC vaults for users with underscores in their username
* (2117) Runtime security fix for Xilinx FPGA machine types in older versions of JARVICE

## 3.0.0-1.20191011.1301

* (1664) Self-service app management, allowing team admins to restrict what catalog apps _non-administrative_ team users have access to; available in the *Account->Team Apps* view;
* (2072) Improved appsync mechanism to not trigger deletion of local apps immediately if there are intermittent failures on authorizing remote Docker repositories due to timeouts or other HTTP errors


## 3.0.0-1.20191003.1943

* (2071) Fixed bug where `/jarvice/teamjobs` API call was not returning all team jobs when authenticating as a non-payer team admin user
* (2074) Fixed pod scheduler to prevent triggering scale-up with Kubernetes autoscalers when jobs are queued due to account limits rather than insufficient capacity
* (2112) Fixed regression in web portal that resulted in duplicate app targets created when editing existing ones in the *PushToCompute* view

## 3.0.0-1.20190925.1914

* (1986) Allow non-admin users on teams to optionally see usage and job summary for entire respective team; this must be enabled by a team payer or admin in the *Account->Summary* view; non-admin members then have visibility into an abbreviated version of *Account->Summary* for viewing current resource usage and team jobs only
* (1990) Additional audit logging for user actions via API (`/jarvice/submit`, `/jarvice/shutdown`, and `/jarvice/terminate`)
* (2029) Improved performance of server-side appsync functionality by parallelizing `/jarvice/apps` API endpoint

## 3.0.0-1.20190918.2053

* (2034) Fixed regression introduced by original fix in release `3.0.0-1.20190913.2114` where job termination and completion emails were not being sent properly

## 3.0.0-1.20190917.1813

* (2068) Fixed regression in job termination option when locking user accounts; jobs were not being terminated

## 3.0.0-1.20190913.2114

* (1910) Detect `CreateContainerError` condition on job startup and fail job appropriately; this prevents resources being held when container creation fails upon job startup
* (2034) Proper handling of job termination and cleanup when its pod(s) are deleted outside of JARVICE (e.g. using `kubectl delete pod`)

## 3.0.0-1.20190911.1715

* (1976) Fixed bug in portal where cloning jobs would result in erroneous values for different workflows
* (1989) Audit logging for end user actions, and the ability for team admins to query and filter the logs via the *Account->Team Logs* view
* (2032) Minor adjustment to container pull policy for `jarvice-dockerpull` and `jarvice-dockerbuild` containers, triggered via `/jarvice/pull` and `/jarvice/build` API endpoints, respectively

## 3.0.0-1.20190830.1317

* (1911) Kubernetes events associated with pods captured in job error output; from the *Administration->Jobs* view, clicking on a job and then clicking *DOWNLOAD STDERR* produces JSON data for each Kubernetes pod in a job; the new `events` key contains a list of events associated with each pod
* (1945) Job label, if applicable, added to job status emails

## 3.0.0-1.20190731.1533

* (1792) Report on average queue times per machine in the *Administration->Stats* view
* (1836) Fix for *Administration->Users->Vaults*  user interface hanging when there is an invalid vault defined for a user - see [Known Issues, Anomalies, and Caveats](#known-issues-anomalies-and-caveats) for details on what vaults are not valid on Kubernetes systems
* (1841) Validation of experimental web portal fix for apps with `NONE` vault type specification in AppDef; confirmed fixed

## 3.0.0-1.20190717.1614

* (1785) Support for running experimental version of web portal, which will become standard after more testing (Kubernetes only)
* Experimental web portal fix for apps with `NONE` vault type specification in AppDef

## 3.0.0-1.20190711.1435

* (1830) Prevent application of a global CPU limit below the smallest machine size possible, in terms of cores; for example, if the limit is 1, and the smallest machine defined has 2 for its `mc_cores` value, JARVICE will enforce the limit as 2 concurrent CPUs.  This applies to all levels of limits.

## 3.0.0-1.20190703.1553

* (1741) Presentation of job utilization metrics in portal; real-time CPU and memory usage are available for running jobs as a summary, and as a click-through per-node representation using the details button.  On Kubernetes, this requires the deployment of [metrics-server](https://github.com/kubernetes-incubator/metrics-server) 0.3.x or newer.

## 3.0.0-1.20190619.1923

* (1712) Job utilization metrics via API endpoint [/jarvice/metrics](https://jarvice.readthedocs.io/en/latest/api/#jarvicemetrics)
* (1738) Fixed bug where jobs queuing for a long time would show negative runtimes in the portal
* (1739) Fixed bug where cloning a job with a machine type that is no longer available would cause the web portal to hang


## 3.0.0-1.20190517.1346

* (1509) Pod scheduler now respects most node taints; optimized for JARVICE-style taints such as:

        node-role.kubernetes.io/jarvice-system:NoSchedule

* (1662) Global max CPU concurrency available for all resource limits, supported with or without whitelisted machine types and scale
* (1665) Support for impersonation of team user accounts by team admins (requires explicit opt-in from the *Account->Team* view)
* (1680) Fixed potential orphaned resources on job submission failure
* (1681) New [jarvice.com/rdma](https://github.com/nimbix/jarvice-k8s-rdma) plugin with optional automatic deployment from Helm chart; this mechanism replaces the previously recommended `tencent.com/rdma` one, and is more appropriate (and reliable) for high density/scale HPC using RDMA; certified using InfiniBand but may also support RoCE


## 3.0.0-1.20190503.1831

* (1636) Applied NetworkPolicy to JARVICE services to prevent jobs from unauthorized access to internal system components
* (1658) Ability to override DAL user account hooks via `jarvice-settings` ConfigMap
* (1659) Delayed garbage collection for shared block storage services; timeout, in seconds, controllable by `${JARVICE_UNFS_EXPIRE_SECS}` in the `jarvice-scheduler` deployment; default is 90 seconds
* (1660) Added ability for vault owners to decide which team members can access their vaults, if any
* (1663) Added extended resource request view underneath node slider in task builder

## 3.0.0-1.20190424.1834

* (1674) gcr.io conversion for system services

## 3.0.0-1.20190423.1852

* (1679) Docker registry v2 fixes

## 3.0.0-1.20190418.2203

* (1448) Support for application-defined minimum window resolution
* (1576) Support for transparent block storage sharing (ReadWriteOnce Persistent Volumes on Kubernetes)
* (1614) Support for team members sharing vaults with other team members (entire team)

## 3.0.0-1.20190409.1413

* (1619) Fixed bug that prevented `/jarvice/pull` endpoint from working correctly in some configurations
* (1644) Fixed bug where `USER` settings in Dockerfiles could prevent jobs from starting correctly; note that JARVICE ignores `USER` at runtime and instead performs its own identity management

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

