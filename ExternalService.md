# Using External Services for Interactive User Jobs

JARVICE supports using external Kubernetes services to load balance and route traffic to interactive user jobs.  The use case is mostly to support static IP or FQDN addresses that are persistent even between jobs starting and stopping, and may be desirable to use for long-running web services, etc.

* [Pattern Overview](#pattern-overview)
* [Service Configuration](#service-configuration)
* [End-user Configuration](#end-user-configuration)

## Pattern Overview

A system administrator would create a Kubernetes *Service* that targets pods based on label selectors that JARVICE assigns at job start time.  Each JARVICE job is made up of one or more pods, depending on the parallel scale a user selects at launch time.  3 basic modes exist:

1. Single endpoint --> first pod in a job (e.g. for "login node" capabilities)
2. Single endpoint --> any pod in a job (e.g. stateless web service started on all parallel workers of a job)
3. Single endpoint --> mode 1 or 2 across multiple jobs

Additionally, multiple endpoints can also target be used, but this is not a typical pattern.

## Service Configuration

Services should be configured to select either `jarvice-job-ipaddr` or `jarvice-pod0-job-ipaddr` label/value pairs.  An example snippet in a service definition would look like this:
```yaml
  selector:
    jarvice-pod0-job-ipaddr: user1-foobar
```

Note the `user1` prefix, which JARVICE automatically prepends based on the name of the logged in user so that one user cannot intercept another user's inbound traffic.  This prefix is added whether jobs are started via API or web portal.  The `foobar` part is the tag the user inputs into the *Task Builder* in the portal or the `ipaddr` key in the `/jarvice/submit` JSON payload for job submission.  The combination of the prefix and the user-specified tag must adhere to the rules specified in [Labels and Selectors | Syntax and character set](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set).  Note that the key name itself will be either `jarvice-job-ipaddr` or `jarvice-pod0-job-ipaddr`, to target all pods in a job, or just the first pod, respectively.

The above example targets the first pod of a job where the user `user1` specifies `foobar` as the *IP Address Tag* in the *Task Builder*.  To target all pods for any job the user `user2` specifies the `roundrobin` tag for, the service definition YAML snippet would look like this instead:
```yaml
  selector:
    jarvice-job-ipaddr: user2-roundrobin
```

### Notes
1. The user-specified tag is case sensitive.
2. Per the syntax and character set rules referred to above, the entire value must be 63 characters or less, including the JARVICE user name and the tag.
3. If a user launches multiple jobs with the same tag specification, and a load balancer service is used, this becomes the "Single endpoint --> mode 1 or 2 across multiple jobs" mode.

## End-user Configuration

Users must enter the case sensitive tag given to them by service providers or system administrators, minus the username prefix which is implied and cannot be changed.  This can be done in the *Task Builder's* *OPTIONAL* tab in the web portal, or via the `ipaddr` key in the `/jarvice/submit` JSON payload.  Note that the name of the key is historic - it refers to tag rather than actual IP address in this version of JARVICE.
