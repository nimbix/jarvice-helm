# Ingress Patterns and Configuration

JARVICE supports 3 forms of ingress into the cluster.  Ingress applies both to the externally-facing user interfaces (portal and API), as well as interactive jobs.

* [Host-based Ingress](#host-based-ingress)
* [Path-based Ingress](#path-based-ingress)
* [Load Balancer Only](#load-balancer)
* [Summary](#summary)

## Host-based Ingress

This method provisions user-facing JARVICE services as well as interactive job endpoints as `<host>.<domain>`, where *host* is dynamically generated per job and *domain* is specified at configuration time.  DNS configuration should point all traffic in the *domain* zone to the same ingress controller IP address, which will then use host headers to direct traffic to the appropriate JARVICE service or job.  This allows the path component in the URL to be application-dependent, and maximizes compatibility with applications that utilize routing techniques.

For this configuration, JARVICE services should have a full FQDN assigned to them.  It may have a different domain than the one used for jobs if desired, but that will require additional DNS configuration and certificates.  The JARVICE services' ingress hosts can be set using `jarvice_api.ingressHost` and `jarvice_mc_portal.ingressHost` for the processing API and the user interface portal, respectively, in the Helm chart configuration.

For jobs, set the FQDN as detailed in [Using an Ingress controller for jobs](README.md#using-an-ingress-controller-for-jobs), in the top-level README.

An example configuration may look like:

```
jarvice_api.ingressHost=api.mydomain.com
jarvice_mc_portal.ingressHost=portal.mydomain.com
jarvice.JARVICE_JOBS_DOMAIN=mydomain.com
```

The above would deploy the API service as `https://api.mydomain.com`, the web portal service as `https://portal.mydomain.com`, and interactive job endpoints as `https://<namespace>-<job-number>.mydomain.com`, where *namespace* is the jobs namespace (e.g. `jarvice-system-jobs`), and *job-number* is the JARVICE job number generated at submission time.  A DNS zone for `mydomain.com` should be configured to resolve all requests to the ingress controller's configured IP address, and a wildcard CA-signed certificate for `*.mydomain.com` should be applied to the ingress controller.  For additional details on ingress controller configuratio, see [Kubernetes ingress controller](README.md#kubernetes-ingress-controller) in the top-level README.

## Path-based Ingress

This method supports path-based routing to JARVICE services and job endpoints, allowing all ingress traffic to consolidate to a single FQDN.  The benefits over host-based ingress are:
* A single "A" record is needed in DNS rather than a complete zone, which simplifies DNS configuration and typically requires less access to make such a change to the network
* A single, non-wildcard CA-signed certificate is needed, which in some organizations is considered a better security practice than using a wildcard certificate

For this configuration, JARVICE services should have both an `ingressHost` (full FQDN), and an `ingressPath` defined in the Helm chart values.  JARVICE jobs should be configured according to [Enable path based ingress](README.md#enable-path-based-ingress) in the top-level README.

As example configuration may look like:
```
jarvice_api.ingressHost=mydomain.com
jarvice_api.ingressPath=/api
jarvice_mc_portal.ingressHost=mydomain.com
jarvice_mc_portal.ingressPath=/portal
jarvice.JARVICE_JOBS_DOMAIN=mydomain.com/job$
```

The above would deploy the API service as `https://mydomain.com/api`, the web portal service as `https://mydomain.com/portal`, and interactive job endpoints as `https://mydomain.com/job<job-number>`, where *job-number* is the JARVICE job number generated at submission time.  Note that unlike with host-based ingress, JARVICE does not inject namespace name into the job ingress path.  The assumption is that if you are running multiple instances of JARVICE on the same cluster, each would have a unique path configured with `jarvice.JARVICE_JOBS_DOMAIN`.

A DNS "A" record for `mydomain.com` should be configured to resolve to the ingress controller's configured IP address, and a CA-signed certificate for `mydomain.com` should be applied to the ingress controller.  For additional details on ingress controller configuratio, see [Kubernetes ingress controller](README.md#kubernetes-ingress-controller) in the top-level README.

### Notes
* `jarvice_api.ingressPath` and `jarvice_api.ingressHost` values should either be set to only `/api` and `/portal`, respectively.  Other values are not supported.  For host-based ingress they should both be set to `/`, which the default.  See [values.yaml](#values.yaml) for details.
* The path in the `jarvice.JARVICE_JOBS_DOMAIN` should not contain multiple `/`'s.  For example, use `mydomain.com/jarvice-job$` rather than `mydomain.com/jarvice/job$`

## Load Balancer Only

This method eliminates DNS and certificate requirements, but requires a potentially large IP address range to be reserved and will introduce user experience and security issues with web browsers.  Note that it is good practice to configure or use a load balancer regardless, and in fact, the default ingress controller configuration for JARVICE uses the load balancer to request an address even when the address is static (which should still be in the load balancer's range).  Additionally, some applications provide alternative connection methods besides HTTPS to end users, such as VNC or SSH, and may be desirable to support this way.

See [Kubernetes load balancer](README.md#kubernetes-load-balancer) in the top-level README for details.  Additionally, to request specific (static) IP addresses in the load balancer's range for the API and user portal, see [Selecting external, load balancer IP addresses](README.md#selecting-external-load-balancer-ip-addresses) in the top-level README.

## Summary

|Ingress Type|Requirements|Caveats|
|---|---|---|
|[Host-based Ingress](#host-based-ingress) (**preferred**)|Wildcard HTTPS certificate, Ability to manage DNS zones|*broadest application compatibility*|
|[Path-based Ingress](#path-based-ingress)|Single HTTPS certificate, ability to add DNS "A" record|best compromise of security and accessibility with minimum network configuration required, but may not be compatible with all applications|
|[Load Balancer Only](#load-balancer-only)|Ability to reserve a potentially large IP range|Easiest to deploy, but diminishes user experience due to browser compatibility and security warnings|

### Additional Notes and Best Practices

* Use CA-signed certificates to avoid browser compatibility and usability issues
* A load balancer can, and in most cases should, still be used even when ingress is configured, to facilitate IP address management and enable alternate connection methods to certain applications

