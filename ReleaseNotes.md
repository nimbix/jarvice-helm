# Release Notes

## General

- Singularity containers are not supported; JARVICE can only refer to Docker containers on Kubernetes.  If the container runtime can pull from Docker registries and is OCI compliant, this should be transparent to JARVICE as well.
- JARVICE and its applications refers to "CPU cores" but it can work with hyperthreading and SMT as well; in this case, treat the threads themselves as cores when configuring machine types, etc.  Note that many HPC applications explicitly recommend against using SMT, so consider setting up non-SMT nodes for these applications (they can be targeted with labels)
- Currently vaults should be provisioned on a user-by-user basis from the web portal or via the ```jarvice-vaults``` command in a pod in the ```jarvice-dal``` deployment; support for dynamic provisioning of Kubernetes PersistentVolumes linked to user account signups will be available in a future release
- The full JSON for all pods in a job can be downloaded via the *DOWNLOAD STDERR* button in the *Job data* for any given job in the *Jobs* view of the *Administration* tab; this should be used to troubleshoot failures by checking the actual Kubernetes status conditions.  Note that pods are deleted and garbage collected automatically once jobs end, so this is the only persistent record of what was specified and what the actual statuses were during the lifecycle.

## Known Issues, Anomalies, and Caveats

### JARVICE HPC Pod Scheduler (jarvice-pod-scheduler)

- Custom resource weighting is not yet implemented; all resource multipliers are set to 1 automatically.
- Pod affinity, local volumes, or any mechanism that pins pods to specific nodes in the cluster is not supported; use node labels as machine properties to direct pods to sets of nodes instead, and use network-attached persistent storage only

### Service Catalog

- It is not currently possible to prevent public/non-commercial applications from synchronizing from the Nimbix Cloud service catalog; the application sync fetches all authorized applications, which includes applications that are completely public (e.g. in public Docker registries)

### Web Portal

- The *Nodes* view in *Administration* should not be used in this version of JARVICE and is unlikely to load properly
- The *Discounts* view in *Administration* does not load properly
- It is not currently possible to add users without sending them an email to complete a registration; the cluster should be configured to send email and users should have real email addresses
- Specifying multiple device resource requests, other than for GPUs and CPUs, is not yet well supported in machine definitions.  By default anything entered into the ```devices``` field requests 1 unit of the respective entry.

### PushToCompute

- Logging into a Docker registry via the web portal has no effect on authorizing pulls currently; to add a login into a private Docker registry, instead create a secret called ```jarvice-docker--<user>```, where ```<user>``` is the login user name of the user doing the pull, in the Jobs namespace.
- Complete logs for pulls and builds are available in the system namespace for pods called ```dockerpull--<user>-<app>```, where ```<user>``` is the user who initiated the pull, and ```<app>``` is the application target ID that was pulled into; these pods are not garbage collected so that errors can be troubleshooted more effectively.  It is safe to delete them manually if desired.
- The *Build* functionality is not yet verified on this version of JARVICE.  The workaround is to ```docker build``` locally, push to a registry, and then use the *Pull* function of an application target to pull the metadata; if running a "non-native" application (see *Running "non-native" Applications* in [JARVICE System Configuration Notes](Configuration.md)), it is not necessary to pull explicitly via the web portal in order to run the container after creating the application target.

### Miscellaneous

- Jobs that run for a very short period of time and fail may be shown as *Canceled* status versus *Completed with Error*

