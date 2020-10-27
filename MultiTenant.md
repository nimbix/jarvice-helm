# JARVICE Multi-tenant Overview

JARVICE supports a multi-tenant deployment mode which provides isolation and
separation of the data, network, and workload resources used by JARVICE jobs.

There are 2 main elements to this mode:
1. Job isolation: in multi-tenant mode, the JARVICE scheduler will not pack jobs onto the same nodes if they are able to consume fractional resources and other tenant(s)' jobs are already running there.  While this may lead to decreased utilization efficiency, it guarantees that no 2 tenant workloads are running on any given physical node at any time, and may be a desired security posture for a multi-tenant service provider.
2. Network isolation: in multi-tenant mode, containers can only communicate with those of the same tenant and are blocked by *NetworkPolicy* from communicating with others.

A tenant is equivalent to a *payer* user account in JARVICE.  A payer is a user account that is not part of another account's team, and is typically invited by a system administrator from the *Administration->Users* view.  All subsequent users that a given payer invites (explicitly via invitation or implicitly via external authentication setup) are considered part of that tenant.  Note that all users in a payer's team fall into this category, even if they are delegated team admin rights, as well as the payer itself.

Multi-tenant mode is generally appropriate for service providers or large Enterprise users looking to achieve additional security compliance between groups or departments.  For most other users, it is safe to leave it disabled, which is the default.

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

## Additional notes

1. Even in multi-tenant mode, all jobs run in the same Kubernetes namespace (as set by `jarvice.JARVICE_JOBS_NAMESPACE`, or `${jarvice.JARVICE_SYSTEM_NAMESPACE}-jobs` by default); JARVICE ensures isolation by policy within this namespace as stated above.  Users looking to manage multiple namespaces must instead follow a [JARVICE Multi-cluster](Multicluster.md) pattern.  Note that the best practice is _not_ to allow ordinary users to make direct use of the Kubernetes API on the same cluster that runs JARVICE jobs in order to avoid tenant boundary violations.
2. If multi-tenant mode is enabled, the `jarvice-pod-scheduler` deployment will log (in log level 10) when it's disqualifying nodes from consideration for pod binding due to conflicting tenant workloads.  To troubleshoot such issues, set `jarvice.JARVICE_POD_SCHED_LOGLEVEL` to `10` before inspecting logs from pods of that deployment (accessible with the selector `-l component=jarvice-pod-scheduler`).  Note that this will produce very verbose logs especially on systems with high levels of job activity.

