# Ingress Patterns and Configuration

JARVICE supports 3 forms of ingress into the cluster.  Ingress applies both to the externally-facing user interfaces (portal and API), as well as interactive jobs.

* [Host-based Ingress](#host-based-ingress)
* [Path-based Ingress](#path-based-ingress)
* [Ingress Class and TLS Certificates](#ingress-class-and-tls-certificates)
    - [Ingress class](#ingress-class)
    - [TLS certificates](#tls-certificates)
        - [Bring your own certificate](#bring-your-own-certificate)
        - [Dynamic certificate issuance with cert-manager](#dynamic-certificate-issuance-with-cert-manager)
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

## Ingress Class and TLS Certificates

### Ingress class

Traefik is the recommended ingress controller for JARVICE.  As such, the
default setting for `jarvice.ingress.class` is `traefik`.  This ingress class
setting will be used for the JARVICE portal and API service ingresses as well
as for JARVICE job ingresses.  If using an ingress controller other than
Traefik, `jarvice.ingress.class` should be updated to match the ingress class
for that ingress controller.

### TLS Certificates

By default, JARVICE deployments do not enable any TLS settings.  So ingresses
will use whichever certificate the ingress controller may provide.  However,
it is highly recommended that the settings under `jarvice.ingress.tls` be
used in order to ensure a properly secured JARVICE deployment.

#### Bring your own certificate

In order to use an existing certificate and key which may have been issued by
a certificate authority (CA), it will be necessary to `base64` encode the
certificate and key.  Example:

```bash
$ base64 -w 0 <site-domain>.crt
$ base64 -w 0 <site-domain>.key
```

The `base64` outputs should then be used for the `jarvice.ingress.tls.crt`
and `jarvice.ingress.tls.key` settings.

**Note:** If `jarvice.ingress.tls.crt` and `jarvice.ingress.tls.key` are set,
The `jarvice.ingress.tls.cluster_issuer` and `jarvice.ingress.tls.issuer`
settings will be ignored.

#### Dynamic certificate issuance with cert-manager

In order to dynamically issue TLS certificates and keys for ingresses,
[cert-manager](https://cert-manager.io/) must be deployed.  This is done
automatically when doing a [JARVICE deployment with Terraform](Terraform.md).
When not using Terraform,
the `deploy2k8s-cert-manager` shell script included in the `scripts`
directory of this helm chart can be used to deploy `cert-manager`.

##### JARVICE certificate issuers

When `jarvice.ingress.tls.issuer.email` is set to a valid email address and
`jarvice.ingress.tls.issuer.name` is set to one of `letsencrypt-prod`,
`letsencrypt-staging`, or `selfsigned`, the JARVICE helm chart will
automatically create an appropriate certificate issuer that will dynamically
create certificates for ingresses.

If [Let's Encrypt](https://letsencrypt.org/) certificates are desired,
set `jarvice.ingress.tls.issuer.name` to `letsencrypt-prod` or
`letsencrypt-staging`.  For production deployments of JARVICE,
`letsencrypt-prod` should be used.  For experimental or testing deployments,
it may be desirable to use `letsencrypt-staging`.  In the latter case, it is
recommended that the root certificates for the
[Let's Encrypt Staging Environment](https://letsencrypt.org/docs/staging-environment/)
be imported into your web browser.

**Note:**  In order to use the [Let's Encrypt](https://letsencrypt.org/)
issuers, the JARVICE ingresses must be accessible from the internet.

##### Custom certificate issuers

If the use of a custom cluster issuer is desired, set
`jarvice.ingress.tls.cluster_issuer.name` to the name of that issuer.
Manually creating and using custom issuers is beyond the scope of this
document.  Please view the
[issuer concept](https://cert-manager.io/docs/concepts/issuer/) page and
[configuration documentation](https://cert-manager.io/docs/configuration/).

**Note:**  If `jarvice.ingress.tls.issuer.email` and
`jarvice.ingress.tls.issuer.name` are set,
`jarvice.ingress.tls.cluster_issuer.name` will be ignored.

## Load Balancer Only

This method eliminates DNS and certificate requirements, but requires a potentially large IP address range to be reserved and will introduce user experience and security issues with web browsers.  Note that it is good practice to configure or use a load balancer regardless, and in fact, the default ingress controller configuration for JARVICE uses the load balancer to request an address even when the address is static (which should still be in the load balancer's range).  Additionally, some applications provide alternative connection methods besides HTTPS to end users, such as VNC or SSH, and may be desirable to support this way.

See [Kubernetes load balancer](README.md#kubernetes-load-balancer) in the top-level README for details.  Additionally, to request specific (static) IP addresses in the load balancer's range for the API and user portal, see [Selecting external, load balancer IP addresses](README.md#selecting-external-load-balancer-ip-addresses) in the top-level README.

## Summary

|Ingress Type|Requirements|Caveats|
|---|---|---|
|[Host-based Ingress](#host-based-ingress) (**preferred**)|Wildcard HTTPS certificate, Ability to manage DNS zones|*broadest application compatibility*|
|[Path-based Ingress](#path-based-ingress)|Single HTTPS certificate, ability to add DNS "A" record|best compromise of security and accessibility with minimum network configuration required, but may not be compatible with all applications|
|[Load Balancer Only](#load-balancer-only)|Ability to reserve a potentially large IP range|Easiest to deploy, but diminishes user experience due to browser compatibility and security warnings|

### Custom Ingress URLs for Jobs

The `jarvice.JARVICE_JOBS_DOMAIN` parameter also supports URL specification in addition to just FQDN.  This should only be used if the ingress controller does not properly support HTTPS, or if it runs on a custom port other than 443.  Specifying this parameter as an FQDN defaults to `https://` scheme and port 443.

To change the scheme and/or port, you must specify `jarvice.JARVICE_JOBS_DOMAIN` as a URL rathern than a FQDN.  For example, to generate user-facing ingress URLs using path-based ingress on a specified port, the parameter could be specified as:

```
http://myingress.io:8080/job$
```

Note that scheme can be either `http://` or `https://`, and must be specified if a custom port is used.  The above setting is not valid as just `myingress.io:8080`, it must include the scheme if you are overriding the default ports!

Also note, Kubernetes does not support creating ingress objects that specify ports; the assumption is that the ingress controller will be listening on any non-443 or non-80 port you choose.  In terms of the *Ingress* object itself, it will still be created with the FQDN (minus any port override).

Finally, using HTTP versus HTTPS has security implications, especially on public networks, as many application services will pass access keys in URLs for easy connection.  Use only if necessary or for specific purposes.  Using HTTPS with a valid certificate is always the best practice (see below).

### Additional Notes and Best Practices

* Use CA-signed certificates to avoid browser compatibility and usability issues
* A load balancer can, and in most cases should, still be used even when ingress is configured, to facilitate IP address management and enable alternate connection methods to certain applications

