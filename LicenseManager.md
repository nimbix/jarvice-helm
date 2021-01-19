# JARVICE License Manager

A comprehensive mechanism for queuing jobs based on license token availability.

## Contents

* [Overview](#overview)
    * [Use Cases](#use-cases)
    * [Notable Features](#notable-features)
    * [Architecture](#architecture)
* [Configuration](#configuration)
    * [Service Configuration](#service-configuration)
    * [License Server Configuration](#license-server-configuration)
    * [Multi-cluster Configuration](#multi-cluster-configuration)
* [API](#api)
* [Usage](#usage)
    * [Web Portal](#web-portal)
    * [JARVICE API](#jarvice-api)
* [Troubleshooting](#troubleshooting)
* [Best Practices, Anomalies, and Caveats](#best-practices-anomalies-and-caveats)

---

## Overview

The `jarvice-license-manager` component is an optional service in the JARVICE control plane (upstream) to provide support for queuing jobs based on license token availability on external license servers.  It is a cluster-wide feature intended to be used with batch, rather than interactive, jobs.

### Use Cases

Typical use cases include, but are not limited to:

* *"submit and forget"* for batch simulations - jobs will queue (rather than fail) until both infrastructure and license tokens are available
* ensuring important projects get priority for license tokens versus other projects
* maximizing cost efficiency on auto-scaling infrastructure to ensure scale-up only happens if licenses are available to run the respective jobs

### Notable Features

* Multi-cloud/multi-cluster support
* Multiple vendor/application support; allows configuration of multiple license servers to manage
* Project-based limits and overrides for tokens
* Optional feature groups and "pseudo-features" to simplify job submission
* Web-based management [API](#api)

### Architecture

![General Component Architecture](jarvice-license-manager.svg)

The `jarvice-license-manager` web service communicates with one or more FlexNet license server(s), maintains a token cache and reservation system, and provides guidance to downstream schedulers about license availability so they can queue jobs as needed.  It is intended to be used with batch, rather than interactive jobs.

To avoid overwhelming license server(s) with traffic during periods of frequent job submission, `jarvice-license-manager` keeps a cache of available tokens and updates it periodically for all configured license server(s).  A reservation system fronts the cache, so that job submissions can "reserve" feature tokens until the respective solver checks them out from the license server.

Users (or scripts/applications via API) must specify token reservation information at the time of job submission.  This should reflect the expected license use of the solver itself once it starts.

#### Reservation Life Cycle

* If tokens are available, a reservation is created which does not expire and counts against future reservation attempts; if not enough tokens are available, the reservation fails and the requesting job queues.
* Once the job starts (e.g. infrastructure queuing and container pulling for all parallel nodes in the job is complete), expiration is update to give the solver time to perform the actual checkout; typically, this is a 60 second period but can be increased or specified by the end user during job submission.  The expectation is that the solver will perform the actual checkout within this time period, which starts the moment the application environment is ready.  Most solvers attempt license checkouts immediately upon invocation, which fits this model.
* Expiring reservations are automatically deleted on the next license server update period.
* If the job is canceled, terminated, or ends before the expiration time of the reservation, the reservation is automatically deleted since the job is no longer active.

The reservation life cycle is intended to achieve 2 goals:

1. Favor queuing rather than failure, even at the slight expense of license utilization for short periods of time during high frequency job submission.
2. Facilitate consuming license tokens from outside of JARVICE concurrently, although this is not recommended.

Generally speaking, reducing the update interval period increases license token utilization under high load at the expense of putting additional pressure on the license server(s) themselves.

#### Fault Tolerance

While the `jarvice-license-manager` component itself is stateless and can be restarted, reservations are persistent and maintained in the control plane database.  At worst case, failure of the `jarvice-license-manager` component will lead to temporary queuing of jobs that request license token reservations.  This is corrected automatically when the service resumes.  The component is deployed as a single replica Kubernetes *Deployment* and restarts automatically on failure.

#### Additional Information

* JARVICE cannot anticipate what actual license tokens will be checked out by a given solver with a given set of parameters.  This is why the reservation requests are user-initiated, and it's expected that end users understand what tokens their jobs will require.  If users do not specify any license reservation tokens at submission time, JARVICE does not attempt to apply queuing rules to those jobs.
* The `jarvice-license-manager` component has an [API](#api) that can be used to inspect internal configuration as well as license token availability as reported by configured FlexNet servers.  Note that the API requires *Ingress* to be enabled so it can be accessed from outside the control plane.

[Back to Contents](#contents)

---

## Configuration

`jarvice-license-manager` is an optional component that must be explicitly enabled in the Helm chart, and configured by Kubernetes *ConfigMap*.  Additional configuration details follow...

### Service Configuration

To enable the service, set the Helm parameter `jarvice_license_manager.enabled` to `true` on the JARVICE control plane (upstream cluster).  Additional parameters:

### On Upstream clusters only

* `jarvice_license_manager.ingressHost` - set to the FQDN to request for Ingress; note that this must be an FQDN and not a URL; `jarvice-license-manager` assumes the path to its services is `/`.  If not specified, Ingress is not enabled.  Note that Ingress must be enabled if serving a multi-cloud/multi-cluster configuration, or if direct use of the [API](api.md) is desired.
* `jarvice_license_manager.JARVICE_LMSTAT_INTERVAL` - set to the number of seconds between license server token updates (runs `lmutil lmstat` on all configured servers, and garbage collects expired reservations)
* `jarvice_license_manager.JARVICE_HOSTALIASES` - JSON, see [Adding entries to Pod /etc/hosts with HostAliases](https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/) for format.  This is needed for FlexNet license clients to properly resolve server addresses when DNS is not sufficient, as explained in [Flex server host name resolution](#flex-server-host-name-resolution).

#### If using S3-compatible object storage to serve FlexNet `lmutil` binaries from

* `jarvice_license_manager.JARVICE_S3_BUCKET` - set to the S3 bucket to fetch from
* `jarvice_license_manager.JARVICE_S3_ACCESSKEY` - set to S3 access key
* `jarvice_license_manager.JARVICE_S3_SECRETKEY` - set to S3 secret access key
* `jarvice_license_manager.JARVICE_S3_ENDPOINTURL` - set to S3 endpoint URL, if not serving from AWS

### On Downstream clusters only
* `jarvice.JARVICE_LICENSE_MANAGER_URL` - should be set only in downstream clusters with the full URL to reach the license manager on the control plane.  Do not set on upstream deployments as the standard service URL will be used automatically within the control plane itself.
* `jarvice.JARVICE_LICENSE_MANAGER_SSL_VERIFY` - set to `"true"` to verify SSL certificates, assuming secure Ingress.

### On both Upstream and Downstream clusters

* `jarvice.JARVICE_LICENSE_MANAGER_KEY` - set to basic HTTP authentication token; can be set to `""` to disable authentication, but must match on all upstream and downstream clusters in a deployment.  Note that the use of authentication is strongly recommended when Ingress is configured.
* `jarvice.JARVICE_POD_SCHED_LICENSE_PRE` - set to `"true"` to attempt license reservations before queuing for infrastructure availability; default is `false`, meaning after infrastructure is available (see [Best Practices, Anomalies, and Caveats](#best-practices-anomalies-and-caveats) below); this value can be set differently for each downstream cluster in a deployment, as underlying infrastructure characteristics may vary.

For additional configuration parameters, see the `jarvice_license_manager` section in [values.yaml](values.yaml)

### License Server Configuration

#### ConfigMap

A Kubernetes ConfigMap is needed in the "system" namespace called `jarvice-license-manager`.  To create this ConfigMap, create a directory called `etc`, with the file `servers.json` in it (see below for format).  Then run the following command:

```
kubectl create configmap -n jarvice-system --from-file=etc jarvice-license-manager
```

(Replace `jarvice-system` with the "system" namespace if different.)

Note that the `jarvice-license-manager` component must be restarted if the ConfigMap is changed; alternatively, it can be reloaded via the API's [/reload](#reload) method.

#### Sample Configuration

`servers.json` specifies license servers to communicate with, pseudo-feature definition, project limits, and `lmutil` binary locations.  Note that `lmutil` itself is not distributed in this package and must be provided from an external source, such as S3 or filesystem.

```json
{
    "ansyslic1": {
        "config": {
            "name": "ANSYS_LICENSE_SERVERS",
            "value": "192.168.30.101"
        },
        "address": "192.168.30.101",
        "port": 1055,
        "binary": "s3:///flexnet/lmutil-ansys2019r3",
        "features": {
            "spaceclaim": {
                "a_spaceclaim_dirmod": 0,
                "a_spaceclaim_faceteddata": 1
            }
        },
        "projects": {
            "team1-design": {
                "a_spaceclaim_faceteddata": "25%"
            }
        }
    },
    "adslic1": {
        "config": {
            "name": "ADS_LICENSE_SERVERS",
            "value": "27009@adslic1.internal.io"
        },
        "port": "27009",
        "binary": "s3:///flexnet/lmutil-ads"
    }
}
```

The above configuration describes the following:

* 2 license servers - `ansyslic1` and `adslic1` are the Flex host names for each ones, respectively; these are typically stored in the license file itself and must be resolvable from the client - more information below
* Account variable name/value pairs that will be fed into a job needing a license from this server in the `config` key; these must match exactly what's set for a given payer in *Administration->Users* view, *VARIABLES* dialog; when a job is launched that has this account variable name/value pair, the JARVICE scheduler should ping the license manager with that pair as part of a license reservation request (if the user specified license features); `jarvice-license-manager` finds the server configuration based on that name/value pair; while the value of this variable will likely be the Flex server address, `jarvice-license-manager` treats it as opaque and application specific
* IP address or FQDN of license server in the `address` key - if not specified, the top-level key itself (e.g. `adslic1` in the example where `address` is not set) will be used - more information below
* A port number value in the `port` key - note that this must be specified separately since some JARVICE applications (e.g. ANSYS) imply the port number from their license account variable value; therefore the `jarvice-license-manager` must be told explicitly
* The `binary` key is required and specifies a URL for the `lmutil` binary to use against that license server; supported schemes are `http`, `https`, `s3`, and `file`; `jarvice-license-manager` will download each binary and then refer to it when counting licenses on that particular server during its update interval; the container is built with `redhat-lsb-core` packages to allow most known Flex clients to execute properly, and this should also be assumed to work only on `x86_64` architectures
* The `features` key is optional and is used to define "pseudo-features" that users can request at job submission time (e.g. to group many Flex features into one easier-to-remember symbolic name); subkeys are the pseudo-feature name itself (e.g. `spaceclaim`), which contain a mapping to actual Flex license features and counts; 0 means absolute 1, while non-zero values are multiplied by the counts specified by the user; in the `spaceclaim` example, if the user requests `spaceclaim:9`, the reservation will be for 1 `a_spaceclaim_dirmod` license and 9 `a_spaceclaim_faceteddata` licenses; note that users can request either pseudo features or actual features - `jarvice-license-manager` will always choose a pseudo-feature first and expand it even if it's named the same as an actual feature
* The `projects` key is optional and describes adjustments to make to maximum license reservation limits for given features; each subkey is the name of the project, prefixed with the team payer account (e.g. `design` project for `team1` payer); each subkey of that is the actual license server feature and either a maximum percentage of total (e.g. "25%") or an absolute maximum (e.g. `10`) to restrict for that project; note that these features refer to the actual Flex license feature, not a pseudo-feature that may have been defined

#### Flex server host name resolution

The Flex license server protocol requires a client to be able to reconnect to a host name that the license server thinks it's running on, which is usually specified in the license variable itself.  This needs to be resolvable from the client.  If the initial outbound address (`address` key) is an FQDN rather than an IP address, `jarvice-license-manager` will automatically create a host alias to resolve the top-level license server name (e.g. `ansyslic1`) to this value.  The top-level name must match what the Flex server thinks its host name is.  If using an IP rather than an FQDN, the top-level license server name must be resolvable using either DNS or explicit value configured via `jarvice_license_manager.JARVICE_HOSTALIASES`, which is a JSON representation of Kubernetes Pod `hostAliases` as described in [Adding entries to Pod /etc/hosts with HostAliases](https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/).

If you do not have access to the Flex license file itself to see the value of `SERVER`, you can determine this using an existing `lmutil` binary (usually supplied as an embedded componnet in a Flex-licensed application) as follows:

```
$ ./lmutil lmstat -lm -c 1055@192.168.30.101
lmutil-l34815 - Copyright (c) 1989-2015 Flexera Software LLC. All Rights Reserved.
Flexible License Manager status on Fri 12/18/2020 20:52

License server status: 1055@ansyslic1
    License file(s) on ansyslic1: 1055@192.168.30.101:

lmgrd is not running: License server machine is down or not responding. (-96,7:2 "No such file or directory")
```
Notice that the server answers and refers to itself as `1055@ansyslic1`, where `ansyslic1` is the server name.  This value must be used as the top-level key in the configuration file to define this license server, and must be resolvable from the `jarvice-license-manager` container.  During the stage of determining the server name, it is safe to ignore the error at the bottom.  Once resolvable, this command will provide successful status.

[Back to Contents](#contents)

---

## API

`jarvice-license-manager` provides a web service API for control and status.  It supports both GET and POST methods.  All response payload formats are JSON format unless otherwise specified.  API access requires Ingress to be enabled for the license server, or some other manually configured externally-accessible Kubernetes service (e.g. `LoadBalancer` type).  The following endpoints are defined...

### /servers

Returns configuration and status information for all servers, closely resembling the initial `servers.json` configuration file; note that certain keys are removed and/or adjusted for internal operation.

#### /servers/*server*

Returns configuration for a specific *server* (e.g. `ansyslic1`); notice that percentages reflecting feature max allowance in the optional `projects` scope are expressed as negative numbers - e.g. `"25%"` becomes `-25` internally; positive numbers refer to an absolute maximum.

#### /servers/*server*/lmstat

Runs the `lmutil lmstat -a` command against the specific *server*; note that this is performed on-demand and out of cycle with `jarvice-license-manager`'s periodic updates; return content-type is `text/plain` rather than `application/json` as with other methods.

#### /servers/*server*/reservations

Lists reservations currently active against the specific *server*.

### /configs

Lists server configuration grouped by name/value pair for account variables - e.g. `ANSYS_LICENSE_SERVERS=192.168.30.101`.  This is an index into the information available with the `/servers` endpoint.

#### /configs/*config*

Lists server configuration for a specific name/value pair (specified in *config*).

### /reload

Reloads `servers.json` configuration; note that a failure (e.g. all license server configurations invalid) will cause the web service to terminate; use this endpoint to reload after applying changes to the `jarvice-license-manager` Kubernetes ConfigMap.  This endpoint also updates license counts for each configured server, even if performed outside the configured interval.

### /update

Updates license counts for all valid configured servers immediately, even if called outside the configured interval.

### /gc

Garbage collects expired reservations immediately, even if called outside the configured interval.

### /reserve

Creates or updates reservations.  Parameters are as follows (GET or POST):

* `rsvid` - reservation ID, must be globally unique; in JARVICE this will be a job number
* `project` - optional project name to associate with reservation, used to calculate maximum available licenses; note that the project name should contain the payer account prefix (`<payer>-<project>` format)
* `kv` - key/value pair for the license server configuration (e.g. `ANSYS_LICENSE_SERVERS=192.168.30.101`) as a single string, or list of key/value pairs as serialized JSON; `jarvice-license-manager` will match the first one possible in order to find a configuration; note that some applications specify multiple license servers in variables, but only the first one can be used
* `expiration` - expiration timeout, in seconds, for the reservation; 0 means the reservation never expires; -1 means it expires immediately and is valid only when updating an existing reservation.
* `features` - comma-separated list of features expressed as *feature*:*count* - e.g. `spaceclaim:1`; multiple features may be specified

Returns 200 on success or HTTP error on failure - e.g. not enough licenses available, etc.

#### Notes

1. to update an existing reservation, do not specify `kv` - e.g. to change `expiration` from 0 (never) to 60 (1 minute from now)

### /live and /ready

Liveness and Readiness endpoints - return 200 when the service is up.

[Back to Contents](#contents)

---

## Usage

License reservation requests are made as part of job submissions in either the web portal or JARVICE API's `/jarvice/submit` method.  Jobs that queue based on license availability will be labeled as such with an appropriate substatus, visible in red text in the portal's *Dashboard* view, as well as in the various system administrator views relating to job inspection (events, job details, etc.).  Kubernetes status and events are appropriate marked for each Pod in a given job when it queues based on licensing as well.

### Web Portal

To request license-based queuing for specific features, users should populate the *License Features* field in the *OPTIONAL* view of the task builder used to submit jobs, e.g.:

![Example license feature request](portal-license-features.png)

In the above example, 2 features are requested with varying counts, and the final `/60` indicates to hold the reservation for up to 60 seconds after the job starts.  60 is the default, but any positive integer (indicating seconds) can be used.  The example feature request can also be specified as `cfd_base:1,anshpc_pack:2` since the default reservation timeout is used.  Note that any number of features may be specified in the comma-separated list, and each item can be either a pseudo-feature defined for the cluster (see [License Server Configuration](#license-server-configuration]) above), or an actual licensed feature.  The number after the colon (`:`) for each feature is the count to queue on for that particular feature, and must be specified.

### JARVICE API

License feature requests can be specified with the `licenses` key in the job submission JSON of the `/jarvice/submit` endpoint, e.g.:

```json
{
    "app": "ansys-fluids2020r2",
    "staging": false,
    "checkedout": false,
    "application": {
        "command": "fluent-batch",
        "geometry": "1342x768",
        "parameters": {
            "-v": "3ddp",
            "-i": "test.jou",
            "-mpi": "intel",
            "version": "202",
            "-u": false
        }
    },
    "machine": {
        "type": "n3",
        "nodes": 2
    },
    "vault": {
        "name": "projects2",
        "readonly": false,
        "force": false
    },
    "licenses": "cfd_base:1,anshpc_pack:2/60",
    "user": {
        "username": "not shown",
        "apikey": "not shown"
    }
}
```



(The above API example mirrors the Web Portal example above.)

[Back to Contents](#contents)

---

## Troubleshooting

All errors are logged, and in DEBUG mode (log level 10), large amounts of internal information is exposed.  Most error messages will be self explanatory.  Note that invalid license server configurations result in that configuration being eliminated from consideration rather than outright failure, unless no valid configurations are left.

In all cases the output of `jarvice-license-server`, in log level 10, is the suggested troubleshooting route.  This value can be set via the `jarvice.JARVICE_LICENSE_MANAGER_LOGLEVEL` variable.  The recommended production value is `20` (INFO).

[Back to Contents](#contents)

---

## Best Practices, Anomalies, and Caveats
1. In a multi-cloud/multi-cluster configuration, the license manager service must be exposed via Ingress (or some other service type to make it available from downstream clusters, such as `LoadBalancer`); it is strongly recommended that an HTTP basic authentication token is set in this case, to avoid unauthorized use, via the `jarvice.JARVICE_LICENSE_MANAGER_KEY` setting.
2. Reservations are persistent; `jarvice-license-manager` restarts will not cause problems other than temporarily being unable to create or update reservations.  The most immediate consequence of a service restart is that jobs queuing on license availability will continue to queue until the `jarvice-license-manager` service starts responding again.
3. Use the value of `jarvice.JARVICE_POD_SCHED_LICENSE_PRE` wisely depending on cluster characteristics; in an auto-scaling cluster it may be desirable to set to `"true"` in order to avoid costly scale-up until licenses are actually available.  In a fixed cluster, the tradeoff is between licenses being reserved potentially for too long a time (if set to `"true"`) due to lack of infrastructure availability, or not available once the infrastructure becomes available and other jobs running first instead (if set to `"false"`, its default value).
4. The scheduling algorithm is linear and jobs don't return to prior states once they progress; the progression is advisory limits enforcement, then released to the general queue to wait on license features or infrastructure (order depends on setting described above); therefore account limits take precedence over all conditions, including license availability.  Once a job progresses to the general queue, it will count against account limits even if it continues to queue for either license features or infrastructure.
5. While the `jarvice-license-manager` service is technically multi-architecture capable, the default configuration selects nodes of the `amd64` (`x86_64`) architecture only; this is to remain compatible with the site-supplied FlexNet `lmutil` binaries that must be executed to query the configured license servers.
6. Commercial ISVs (Independent Software Vendors) typically package FlexNet `lmutil` binaries along with their installations as they are commonly used for troubleshooting.  Please consult the respective documentation or contact the vendor directly for details if you are not sure where to find the `lmutil` binary.  Note that different applications use different versions of this binary, which is why each configuration for `jarvice-license-manager` supports its own specific `lmutil` binary.

[Back to Contents](#contents)

