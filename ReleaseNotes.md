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

Kubernetes **1.28**; newer versions are not explicitly supported.  Using the latest patch release of each version is recommended but not required.

#### Previous Version(s) Supported

Up to 2 previous minor revisions (from the one indicated in [Latest Version Supported](#latest-version-supported)) will be supported at any given time, unless otherwise noted.  Currently this list is limited to:

* Kubernetes **1.27**
* Kubernetes **1.26**

### External S3-compatible Object Storage Service Compatibility

At the time of this writing, JARVICE supports the following service/providers:
* **radosgw** (REST gateway for RADOS object store, part of Ceph)
* AWS S3
* GCP Cloud Storage

Other providers may or may not be compatible, and are not officially supported.

---
## Known Issues, Anomalies, and Caveats

### JARVICE HPC Pod Scheduler (jarvice-pod-scheduler)

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

## 3.24.8-202409242140
* (JAR-8021) Allow Team Admin or Payer to access billing reports API
* (JAR-8131) Change Jarvice compatibility statement 1.28
* (JAR-8989) Publish API to manage External custom billing
* (JAR-9124) Create a virtual scheduler
* (JAR-9143) [KNS] Demo, documentation and apps
* (JAR-9199) [DSSR] Implement V2.1
* (JAR-9205) Logging to Object Storage not working after 3.24.3-202402282109
* (JAR-9230) [KNS] Add custom script support
* (JAR-8879) Make UI, API Changes for External custom billing
* (JAR-9265) Fix syntax issue for MYSQL
* (JAR-9195) Send mail based on user flags
  
## 3.24.7-202409101355

* (JAR-8021) Allow Team Admin or Payer to access billing reports API
* (JAR-8452) Kubernetes service DNS domain added to helm chart
* (JAR-8575) Add recently terminated jobs to active dashboard on BIRD UI
* (JAR-8609) Update Keycloak realm configuration
* (JAR-8665) Update NGINX used by bird-portal
* (JAR-8666) Replace uWSGI with gunicorn
* (JAR-8701) Encode downstream scheduler credentials
* (JAR-8825) Use JARVICE_MACHINES_ADD to populate default machines for new clusters
* (JAR-8955) Correct job output log on Firefox
* (JAR-8956) Add application license link to job builder UI
* (JAR-8960) Replace strings with translation keys for adminViewsList
* (JAR-8969) Fix job logs pane on Administration/Jobs page
* (JAR-8970) Update jarvice-idp-mapper to map '-' to '_'
* (JAR-8975) Fix Administration/Logs filter
* (JAR-8977) JARVICE support Keycloak usernames with spaces
* (JAR-8987) Update gotty shell packaged with KNS
* (JAR-9013) KNS V2 improvements
* (JAR-9060) Update UI to Angular 17
* (JAR-9073) Fix Administration/Machines "Refresh" button
* (JAR-9108) Correct setting user group permissions for v2 JARVICE applications
* (JAR-9114) Enable metrics request for KNS
* (JAR-9115) Add help message and optional app message to KNS jobs
* (JAR-9119) Change gotty shell to an optional component for KNS V2 jobs
* (JAR-9121) Optimize BIRD UI API calls
* (JAR-9125) Optimize jobList DAL call for larger databases
* (JAR-9134) Initial JARVICE integration with SMC xScale
* (JAR-9142) Fix race condition in KNS
* (JAR-9172) Update to gevent 24.2.1 

## 3.24.6-202407122022

* (JAR-7876) Customize favicon using `jarvice-settings` ConfigMap
* (JAR-8494) Make notification email RFC 5322 compliant
* (JAR-8756) Correct `Jobs Run`  in `Stats`  box on legacy portal
* (JAR-8792) Add notification to `Users` table
* (JAR-8794) Improve performance of active jobs query
* (JAR-8826) DSSR scheduler support deep identity based on Slurm API Tokens
* (JAR-8858) (JAR-8968) Add ` shib-saml ` and `fed-shib-saml` providers to JARVICE Keycloak SAML mapper
* (JAR-8859) Correct Keycloakx default values in Terraform modules
* (JAR-8863) JARVICE user invites set `jarvice-user` role in Keycloak
* (JAR-8875) Correct format of AppDefs shown in BIRD UI
* (JAR-8878) V2 applications to warn when incompatible glibc is detected
* (JAR-8887) BIRD UI no longer shows a $0.00 price for machines and applications
* (JAR-8896) Add Keycloak button to JARVICE Administration submenu
* (JAR-8962) Reduce resources used by Kubernetes Nested Scheduler
* (JAR-8979) (JAR-8971) Build Kubernetes Nested Scheduler init containers

## 3.24.5-202405221807

* (JAR-7901) Correct error when Team admin try to impersonate Payer accounts
* (JAR-8099) Enable Zone Admins to list users/tenants in zone
* (JAR-8504) Hide PushToCompute Dashboard on BIRD UI for non-developer users
* (JAR-8560) Fix Slurm nodes list
* (JAR-8564) Do not expand JARVICE machines when saving PushToCompute Appdef from BIRD UI
* (JAR-8609) Update initial Keycloak realm configuration for new JARVICE deployments
* (JAR-8627) Fix various dashboard bugs on BIRD UI
* (JAR-8641) Add hostAliases support for jarvice services and keycloak in jarvice-helm
* (JAR-8646) Fix job output for batch jobs on mc portal
* (JAR-8651) Change mouse icon when hovering on job "Clone" option
* (JAR-8652) Log the correct user on PushToCompute Pull History page
* (JAR-8655) (JAR-8733) Update JARVICE service containers to alpine 3.19
* (JAR-8656) Correct presentation of applications displayed on the BIRD UI Team Jobs page
* (JAR-8661) Maintain search query on tables in BIRD UI during refreshes
* (JAR-8671) (JAR-8643) (JAR-8791) General accessibility improvements for BIRD UI
* (JAR-8693) Flex support for upload file template
* (JAR-8697) Correct File parameter handling in BIRD UI
* (JAR-8710) (JAR-8657) Fix vault creation logic to prohibit invalid sizes
* (JAR-8711) (JAR-8620) Use trust-manager to handle root certificates in JARVICE
* (JAR-8734) Fix user stats refresh on MC portal
* (JAR-8743) Update init v2 to conditionally load libraries based on LSB compatibility
* (JAR-8746) Fix issue with missing import for docker pull container
* (JAR-8762) Map SAML emails to JARVICE supported username
* (JAR-8763) Create JARVICE user using JWT token from Keycloak
* (JAR-8788) Support days format with Slurm squeue command
* (JAR-8808) Fix GID permissions on /etc/hosts

## 3.24.4-202403251918

* (JAR-8186) Allow apps to disable public IP ingress in interactive endpoints via AppDef
* (JAR-8283) Add wall time field to Team Jobs view
* (JAR-8502) Fix incorrect AppDef command name in job builder on BIRD UI
* (JAR-8507) Fix core slider on job builder for BIRD UI
* (JAR-8508) Fix job clone on BIRD UI to use correct machine type
* (JAR-8509) (JAR-8203) Fix bug in appsync preventing deletion of out dated application
* (JAR-8513) Dashboard transition to Current page after job submission on BIRD UI
* (JAR-8519) Verify vault share settings during job submission
* (JAR-8524) Add topbar color to theme editor
* (JAR-8553) Allow LDAP bind user to use generic string
* (JAR-8557) Preserve AppDef ordering returned by /jarvice/apps
* (JAR-8565) Fix bug not displaying all application on Administration->Applications page
* (JAR-8599) Fix JARVICE_API_PUBLIC_URL substitution in jarvice-helm chart
* (JAR-8611) Fix /jarvice/apps handling of Google Artifact Docker registries
* (JAR-8614) Update dependencies for OpenMPI

## 3.24.3-202402282109

* (JAR-7845) Prevent SAML/LDAP login if email is already in use
* (JAR-8356) gkev2 terraform module optionally uses different service account for compute node groups
* (JAR-8412) (JAR-8430) (JAR-8440) (JAR-8445) (JAR-8435) (JAR-8519) Address various vulnerabilities
* (JAR-8467) Export theme to json file
* (JAR-8469) (JAR-8470) Fix issue where job help HTML doesn't show up
* (JAR-8484) Add timeout for FPGA reset when using Xilinx accelerators
* (JAR-8486) Correct theme editor settings for dark mode
* (JAR-8488) Optionally block cloud metadata server (GKE and EKS) from JARVICE jobs

## 3.24.2-202402151917

* (JAR-8357) Remember dashboard navigation history
* (JAR-8364) (JAR-8420) (JAR-8425) Fix various vulnerabilities on Material Compute UI
* (JAR-8371) Get global theme from java-web-ui-server
* (JAR-8453) Fix SAML config failure for some configurations
* (JAR-8466) Package OpenMPI with UCX
* (JAR-8471) Add XRT reset for jobs using a Xilinx FPGA

## 3.24.1-202401311639

* (JAR-7949) Add Vendor option to LDAP federation on Account->LDAP page
* (JAR-8150) Add general-purpose job submission validation hook script
* (JAR-8280) Correct job details shown to System Administrators
* (JAR-8321) Fix PushToCompute bug that clears out application certification
* (JAR-8325) Update bird nginx config to proxy /portal to port 8080
* (JAR-8327) Fix bug with FQDN support with slurm scheduler
* (JAR-8329) Fix jobtail display to show unicode characters correctly
* (JAR-8330) Update recent apps on BIRD UI
* (JAR-8345) Fix team limits for Machines in Cluster 0 under Account->Team
* (JAR-8351) Fix generator for container image tags in jarvice-helm
* (JAR-8358) Add missing toleration constraint for proxy pod on slurm scheduler
* (JAR-8376) Optionally move UI submenus to the right using dashboard editor

## 3.24.0-202401181754

* (JAR-6946) Use persistent PVC for bird server db
* (JAR-7519) Fixed bug where user by zone drop down lists zones that have been deleted
* (JAR-7523) Add Disable Notifications feature for sysadmins
* (JAR-7847) Add the Wall time to Team Jobs dashboard or Team Summary
* (JAR-7948) Remove unused routes from jarvice-bird ingress
* (JAR-7972) Allow jarvice-bird Keycloak client to deploy in realms other than 'jarvice'
* (JAR-7975) Fix error when pulling image from PushToCompute
* (JAR-7977) Fix error when clicking on active job logs for a submitted job
* (JAR-8136) Fix error preventing PushToCompute App icon from updating after successful save
* (JAR-8213) Update docker-unfs3 container to Alpine 3.18
* (JAR-8214) Enable custom Keyloack email theme
* (JAR-8223) Move back button on application builder UI
* (JAR-8230) Enable custom Keycloak login theme
* (JAR-8245) Fix team limits to include all team member zones
* (JAR-8246) Fix sidenav rendering
* (JAR-8280) Correct job details shown to System Administrators
* (JAR-8296) Remove unused packages from jarvice-bird
* (JAR-8308) Remove root path from JARVICE_API_PUBLIC_URL
* (JAR-8311) Automatically refresh Admin/Machines page

## 3.21.9-1.202312061620

* (JAR-5243) Billing code showing a job in current month even though it completed in previous month
* (JAR-7421) Account/Limits - Hide "Per User" checkbox unless its the "Team default" limit
* (JAR-7444) Project selection does not show up for team member
* (JAR-7584) Move k8s support to 1.26
* (JAR-8039) Enable SAML login for Google
* (JAR-8081) UI: Don't show errors when job-runtime-info polling fails (seen during job termination)
* (JAR-8095) Multi-tenant support has a race condition
* (JAR-8128) Change k8s API deprecation check to version 1.23 for gke terraform module
* (JAR-8137) pod-scheduler: account for resource-less containers to avoid OutOfCpu evictions
* (JAR-8138) UI: Notifications - 400 Error when entering phone number without selecting provider
* (JAR-8141) UI: Account SSH Keys cannot be validated correctly
* (JAR-8150) Add general-purpose job submission validation hook script
* (JAR-8153) UI: SAML page buttons alignment
* (JAR-8170) Update DAL to Django 4.2
* (JAR-8219) Fix pullsecret check for /jarvice/batch

## 3.21.9-1.202311081510

* (JAR-6665) Allow option for user to inherit team default white list
* (JAR-7950) Fix invalid redirect_url & backchannel logout url in auto generated jarvice Keycloak client config
* (JAR-8027) jarvice-api: support job priority during job submission for payers and team admins
* (JAR-8066) ZoneAdmin fix bug with auto complete list only showing 25 users
* (JAR-8072) SlurmScheduler support FQDN hosts
* (JAR-8101) Fix endless failure login loop when impersonating user
* (JAR-8102) Check zone admin status on heartbeat and enforce refresh if changed
* (JAR-8133) Add restrict queue environment variables to helm
* (JAR-8139) Pin helm chart version in script/deploy2k8-* scripts
* (JAR-8143) Hide edit dashboard for normal user

## 3.21.9-1.202310261643

* (JAR-7581) Create "short queue" via license manager licfeatures hook script.
* (JAR-7741) (JAR-8013) Eviden theme.
* (JAR-7802) (JAR-7803) (JAR-7804) (JAR-7805) (JAR-7806) (JAR-7961) (JAR-8029) (JAR-8066) (JAR-8073) (JAR-8092) (JAR-8093) (JAR-8097) (JAR-8098) Added Zone Admin feature; system administrators can now delegate self-service management to an entire zone from the *Administration->Zones* view, including whether or not a zone has access to legacy apps (v1), which is the default.  Delegated zone administrators have an administration widget in their dashboards and can act on elements such as jobs, machine definitions, and billing reports for the respective zone.
* (JAR-7859) Update Keycloak LDAP and SAML config to allow partial setups.
* (JAR-7900) Allow the Team Jobs username column to be adjustable.
* (JAR-7902) UI Dashboard History long label overwrites next column content.
* (JAR-7904) Dashboard Team Jobs landing page should not be collapsed.
* (JAR-7905) Dashboard Team Jobs remember the choice for Group by user.
* (JAR-7906) Dashboard Team Jobs Group by User default should be turned off.
* (JAR-7907) Dashboard Team Jobs missing terminate a single job option. 
* (JAR-7909) Dashboard Team Jobs Application name should replace application id.
* (JAR-7910) Dashboard Team Jobs Machine column is missing.
* (JAR-7911) Dashboard Team Jobs Status unnecessary if all are running.
* (JAR-7912) Dashboard Team Jobs Clone is not necessary.
* (JAR-7913) Dashboard Team Jobs Impersonate function missing.
* (JAR-7914) Dashboard Team Jobs Command is unnecessary.
* (JAR-7915) Dashboard Team Jobs Start time for submitted should be -:-:- .
* (JAR-7938) Portal: Fix issue with creating new zone.
* (JAR-7974) Make Job Control icons bigger on new UI.
* (JAR-7976) Batch output from jobs shows special characters (\n) removing the format from stdout.
* (JAR-8065) UI: SysAdmin sees multiple Administration icons.
* (JAR-8068) Remove jarvice client ADMIN role from keycloak.
* (JAR-8084) UI: Zone name text longer than the button.

## 3.21.9-1.202309071538

* (JAR-6820) Audit log endpoint for jarvice-api
* (JAR-7046) Portal: Sysadmin feature to force Keycloak password reset for any user.
* (JAR-7544) Queue limits are enforced for per-payer job priorities.
* (JAR-7597) Tag jobs to allow easy sorting by bare metal sys admin on Slurm downstream clusters.
* (JAR-7736) Portal - Allow custom About Page content.
* (JAR-7737) Update cert-manager tolerationS.
* (JAR-7739) v2 apps: support SSH with password if possible.
* (JAR-7744) Billing Multiselect dropdown does not show selected options.
* (JAR-7779) Make Jarvice BIRD deployment air gap friendly.
* (JAR-7782) Create EKSv2 terraform module supporting EBS Container Storage Interface required for k8s 1.23+.
* (JAR-7783) UI - PTC - limit icon size.
* (JAR-7788) Add banner to help debug on Slurm downstream cluster jobs.
* (JAR-7790) Minor helm updates for BIRD UI.
* (JAR-7801) Internal support for future "zone admin" feature.
* (JAR-7807) bird-portal should not change to ready state if keycloak admin credentials are invalid.
* (JAR-7808) Add externalIP support to traefik deploy script.
* (JAR-7810) Correctly apply resources settings for jarvice-db service from override file.
* (JAR-7833) Portal: Request IP checkbox not shown for v2 apps with interactive endpoints.
* (JAR-7846) Fixed issue with User signup success email template.

## 3.21.9-1.202308021521

* (JAR-7368) Helm does not export singularity verbose.
* (JAR-7407) Add Theme Editor.
* (JAR-7427) SAML users are kept logged in for the entire duration of browser session (or tab).
* (JAR-7442) Fix issue with restricted Team member still having access to other apps unless they refresh page.
* (JAR-7496) Limit dashboards menu width.
* (JAR-7516) Fix Admin Manage Apps Error handling when save fails.
* (JAR-7517) Admin Users: Change 'Login' to 'Username' and 'User name' to 'Full Name'
* (JAR-7521) Admin Users UI: Team members should inherit fields from payer.
* (JAR-7522) API: Admin->Metadata shows Keycloak auth error.
* (JAR-7525) Fixed timeout error shown for user trying to relogin on a timedout login screen.
* (JAR-7542) Compute/PTC - Fix filter by category logic.
* (JAR-7547) Allow ungroup view on Team Jobs.
* (JAR-7550) Updated terraform tfvars for BIRD UI.
* (JAR-7551) On Team Jobs, allow all jobs to be visible on the page.
* (JAR-7580) Add BIRD UI containers to jarvice-pull-system-images.
* (JAR-7676) Divide long menu into categories using divider.
* (JAR-7677) Add 9-dot icon on topbar.
* (JAR-7701) Check and merge OpenAPI documentation for Jarvice API.
* (JAR-7726) Fix License Included not displayed PTC.
* (JAR-7727) Admin/Billing - Optional filters error.
* (JAR-7735) Fix typo for helm hook job.

## 3.21.9-1.202307051453

* (JAR-5754) Added `jarvice.JARVICE_API_TIMEOUT` and `jarvice.JARVICE_API_MAX_CNCR` to [values.yaml](values.yaml).
* (JAR-6821) Return the JARVICE deployment version tag in `/jarvice/ready` endpoint of `jarvice-api`
* (JAR-6822) Return the JARVICE deployment version tag in `/ready` endpoint of all control plane components served via public Ingress (e.g. downstream scheduler).
* (JAR-7149) Rendering issue - dummy scrollbar.
* (JAR-7189) Fixed bug where license manager configuration couldn't be deleted if it would've left the entire configuration empty.
* (JAR-7305) Expose tenant priority in job details for admins.
* (JAR-7306) Allow sort by tenant priority in team jobs queue view.
* (JAR-7307) Allow team admins to change job priority.
* (JAR-7309) Update Account->Team Restrictions column logic.
* (JAR-7357) Improved cleanup of Singularity overlay images on Slurm clusters.
* (JAR-7367) Fixed bug sourcing custom environment on Slurm clusters.
* (JAR-7420) Account/Team Summary: "More" button on active jobs should redirect to Dasboard/Team Jobs.
* (JAR-7426) Don't show "Invalid Command" banner on apps whose commands cant be run.
* (JAR-7436) Regular team member does not have Account->Summary when Allowed by Team Admin.
* (JAR-7443) Demoting a team admin does not remove Saml admin privilege.
* (JAR-7451) Fixed table filter behaviour.
* (JAR-7478) Add steps to add keycloak cert to bird UI.
* (JAR-7493) Admin/Users Show only payers not filtered after refresh.
* (JAR-7494) Admin/Users Vaults in dark mode.
* (JAR-7495) Recent apps -tooltip position.
* (JAR-7498) Team jobs - if two users run jobs view is empty.
* (JAR-7502) Fix issue with SAML config parsing - allowing Keycloak to handle the configuration.
* (JAR-7506) Fixed missing scratch directories in writable tmpfs for Singularity without setuid privileges on Slurm clusters.
* (JAR-7507) Fixed missing non-RSA key support in SSH proxy for remote visualization in Slurm clusters.
* (JAR-7510) Fixed Administrator apps detail showing interpolated AppDef.
* (JAR-7518) Increase visibility of Zone selector.
* (JAR-7524) Pagination change Default settings.

## 3.21.9-1.202306281533

* (JAR-7484) Fixed problem with `ldconfig` failures when using `nvidia-container-cli` with GPU-enabled jobs.
* (JAR-7488) Removed reporting of privileged public apps as well as app container addresses when using unauthenticated `/jarvice/apps` endpoint of `jarvice-api`.

## 3.21.9-1.202306211440

* Next-generation user interface portal generally available but disabled by default; see [BIRD portal](Bird.md) for details on enabling and configuring.
* (7251) Optional support for existing Kubernetes secret for SSH user name/private key combination when configuring Slurm schedulers; see `jarvice_slurm_scheduler.schedulers` section in [values.yaml](values.yaml) for details.
* (7270) Added documentation for new Slurm downstream scheduler features; see [Slurm cluster nodes](Configuration.md#slurm-cluster-nodes) in *JARVICE System Configuration Notes* for details.
* (7297) Added support for ed25519 SSH keys for user private key when using Slurm scheduler; this format is detected automatically based on the private key's value.
* (7302) (7303) (7304) Future data model and scheduling support for self-service tenant admin job queue management.
* (7350) Improved cleanup after image conversion errors with Singularity for Slurm downstream clusters.
* (7355) Fixed bugs applying settings *ConfigMap* to portal.
* (7358) Support for unprivileged Singularity binaries which cannot use the overlay functionality; note that this may result in compatibility issues with certain applications; see [Singularity builds and setuid](SlurmScheduler.md#singularity-builds-and-setuid) for details.

## 3.21.9-1.202305101453 *(Next-generation UI portal TECH PREVIEW)*

* (JAR-6818) Sign email addresses in new user invite URLs for additional security.
* (JAR-6884) Preserve `${PATH}` in V2 app containers.
* (JAR-6947) Preliminary support for Kubernetes 1.26 (experimental)
* (JAR-7043) Slurm jobs fail sooner if errors occur during execution of script.
* (JAR-7072) Initial support for next-generation ("BIRD") user interface portal; see the `jarvice-bird` section in [values.yaml](values.yaml) for details.
* (JAR-7073) If enabled, new user invitations will be serviced automatically by new portal backend with functionally identical user experience and similar look and feel; new logins will be consistent on both portals unless passwords are later reset from any given portal.
* (JAR-7116) Fixed bug with variable expansion in V2 apps.
* (JAR-7150) Enable SFTP in V2 app containers requesting public IP addresses; note that only key authentication is supported for V2 apps, not password.
* (JAR-7250) Additional `sbatch` parameters added for machine definitions, documentation forthcoming in a future release.
* (JAR-7258) Support `walltime` limit parameter in job submission when using Slurm clusters.
* (JAR-7259) Support for optional custom environment script in JARVICE-submitted Slurm jobs, documentation forthcoming in a future release.

## 3.21.9-1.202304121617

* (JAR-7112) Fixed deadline (walltime limit) capabilities to avoid terminating jobs that are still queuing; also included small but significant performance improvement to general Kubernetes downstream scheduling.

## 3.21.9-1.202303301627

* (JAR-6941) Support for custom HTML in portal *About* page; please see [Customize JARVICE files via a ConfigMap](README.md#customize-jarvice-files-via-a-configmap) for details.
* (JAR-6955) (JAR-7038) (JAR-7039) Slurm downstream support GA release.

## 3.21.9-1.202303151623

* (JAR-6370) Support for license-based queuing in Slurm downstreams.  Please see [Note about Slurm-managed compute clusters](LicenseManager.md#note-about-slurm-managed-compute-clusters) for additional details.
* (JAR-6669) Support for establishing a per-cluster concurrent CPU restriction in order to support smaller downstream clusters with a common set of limits.  Please see [Per-cluster Concurrent CPU Restriction: mL](Limits.md#per-cluster-concurrent-cpu-restriction-ml) for additional details.
* (JAR-6819) Added audit logging for when `jarvice-license-manager` suspends (and subsequently resumes) jobs.  Suspension logging will indicate which job triggered the suspension.

## 3.21.9-1.202303021959

* (JAR-4894) Allow configurable resource requests, limits, and expiration for file listing services, to better support large shared single volumes.  Please see [Improve file lister performance for shared vaults](Storage.md#improve-file-lister-performance-for-shared-vaults) for details.
* (JAR-5467) AppDef "v2" is now the default for newly created apps in the *PushToCompute* view.  For details on "v2" apps, please see the [JARVICE Applications Push to Compute tutorial](https://jarvice.readthedocs.io/en/latest/apps_tutorial/).
* (JAR-6712) Added support for `meta` JSON key at the top level of AppDefs which can be an arbitrary string for external use; this metadata is available when querying the service catalog using the `/jarvice/apps` API endpoint as well.
* (JAR-6782) Added newly queued job grace period before auto-cancellation for jobs that take too long to enqueue on Kubernetes clusters.  Please see [Advanced: Scheduler Performance Tuning](Scaling.md#advanced%3A-scheduler-performance-tuning) for details.

## 3.21.9-1.202302250249

* (JAR-6823) Fixed EGL rendering issue with certain applications in v2 mode due to misconfigured system libraries.

## 3.21.9-1.202302221615

* (JAR-6780) Fixed permission issues when using the `jarvice.JARVICE_APP_ALLOW_ROOT_INIT` option set to `"true"`.

## 3.21.9-1.202302161750

* (JAR-6771) Fixed GPU compute and 3D offload initialization bug when using the `jarvice.JARVICE_APP_ALLOW_ROOT_INIT` option set to `"true"`.

## 3.21.9-1.202302101633

* (JAR-4255) Fixed subsequent login failure when deleting default vault for a user in *Administration->Users*.
* (JAR-6080) Added `/jarvice/batch` endpoint to JARVICE API, to support submitting batch-only jobs referencing arbitrary containers (rather than apps in the catalog); note that cloning these jobs is not supported and inspecting the JSON in the portal from these jobs may not precisely match the submission payload.  For details please see the [JARVICE API](https://jarvice.readthedocs.io/en/latest/api) reference.
* (JAR-6131) Portal performance improvements.
* (JAR-6277) Experimental support for one or more downstream Slurm clusters, utilizing Singularity container engine for runtime.  For details please see the work-in-progress documentation in [JARVICE Slurm Scheduler Overview](SlurmScheduler.md)
* (JAR-6689) Increased size of ephemeral user home directory in v2 apps to take advantage of the entire overlay and avoid application issues.
* (JAR-6694) Improved robustness of SQL queries against certain versions of MySQL.

## 3.21.9-1.202211231718

* (JAR-5617) Improved web portal login speeds by optimizing whitelisted app queries.
* (JAR-5961) Future architectural updates.
* (JAR-6035) Prevent V2 apps from being sync'd to older systems via App Sync.

## 3.21.9-1.202210191724

* (JAR-5911) Restore compatibility with newer downstream endpoints during upgrades.

## 3.21.9-1.202210121614

* (JAR-5308) Updated `kubectl` authentication plugin for GKE to use `gke-gcloud-auth-plugin`.
* (JAR-5502) Prevent clickjacking vulnerability via iframe in portal.
* (JAR-5556) Made `interactive` key optional (defaulting to `false` for non-interactive endpoints) in the AppDef.
* (JAR-5575) Increased resource requests and limits for `pvcrun` file lister, and made them configurable when more is needed; please see [Improve file lister performance for shared vaults](Storage.md#improve-file-lister-performance-for-shared-vaults) in the *User Storage Patterns and Configuration* guide for details.
* (JAR-5576) Made the primary DN attribute configurable in *Account->LDAP* in order to support non-AD schemas.
* (JAR-5584) Performance improvement in portal user stats.
* (JAR-5623) Fixed bug where saving configuration in *Account->SAML* was failing with a null-related error.
* (JAR-5680) Added job `substatus` to response JSON from `jarvice/status` API endpoint.

## 3.21.9-1.202209141659 *(TECHNOLOGY PREVIEW RELEASE)*

* (JAR-5471) Fixed issue with team admins getting the payer vault list instead of their own on the Account/Vaults view
* (JAR-5614) Fixed bug with LDAP and SAML login URLs failing to launch  

## 3.21.9-1.202208311627 *(TECHNOLOGY PREVIEW RELEASE)*

* (JAR-100) `jarvice-sched-pass` became its own component, for improved troubleshooting and scalability; see [Advanced: Scheduler Performance Tuning](Scaling.md#advanced-scheduler-performance-tuning) in the *Resource Planning and Scaling Guide* and [Job status problems](Troubleshooting.md#job-status-problems) in the *JARVICE Troubleshooting Guide* for more information.
* (JAR-5414) (JAR-5536) (JAR-5545) Future AppDef "v2" support added.
* (JAR-5471) Reduced machine visibility to payers and team admins in *Account->Limits* view to those only in zones the team has access to.
* (JAR-5500) (Vulnerability remediation) use HSTS headers for web portal.
* (JAR-5571) Prevent caching of portal index page to avoid stale versions in browser, and version assets with each build.
* (JAR-5583) Fixed bug where sorting the metadata table in the portal *Administration->Metadata* view could result in selecting the wrong row.
* (JAR-5585) Fixed bug where downloading CSV report was failing in the *Administration->Billing* view.

## 3.21.9-1.202208171639

* (JAR-5459) Fixed vulnerability with billing reports URLs.
* (JAR-5472) Fixed `jarvice-license-manager` to maintain license reservations until all tokens are checked out by solver from FlexLM.
* (JAR-5483) Adjusted all scheduler components `requests` and `limits` in Helm templates for performance and scalability.
* (JAR-5493) Parallelized most elements of formerly serial scheduling mechanisms to improve job submission, start, and end throughput at scale.
* (JAR-5497) Fixed vulnerabilities related to using HTTP GET requests in web portal.
* (JAR-5499) Fixed vulnerability in web portal to hide server information in response headers.

## 3.21.9-1.202207251527

* (JAR-5386) Fixed regression introduced in previous release on `jarvice-pod-schduler` restart fixes; added additional fix to pod binding at scale for gang-scheduling robustness.

## 3.21.9-1.202207201613

* (JAR-5356) Added optional parameter in the task builder to use RSA keys instead of ED25519 keys for SSH inside jobs.  Use only for older applications packaging an SSH which does not support ED25519 keys.
* (JAR-5357) Improved job submission throughput and updated scaling guidelines for parallel submissions.  See [Load Scenarios Tested](Scaling.md#load-scenarios-tested) in the *Resource Planning and Scaling Guide* for details.
* (JAR-5386) Fixed bug causing potentially excessive `jarvice-pod-scheduler` restarts due to "best effort" *ConfigMap* deletion failure.
* (JAR-5417) Kubernetes 1.22 support.  See [Kubernetes Support](#kubernetes-support) for the latest list of supported Kubernetes versions.
* (JAR-5418) Improved `jarvice-license-manager` stability.

## 3.21.9-1.202207071522 *(TECHNOLOGY PREVIEW RELEASE)*

* (JAR-5198) (JAR-5199) Upgrade base components in `jarvice-mc-portal` and `jarvice-dal` to address future vulnerabilities.
* (JAR-5200) Support for configurable cluster name for default `no_proxy` settings; set `jarvice.JARVICE_K8S_CLUSTER_DOMAIN` if the cluster is named something other than `cluster.local`.
* (JAR-5309) Increased job submission throughput, especially in parallel (EXPERIMENTAL)
* (JAR-5328) Fixed bug where `jarvice-license-manager` permitted more jobs than available tokens.
* (JAR-5329) *Administration->Jobs* view now shows jobs queued for licensing or limits, in orange and yellow background, respectively.
* (JAR-5355) Eliminate use of `host_path` volume when using EGL 3D acceleration, and allow multiple jobs to use this mechanism on each node concurrently.
* (JAR-5362) Fixed `jarvice-license-manager` metrics to better align with Flex server, including fast expiration of reservations soon after tokens are checked out; also hold reservations while solvers are performing preprocessing operations ahead of checking out tokens to avoid oversubscribing licenses.
* (JAR-5407) Fixed bug where the search function of `Administration->Jobs` was causing a front-end exception.

## 3.21.9-1.202206081546

* (JAR-5064) Fixed bug where `jarvice-license-manager` was allowing too many jobs when using reservation limits.
* (JAR-5100) CVE remediation for various components
* (JAR-5150) Made the *TERMINATE ALL* job limit configurable in *Administration->Jobs*; set `jarvice_mc_portal.JARVICE_PORTAL_JOB_TERMINATE_LIMIT` in the deployment to a number less than 100 if desired.  The default is to terminate all jobs in the current page.
* (JAR-5160) Fixed bug with `RANGE` parameter type in apps.
* (JAR-5197) Removed hardcoded default of `master` branch name from PushToCompute builds; uses server's default (e.g. `main` or `master` on GitHub) unless otherwise specified.
* (JAR-5201) Made the `timeout` key for JARVICE License Manager configuration optional.
* (JAR-5213) Bundled OpenMPI for app container build stages, compatible with JARVICE-provided OpenMPI at runtime.  See the [nimbix/mpi-common](https://github.com/nimbix/mpi-common) repository for details and example.
* (JAR-5230) Fixed parameter name bug in `/jarvice/pull` API endpoint in the case where the pull Pod creation fails in Kubernetes.
* (JAR-5234) Added support to inject custom CA root certificates into JARVICE services and jobs.  See [Add CA root for JARVICE (optional)](README.md#add-ca-root-for-jarvice-optional) for details. (EXPERIMENTAL)
* (JAR-5240) Fixed bug with runtime info timeout that prevented jobs from transitioning out of *Starting* state due to Kubernetes client cache on some distributions.
* (JAR-5242) Fixed bug where *TERMINATE ALL* button in *Administration->Jobs* view was not enabled until refresh button clicked.
* (JAR-5276) Fixed SAML and LDAP configuration inconsistencies between team admins and team payer account.
* (JAR-5282) Added feature to optionally disable `chown` of user vault mountpoints.  See [Preventing permission changes on user storage directories](Storage.md#preventing-permission-changes-on-user-storage-directories) for details. (EXPERIMENTAL)
* (JAR-5291) Added support for optionally mapping SAML attributes for Active Directory UPN and sAMAccountName in *Account->SAML2 IdP*, in order to enable `jarvice-idmapper` to correctly map ownership to that of user home directories named after either UPN or sAMAccountName.  The configuration allows mapping arbitrary attributes from the SAML assertion to these values, and varies per identity provider and site configuration. (EXPERIMENTAL)

## 3.21.9-1.202204271651

* (JAR-75) Added endpoint capability in AppDef to run commands in a webshell; for additional details and examples please see [Gotty Shell AppDef Template](https://github.com/nimbix/appdef-template#gotty-shell-appdef-template) in the [JARVICE Application Definition Guide on GitHub](https://github.com/nimbix/appdef-template).
* (JAR-5047) Added color coding and filtering for Suspended Jobs in the *Administration->Jobs* view.
* (JAR-5055) Added consideration for project floor oversubscription when deciding what jobs to suspend for projects with identical priorities in JARVICE License Manager.
* (JAR-5072) Added `/jarvice/projects` API endpoint to list all available projects in the system and their members; available to system administrators only; for details please see the [JARVICE API](https://jarvice.readthedocs.io/en/latest/api) reference.
* (JAR-5089) Added capability to specify timeout in seconds for `lmstat` queries against license servers in JARVICE License Manager using the `timeout` configuration key.
* (JAR-5090) Remediated "critical" and "high" package security vulnerabilities in all control plane containers.
* (JAR-5105) Removed the obsolete *Administration->Nodes* section.
* (JAR-5118) Fixed bug in license manager when configuring 0 for minimum allocation in preemptible features.
* (JAR-5119) Optimized saving of license manager configuration from *Administration->License Manager*.
* (JAR-5144) Fixed bug with project allocation edit dialog box in *Administration->License Manager*.
* (JAR-5164) Added support for IP-over-InfiniBand passthrough, as required for modern OFI-based MPI applications to leverage the `verbs` fabric provider (RDMA); for details, please see [Supporting OFI MPI stacks over InfiniBand](Configuration.md#supporting-ofi-mpi-stacks-over-infiniband).

## 3.21.9-1.202203301625

* (JAR-83) Handle missing zone or cluster gracefully in web portal login.
* (JAR-4848) Support for solver suspend/resume in apps implementing embedded Slurm scheduler.
* (JAR-4901) (JAR-4902) (JAR-4978) (JAR-4980) (JAR-4951) (JAR-5010) (JAR-5054) (JAR-5063) Advanced license-based queuing with preemptible features; see [Advanced: Preemptible Features](LicenseManager.md#advanced-preemptible-features) in the [JARVICE License Manager](LicenseManager.md) documentation for details.
* (JAR-4999) Fixed regression in browser-based interactive apps where team admin has disabled encoding connection passwords in URL.
* (JAR-5022) Added index to audit log table in database to improve performance of audit-related functions over time.
* (JAR-5062) GPU-related fixes for GKE.

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

