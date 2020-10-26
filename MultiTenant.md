# JARVICE Multi-tenant Overview

JARVICE supports a multi-tenant deployment mode which provides isolation and
separation of the data, network, and workload resources used by JARVICE jobs.

## Configuration

Multi-tenant mode can be enabled by setting `jarvice.JARVICE_JOBS_MULTI_TENANT`
to `true` during the helm deployment of JARVICE.  Additional configuration will
be necessary if external access to interactive JARVICE jobs is desired.
The `jarvice.JARVICE_JOBS_MULTI_TENANT_*` settings will direct the JARVICE
kubernetes scheduler to create the necessary NetworkPolicy objects to allow
external access.

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

