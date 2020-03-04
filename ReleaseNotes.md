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

Kubernetes **1.16**; newer versions are not explicitly supported.  Using the latest patch release of each version is recommended but not required.

#### Previous Version(s) Supported

Up to 3 previous minor revisions (from the one indicated in [Latest Version Supported](#latest-version-supported)) will be supported at any given time, unless otherwise noted.  Currently this list is limited to:

* Kubernetes **1.15**
* Kubernetes **1.14**


---
## Known Issues, Anomalies, and Caveats

### JARVICE HPC Pod Scheduler (jarvice-pod-scheduler)

- Custom resource weighting is not yet implemented; all resource multipliers are set to 1 automatically.
- Pod affinity, local volumes, or any mechanism that pins pods to specific nodes in the cluster is not supported; use node labels as machine properties to direct pods to sets of nodes instead, and use network-attached persistent storage only

### Web Portal

- The *Nodes* view in *Administration* should not be used in this version of JARVICE
- It is not currently possible to add users via the web portal without sending them an email to complete a registration; the cluster should be configured to send email and users should have real email addresses.  If this is not possible, you can still create users manually from the shell in any `jarvice-dal-*` pod in the JARVICE system namespace by running the command `/usr/lib/jarvice/bin/create-user` (run without arguments for usage).
- When creating vaults for users, do not use the *SINGLE VOLUME BLOCK* and *BLOCK VOLUME ARRAY* types, as these are not supported and can result in bad vaults that can't be deleted.  Use *FILE SYSTEM VAULT* for `ceph` filesystem mounts only, *NFS* for `nfs` mounts, and *PVC* for everything else (via `PersistentVolume` class and/or name)
- JARVICE does not apply any password policy for LDAP/Active Directory logins; instead, it performs a bind with the user's full DN and the supplied password to validate these as the final step of the login.  It's up to the LDAP administrator to apply policies on binds to help prevent DDoS or brute force login attacks.

### PushToCompute

- It is not necessary to explicitly pull in this version of JARVICE, as Kubernetes will do that implicitly, unless you are using a local registry (via `${JARVICE_LOCAL_REGISTRY}`); however it is a best practice, and is highly recommended so that application metadata can be updated in the service catalog.  If your container has JARVICE objects in it such as an `AppDef`, consider explicit pulls mandatory.
- Complete logs for pulls and builds are available in the `${JARVICE_PULLS_NAMESPACE}` and `${JARVICE_BUILDS_NAMESPACE}` respectively, for pods called `dockerpull--<user>-<app>` and `dockerbuild--<user>-<app>`, where `<user>` is the user who initiated the pull or build, and `<app>` is the application target ID that was built or pulled into; these pods are not garbage collected so that errors can be troubleshooted more effectively.  It is safe to delete them manually if desired.
- JARVICE manages pull secrets automatically for user apps, across any clusters it manages; if the user logs in to a Docker regsitry successfully in the web portal, JARVICE automatically generates and uses a pull secret for all associated app containers owned by that user; if the user logs out, JARVICE removes the pull secret.  Creation, patching, and removal of pull secrets happens at job submission time only.  These pull secrets are managed in the "jobs" namespace (controlled by `${JARVICE_JOBS_NAMESPACE}`).  As a best practice, once an app is set to public, the system administrator should create a permanent pull secret named `jarvice-docker-n`, where *n* is an integer, 0-9, in the `${JARVICE_JOBS_NAMESPACE}`.  This way, if the app owner logs out of the Docker registry for that container, the public app can still be used.

### Resource Limits and Cost Controls

- Resource limit changes do not apply retroactively to jobs that are already queued; any queued jobs will be executed as soon as capacity becomes available.  Constraining resource limits after jobs are in the regular queue has no effect on them.  However, increasing resource limits will allow jobs that are being held due to account settings to move to regular queue if the new limits permit that.

### PersistentVolume Vaults

#### General

- When using a PersistentVolume vault ("PVC" type), users will experience a slight delay when navigating file lists for file arguments in the task builder; on average this will a few seconds each time a directory is clicked.  This is becauase JARVICE cannot mount the storage directly and must instead schedule a pod to get file listings using a PersistentVolumeClaim.  As will all PVC vault types, JARVICE manages the PersistentVolumeClaim objects themselves.
- Before an application with a file selection in the task builder can work, at least one job with the PVC vault attached must be run; typically this will be the *JARVICE File Manager*, which is used to transfer files to and from the storage.

#### ReadWriteOnce PersistentVolumes

- Persistent volumes with RWO access mode, such as block devices, are automatically fronted with a filer service that allows multiple pods (multiple jobs with one or more pods each) to share the device in a consistent way.  Note that the first consumer will experience latency in starting as the filer service must start first.  The filer service runs as a StatefulSet with a single pod.  Note that only 1 filer service will run at any given time regardless of how many jobs access it (since the storage access mode is RWO).
- JARVICE calls the filer pod *`jarvice-<user>-<vault>-0`*, in the "jobs" namespace; for example, for the user `root` with a vault named `pvcdata`, the filer pod would be called `jarvice-root-pvcdata-0` in the "jobs" namespace.  The `-0` is actually generated automatically by Kubernetes as part of the StatefulSet.  Never delete this pod manually as it can lead to data corruption and certain job failure of any job consuming it.  It is garbage collected automatically when not used.
- For information about resizing PersistentVolumes and related StorageClass configuration, please see [Resizing Persistent Volumes using Kubernetes](https://kubernetes.io/blog/2018/07/12/resizing-persistent-volumes-using-kubernetes/).  Note that JARVICE terminates the filer pod after all jobs of that storage complete.

##### Advanced

- JARVICE uses guaranteed QoS for filer pods.  By default it requests 1 CPU and 1 gigabyte of RAM.  The filer pod runs a userspace NFS service which may benefit from additional resources for larger deployments.  To adjust, set the environment variables `${JARVICE_UNFS_REQUEST_MEM}` and `${JARVICE_UNFS_REQUEST_CPU}` in the `jarvice-scheduler` deployment.  Note that the memory request is in standard Kubernetes resource format, so 1 Gigabyte is expressed as `1Gi`.
- JARVICE runs filer pods with the node selector provided in `${JARVICE_UNFS_NODE_SELECTOR}`; when using the Helm chart, the values default to the "system" node selector(s), unless `jarvice_dal` has a node selector defined.

### Miscellaneous

- Jobs that run for a very short period of time and fail may be shown as *Canceled* status versus *Completed with Error*; in rare cases jobs that complete successfully may also show up as *Canceled* if they run for a very short period of time (e.g. less than 1 second).
- Account variables for a given user account must be referenced in an application AppDef in order to be passed into the container.  Please see [Application Definition Guide](https://jarvice.readthedocs.io/en/latest/appdef/) for details.
- *NetworkPolicy* may not work with all Kubernetes network plugins and configurations; if JARVICE system pods do not enter ready state as a result of failed connectivity to the `jarvice-db` or `jarvice-dal` service, consider disabling this in the Helm chart

---


# Changelog

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

