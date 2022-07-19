# Resource Planning and Scaling Guide

* [Overview](#overview)
* [Major Components Considered](#major-components-considered)
* [Load Scenarios Tested](#load-scenarios-tested)
* [Minimum System Requirements](#minimum-system-requirements)
* [Additional Considerations](#additional-considerations)

## Overview

This guide provides guidelines for resource and capacity requirements around the JARVICE control plane, including downstream clusters used in multi-cloud deployments.  Note that only control plane is covered, as compute resources vary greatly depending on use case and application workloads.

Also not considered is the Kubernetes control plane itself, which is recommended to be a high availability deployment for any type of production use cases.  Please see [Building large clusters](https://kubernetes.io/docs/setup/best-practices/cluster-large/) in the publicly available Kubernetes documentation for best practices.

If using a managed Kubernetes service (such as Amazon EKS or Google GKE), please consult the documentation of the respective provider for scaling recommendations.

## Major Components Considered

The JARVICE control plane is a service-oriented architecture consisting of a public interface (web portal and API), as well, as internal web services.  By default, JARVICE also uses its own database engine for storing system configuration and job history.

### Database deployment (jarvice-db)

This is the default MySQL-based database component, and cannot scale beyond a single replica in the default control plane configuration.  This is acceptable for typical deployments as the database in a JARVICE system does not handle high volumes of online transactions.  For massive scale, it may be best to manage replicated MySQL servers outside of the Kubernetes system.

### Data Abstraction Layer deployment (jarvice-dal)

The DAL is the central "business layer" for the JARVICE control plane, and manages configuration, policies, and security for all aspects of the system.  This component is also key to most operations, and therefore is critical to scaling.  As such, it receives the largest amount of resource of any single component in the control plane, and is designed to scale out with multiple replicas.

### "Upstream" Scheduler deployment (jarvice-scheduler)

The upstream scheduler receives scheduling and job control requests from the user interfaces and converts them to downstream requests targeting actual compute clusters.  In a single cluster configuration, downstream requests are handled in the same control plane, which is also the case for the "default cluster" in a multi-cluster configuration.  This is a scale-out component designed to support multiple replicas both for performance and high availabiity, although it does include large critical sections such as during job submission and job status reconciliation.  Distributed locking to govern these critical sections is handled automatically by the JARVICE control plane.

### "Downstream" Scheduler deployment (jarvice-k8s-scheduler)

The downstream scheduler receives scheduling and job control requests from the upstream scheduler (see above) and uses the Kubernetes API to create and manage these objects on the compute cluster.  Each downstream cluster (including the "default" cluster on the main control plane) runs a downstream scheduler deployment.

It does not communicate "back" to the control plane in any way, and instead uses a request/response mechanism to provide job status, etc.  It is a scale-out component with support for multiple replicas which does include some critical sections governed by JARVICE's distributed locking mechanisms as explained for the upstream scheduler.

### "Pod" scheduler deployment (jarvice-pod-scheduler)

The pod scheduler binds pending pods to nodes using gang scheduling and other HPC scheduling policies, and runs as an asynchronous event-driven process from the rest of the system.  Each downstream cluster (including the "default" cluster on the main control plane) runs a pod scheduler deployment.

The pod scheduler is a single threaded service which does not scale-out and is limited to a single replica.  It is generally not affected by high system load, and only "wakes up" when there are pending jobs queuing.

### Web portal deployment (jarvice-mc-portal)

The web portal provides front-end user interface services to end users, and is a stateless component that can be scaled out with multiple replicas.  It is also the largest consumer of the DAL and is more likely to be affected by DAL bottlenecks than its own scale under load.

### API deployment (jarvice-api)

The API provides end-user web-based API services for job control, status, and other functions.  Like the web portal it is a stateless component that can be scaled out with multiple replicas.  By default it limits inbound requests to 16 concurrent per replica, to avoid overloading the DAL (which is its main bottleneck).

### Other components

The JARVICE control plane deploys various other components that are inconsequential to scale and sized sufficiently for almost all cases.

## Load Scenarios Tested

The default control plane resource configuration is based on providing response and performance for 3 "high load" scenarios, as described below.  Any combination of these scenarios can exist at any given time and not require additional tuning of the control plane.

Scenario|Description|Notes
---|---|---
"Login storm"|20 users logging in concurrently|Expect 5-8x slowdown as worst case in this scenario, assuming logins are perfectly concurrent (highly unlikely); increasing DAL replicas can mitigate the slow down but this should be treated as peak load in most cases.
"Job submission storm"|20 concurrent job submissions|Job submission at this level should be highly parallelized and occur quickly without generating high load on the system.
"Job submission storm 2"|100 concurrent job submissions|`jarvice-api` minimum replicas should be increased to 7 in order to avoid HTTP 503 errors; `jarvice-scheduler` and the relevant downstream `jarvice-k8s-scheduler` replicas should be increased to at least 4 each for best performance.
Concurrent login sessions|20 users logged in at once, with a single job running, in the *Dashboard* view of the web portal|The default control plane configuraiton provides ample performance for this scenario; if other slowdowns are noticed as more users are logged in, increasing DAL replicas generally mitigates the situation.

### Additional Mitigation

Future versions of JARVICE will include support for horizontal pod autoscaling in order to adapt to peak load without consuming full time resource.  Note however that critical components such as the DAL already employ "burstable QoS" to allow automatic "scale-up" if resources are available.  All other things being equal, increasing DAL replicas should improve responsiveness for any system under heavy load, but note that the DAL is already sized with the highest resource requests of any component and may require additional control plane infrastructure planning to accommodate higher scale.

### Roadmap

Long term evolution of JARVICE always has a key focus on improving scalability of the control plane and reducing critical sections in order to improve performance and responsiveness.  Please check the [Release Notes](ReleaseNotes.md) for the most up to date information on enhancements and fixes.

**NOTE**: because of the extensive policies and functions of the business layers, as well as the cloud-native architecture and design, JARVICE should not be considered a high frequency scheduler.  For high frequency scheduling, it is best to launch a dynamic cluster as a job with an HPC scheduler embedded in its container.  Please refer to the [app-hpctest repository](https://github.com/nimbix/app-hpctest) for the most up-to-date example of this recommended pattern if high frequency scheduling is required as part of a pipeline.

## Minimum System Requirements

The system requirements below include a 50% buffer to support non-disruptive "rolling" updates of components.  Note that for high availability, it is recommended that the resources are provided by more than one server or virtual machine/instance.

### Upstream control plane (including the default cluster downstream scheduler)

* 24 CPUs (cores, threads, or vCPUs)
* 52GB of total available RAM

#### Example upstream control plane instances on various clouds

Please note that configurations may appear oversized in some cases but are required based on the available memory after the providers' overhead is taken into account.

Cloud infrastructure|Instance type|Instance Count
---|---|---
*AWS*|`m5.4xlarge`|3
*GCP*|`n1-standard-8`|3
*Azure*|`Standard_D5_v2`|3

### Downstream cluster control plane (cluster 1-n in multi-cluster deployment)

* 5 total CPUs (cores, threads, or vCPUs)
* 9GB of total available RAM

#### Example downstream control plane instances on various clouds

Please note that configurations may appear oversized in some cases but are required based on the available memory after the providers' overhead is taken into account.

Cloud infrastructure|Instance type|Instance Count
---|---|---
*AWS*|`m5.xlarge`|2
*GCP*|`n1-standard-4`|2
*Azure*|`Standard_D3_v2`|2

### Notes

* Does not include "compute" requirements, which is the capacity used to run HPC jobs; this should be sized according to use cases and application workloads expected at the expected scale.
* Terraform configuration for the various providers is configured as described above by default, with autoscaling up to 2x the instance counts for each respective deployment type (upstream or downstream).

## Additional Considerations

* All deployments' resource and replica parameters are tunable in the **override.yaml** file (originally defined in [values.yaml](values.yaml) for each respective deployment)
* Not all adjustments should be limited to replica counts - if experiencing container restarts, check for *OOMKilled* status, which would mean the deployment needs additional memory.
* Most JARVICE control plane components are not really microservices, and may benefit from increased **cpu** allocation rather than just additional replicas.
* Components in "not ready" state are generally not indicative of a resource problem, but rather a network issue.  Check that the cluster CNI plugin (e.g. `weave`, `kube-router`, etc.) is working correctly in this scenario.
