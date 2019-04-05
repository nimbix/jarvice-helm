# JARVICE Release Notes

* [General](#general)
* [Known Issues, Anomalies, and Caveats](#known-issues-anomalies-and-caveats)
* [Changelog](#changelog)

---
## General

- Singularity containers are not supported; JARVICE can only refer to Docker containers on Kubernetes.  If the container runtime can pull from Docker registries and is OCI compliant, this should be transparent to JARVICE as well.
- JARVICE and its applications refers to "CPU cores" but it can work with hyperthreading and SMT as well; in this case, treat the threads themselves as cores when configuring machine types, etc.  Note that many HPC applications explicitly recommend against using SMT, so consider setting up non-SMT nodes for these applications (they can be targeted with labels)
- The full JSON for all pods in a job can be downloaded via the *DOWNLOAD STDERR* button in the *Job data* for any given job in the *Jobs* view of the *Administration* tab; this should be used to troubleshoot failures by checking the actual Kubernetes status conditions.  Note that pods are deleted and garbage collected automatically once jobs end, so this is the only persistent record of what was specified and what the actual statuses were during the lifecycle.

---
## Known Issues, Anomalies, and Caveats

### JARVICE HPC Pod Scheduler (jarvice-pod-scheduler)

- Custom resource weighting is not yet implemented; all resource multipliers are set to 1 automatically.
- Pod affinity, local volumes, or any mechanism that pins pods to specific nodes in the cluster is not supported; use node labels as machine properties to direct pods to sets of nodes instead, and use network-attached persistent storage only

### Web Portal

- The *Nodes* view in *Administration* should not be used in this version of JARVICE
- It is not currently possible to add users via the web portal without sending them an email to complete a registration; the cluster should be configured to send email and users should have real email addresses.  If this is not possible, you can still create users manually from the shell in any `jarvice-dal-*` pod in the JARVICE system namespace by running the command `/usr/lib/jarvice/bin/create-user` (run without arguments for usage).

### PushToCompute

- It is not necessary to explicitly pull in this version of JARVICE, as Kubernetes will do that implicitly, unless you are using a local registry (via `${JARVICE_LOCAL_REGISTRY}`); however it is a best practice, and is highly recommended so that application metadata can be updated in the service catalog.  If your container has JARVICE objects in it such as an `AppDef`, consider explicit pulls mandatory.
- Complete logs for pulls and builds are available in the `${JARVICE_PULLS_NAMESPACE}` and `${JARVICE_BUILDS_NAMESPACE}` respectively, for pods called `dockerpull--<user>-<app>` and `dockerbuild--<user>-<app>`, where `<user>` is the user who initiated the pull or build, and `<app>` is the application target ID that was built or pulled into; these pods are not garbage collected so that errors can be troubleshooted more effectively.  It is safe to delete them manually if desired.

### Resource Limits and Cost Controls

- Resource limits should not currently be used at any level (administrator controlled or self-service) if Kubernetes cluter autoscaling is enabled, as nodes may scale up even if queued jobs are resource limited; this issue will be fixed in a future release.
- Resource limit changes do not apply retroactively to jobs that are already queued; any queued jobs will be executed as soon as capacity becomes available.  Constraining resource limits after jobs are in the regular queue has no effect on them.  However, increasing resource limits will allow jobs that are being held due to account settings to move to regular queue if the new limits permit that.

### Miscellaneous

- Jobs that run for a very short period of time and fail may be shown as *Canceled* status versus *Completed with Error*; in rare cases jobs that complete successfully may also show up as *Canceled* if they run for a very short period of time (e.g. less than 1 second).

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

