# JARVICE Multi-tenant Overview

JARVICE supports a multi-tenant deployment mode which provides isolation and
separation of the data, network, and workload resources used by JARVICE jobs.

There are 2 main elements to this mode:
1. Job isolation: in multi-tenant mode, the JARVICE scheduler will not pack jobs onto the same nodes if they are able to consume fractional resources and other tenant(s)' jobs are already running there.  While this may lead to decreased utilization efficiency, it guarantees that no 2 tenant workloads are running on any given physical node at any time, and may be a desired security posture for a multi-tenant service provider.
2. Network isolation: in multi-tenant mode, containers can only communicate with those of the same tenant and are blocked by *NetworkPolicy* from communicating with others.

A tenant is equivalent to a *payer* user account in JARVICE.  A payer is a user account that is not part of another account's team, and is typically invited by a system administrator from the *Administration->Users* view.  All subsequent users that a given payer invites (explicitly via invitation or implicitly via external authentication setup) are considered part of that tenant.  Note that all users in a payer's team fall into this category, even if they are delegated team admin rights, as well as the payer itself.

Multi-tenant mode is generally appropriate for service providers or large Enterprise users looking to achieve additional security compliance between groups or departments.  For most other users, it is safe to leave it disabled, which is the default.

Additionally, it's possible to restrict tenants to specific zones by federating their default vaults.  This can be done independently of whether or not job and network isolation modes are enabled, and is relevant in [Multi-cluster](#MultiCluster.md) setups.  See [Zone Isolation](#zone-isolation) for more details.

## Configuration

Multi-tenant mode can be enabled by setting `jarvice.JARVICE_JOBS_MULTI_TENANT`
to `true` during the helm deployment of JARVICE.  Additional configuration will
be necessary if external access to interactive JARVICE jobs is desired.
The `jarvice.JARVICE_JOBS_MULTI_TENANT_*` settings will direct the JARVICE
kubernetes scheduler to create the necessary NetworkPolicy objects to allow
external access.  Additionally, the scheduler will prevent pods from running on nodes that have another tenant's pod(s) already running on it, even if this would result in "best fit" for a given job's pod(s).

### External job access via ingress

If external access will be provided by ingress, it will be necessary to
identify the ingress controller pods via the
`jarvice.JARVICE_JOBS_MULTI_TENANT_INGRESS_*` settings.  For example, setting
`jarvice.JARVICE_JOBS_MULTI_TENANT_INGRESS_POD_LABELS` to
`'{"app": "traefik"}'` will allow access from `Traefik` ingress pods which
have their `app` label set to `traefik`.

If only `jarvice.JARVICE_JOBS_MULTI_TENANT_INGRESS_POD_LABELS` is set, job
access will be allowed from matching pods running in any namespace.  If it
is desired to relegate access to ingress pods running in a particular
namespace, it will be necessary to set
`jarvice.JARVICE_JOBS_MULTI_TENANT_INGRESS_NS_LABELS` to the appropriate
name/value pair for the namespace.  Note that namespaces typically have no
labels associated with them.  So it may be necessary to edit/patch the desired
namespace with the appropriate labels.

### External job access via load balancer services

If load balancer services will be used to allow external access to interactive
JARVICE jobs instead of (or in addition to) ingress,
the `jarvice.JARVICE_JOBS_MULTI_TENANT_LB_SERVICE_CIDRS` setting will need
to match the CIDR(s) of the IP addresses provided by the
[kubernetes load balancer](KubernetesInstall.md#kubernetes-load-balancer).

For example, setting `jarvice.JARVICE_JOBS_MULTI_TENANT_LB_SERVICE_CIDRS`
to `'["10.20.0.0/24"]'` will allow outside access to the load balancer
service IP address matching that network CIDR.

### Additional Notes

1. Even in multi-tenant mode, all jobs run in the same Kubernetes namespace (as set by `jarvice.JARVICE_JOBS_NAMESPACE`, or `${jarvice.JARVICE_SYSTEM_NAMESPACE}-jobs` by default); JARVICE ensures isolation by policy within this namespace as stated above.  Users looking to manage multiple namespaces must instead follow a [JARVICE Multi-cluster](Multicluster.md) pattern.  Note that the best practice is _not_ to allow ordinary users to make direct use of the Kubernetes API on the same cluster that runs JARVICE jobs in order to avoid tenant boundary violations.
2. If multi-tenant mode is enabled, the `jarvice-pod-scheduler` deployment will log (in log level 10) when it's disqualifying nodes from consideration for pod binding due to conflicting tenant workloads.  To troubleshoot such issues, set `jarvice.JARVICE_POD_SCHED_LOGLEVEL` to `10` before inspecting logs from pods of that deployment (accessible with the selector `-l component=jarvice-pod-scheduler`).  Note that this will produce very verbose logs especially on systems with high levels of job activity.

## Zone Isolation

Payers can be restricted to specific zones regardless of whether in multi-tenant mode or not.  This is done by overriding the default ephemeral vault zone, and optionally PVC vault zone, at the time the payer user is invited.  The defaults are then inherited automatically by any users that payer invites to the system.

If all vaults (including ephemeral) are zoned, payers and their respective member accounts will only be able to access those specific zone(s).  If the ephemeral vault and the persistent vault are in the same zone, this locks the team (or tenant) to a single zone, which will also restrict what compute cluster(s) are available.  Note that all zone rules apply, especially:
1. A user must have access to machines on clusters in a zone if they also have a vault in that zone, and vice-versa.
2. If either default vault is unzoned, users will have access to the *Default* zone as well, which may or may not be desired.

Default vault setup, including ephemeral vault zone, can be overridden when inviting payers to the system from the *Administration->Users* view.  Note that if values are not specified, the system defaults are used.  Also note that advanced site configurations may still benefit from custom DAL hooks.  Additionally, all supported storage patterns whether defaults are overidden or not.  See [User Storage Patterns and Configuration](Storage.md) for detauls.

### Per-user Exceptions to Tenant Storage Overrides

In cases where certain users on a team (including the payer itself) need vaults in other zones, or need different/additional vaults in general, these can be created on a per-user basis from the *Administration->Users* view by selecting a user row and clicking the *VAULTS* button.  The default settings only apply at the time of account creation/registration, but new vaults can be added after the fact and these are limited to the specific users they affect.  Vaults can also be shared, which may expand the zone restrictions if they are in zones outside of the default values.

### Changing Tenant Storage Overrides

When a payer account is registered, the defaults used for vault creation for that entire team/tenant are stored as metadata key/value pairs and can be modified from the *Administration->Metadata* view.  **Use extreme caution when editing rows in this view as it can have unintended effects!**  The table is searchable and easy to filter by a specific payer account.  The following metadata keys, specific to a payer account, affect defaults for signups on that team.

Key|Value|DAL Hook Environment Variable|Description/Notes
---|---|---|---
`vaultName`|string|`${JARVICE_PVC_VAULT_NAME}`|name of default JARVICE vault
`vaultStorageClassName`|string|`${JARVICE_PVC_VAULT_STORAGECLASS}`|name of *PersistentVolume* storage class
`vaultVolumeName`|string|`${JARVICE_PVC_VAULT_VOLUMENAME}`|name of *PersistentVolume* storage volume, if using statically-provisioned PV
`vaultAccessModes`|comma-separated list of: `ReadWriteOnce`, `ReadOnlyOnce`, and/or `ReadWriteMany`|`${JARVICE_PVC_VAULT_ACCESSMODES}`|most PV's support only 1 access mode request, even though the Kubernetes API allows multiples.
`vaultSize`|integer (>0)|`${JARVICE_PVC_VAULT_SIZE}`|size in gigabytes, must "fit" within the PV's range
`vaultSubpath`|string|`${JARVICE_PVC_VAULT_SUBPATH}`|optional subpath within volume, [supports substitutions](Storage.md#substitution-support-for-jarvicejarvice_pvc_vault_subpath)
`vaultZone`|integer|`${JARVICE_PVC_VAULT_ZONE}`|zone ID, or -1 for unzoned; note that the zone must exist and all zone login rules apply
`vaultEphemeralZone`|integer|`${JARVICE_EPHEMERAL_VAULT_ZONE}`|zone ID for default ephemeral vault, or -1 for unzoned; note that the zone must exist and all zone login rules apply
`vaultDalHookMeta`|string|`${JARVICE_DAL_HOOK_META}`|opaque metadata for custom DAL hooks, can be used for per-tenant conditional logic or for any other suitable purpose; this is ignored by the default creation hooks

#### Notes
1. Key names are case-sensitive.
2. If keys are not defined for a payer, this means the system defaults are in use instead.
3. Changes/additions affect self-service user invites from that payer moving forward, not existing accounts (including the payer account itself).
4. Unless otherwise noted, values described above are types, not actual values themselves.
