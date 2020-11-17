# JARVICE System Configuration Notes

## Configuring User Accounts

New JARVICE cluster deployments configure with a ```root``` and a ```jarvice``` user; the ```jarvice``` user should not be used directly, as it's used for storing synchronized application catalog metadata from an upstream service catalog.  Use the *Users* view of the *Administration* tab to manage user accounts.  Note tat users must be invited to the platform and should have an email address to complete the registration.

### Best Practices

JARVICE has a concept of teams, with team leaders known as "payers" - this concepts comes from its multi-tenant service provider platform lineage.  The following best practices should be observed:
1. Avoid using the ```root``` account to lead a team; instead invite a user, and have that user in turn invite other users from their own *Account* section to join their respective team
2. Avoid deleting user accounts, and this can cause referential integrity errors when auditing job history and other historical metrics; instead, unused user accounts should be locked or disabled

## Configuring Machine Types
Machine types in JARVICE are used to describe resources that a job requests along with metadata for workflow construction.  Machine types are configured in the *Machines* view in the *Administration* section of the web portal.

If using applications from a typical Nimbix service catalog, the best practice is to follow the [Resource Selection](https://jarvice.readthedocs.io/en/latest/machines/) guidelines in the JARVICE developer documentation to select machine names (the ```name``` field) so that these applications can leverage them properly.

Note that an initial JARVICE deployment defines some default machine types but these need to be adjusted to reflect the actual hardware in your cluster.


### Guaranteed versus Burstable QoS using cores and slots

In the table below, the first column refers to values in the JARVICE machine configuration, while the second column explains what JARVICE will translate into Kubernetes requests.

**WARNING**: The ```static``` CPU manager policy is, at the time of this writing, known to interfere with GPU operations and may have other issues.  As a best practice, do not configure any ```kubelet``` with this option.  This means that even when using Guaranteed QoS (as explained below), running a command such as ```nproc```, even if using the ```lxcfs``` device, will still show all cores/threads on the host machine.  To programmatically configure solvers and other CPU-intensive utilities to properly allocate threads on the allotted CPU, it's best to count the number of entries in ```/etc/JARVICE/cores```, as this will be set to reflect the core count specified in the machine definition.

The following conditions exist along with their recommended usecases:

**Condition**|**Kubernetes Request**|**Usecase**
---|---|---
```cores == slots```|```requests.cpu=cores``` (Guaranteed QoS)|use to request less than a full node's worth of resource, and should generally be used with ```static``` CPU manager policy
```cores < slots```|```requests.cpu=(cores-0.9), limits.cpu=slots``` (Burstable QoS)|use to request a full node's worth of resource; setting ```slots``` to something like 10% more than ```cores``` typically eliminates significant throttling from CFS, but a better alternative may be to pass ```--cpu-cfs-quota=false``` to the *kubelet* on nodes that primarily are used as full systems; note that JARVICE assumes that all Daemonsets and other system pods are requesting less than 1 full CPU core on each node, which is typically a reasonable assumption
```cores > slots```|```requests.cpu=slots, limits.cpu=cores``` (Burstable QoS)|use to oversubscribe work on the node since the ```cores``` value is always passed to the application to indicate how much work it should do (via ```/etc/JARVICE/cores``` in the runtime environment); this works with any CPU manager policy, but this method should be rarely used given the implications of oversubscribing systems

#### Best practice recommendations

1. For machine types that will primarily be used as full entities with parallel CPU-intensive solvers (e.g. CFD, etc.), set ```cores``` to the number of physical cores in the node, and ```slots``` to a value that is 5-10% above that.  Also consider using ```--cpu-cfs-quota=false``` to the *kubelet* on those nodes, and using labels and taints to control assignmnet of work (and respective ```properties``` in the JARVICE machine definition that describes them)
2. For nodes that will primarily be used for fractional containers, e.g. jobs that are GPU heavy but don't require much CPU/system memory resource, set ```cores``` and ```slots``` to equal values (representing some fraction of the node's CPU availability).  Consider using labels and taints to control assignment of work (and respective ```properties``` in the JARVICE machine definitions that describe them)
3. Rarely consider oversubscription, other than perhaps for testing.

See also: [Kubernetes CPU Management Policies](https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/), but see above warning on ```static``` CPU policy!

#### Examples (machine definitions)

The below examples suggest how to specify machine parameters in the web portal for various resource types.

##### Full 20 core node with 192GB of RAM

**Key**|**Value**
---|---
cores|20
slots|22
ram|188
properties|somekey=somevalue

Notes:
1. all other values should be set to something reasonable/appropriate; swap, scratch, and all slave resources are ignored on Kubernetes so they can just be set to non-zero values where a value is required
2. ram at 188 was determined by checking the "Allocatable memory" value when running ```kubectl describe node``` on an idle machine of that type - in this case we were told ```197620404Ki``` which equates to 188GB.  For safety it may make sense to drop this by a couple more GB, to something like 184GB or 180GB.
3. "somekey=somevalue" in properties should be used to identify some label (or labels, comma separated) that can be used as node selectors to ensure work gets placed on this nodes; you can use taints to make sure other work doesn't get placed, but that's controlled outside of JARVICE.  An example property may be ```node-role.jarvice.io/jarvice-compute=true``` to ask JARVICE to select nodes labeled with the ```jarvice-compute``` role.

See also: [Implementing Advanced Scheduling Techniques with Kubernetes](https://kublr.com/blog/implementing-advanced-scheduling-techniques-with-kubernetes/) for a good writeup on this

##### Fractional 4 core, 32GB RAM, 1 GPU

**Key**|**Value**
---|---
cores|4
slots|4
ram|32
gpus|1
devices (recommended)|lxcfs
properties (optional)|accelerator=nvidia-tesla-k80,cudaversion=somevalue

Note that it may be advantageous to label the node with the the CUDA version in the case that these vary by GPU types.  The NVIDIA GPU driver daemonset already presents a value for the ```accelerator``` label.

Also, in the case where applications running on this resource type will be GPU heavy rather than CPU heavy, consider reducing the CPU allocation rather then dividing it equally across all CPUs, so that non-GPU jobs can also fit on the node.

See below for the meaning of ```lxcfs``` device.

### Devices

The *JARVICE* column below refers to the value to populate in the "devices" field in the portal for a given machine definition; note that a machine may refer to various devices, and should be comma separated.  This list is accurate at the time of this writing.

JARVICE|K8S Resource request/behavior|Notes
---|---|---
```ibrdma```|```jarvice.com/rdma:1```|Requests RDMA over InfiniBand (may also support RoCE but this is not tested) - requires the [jarvice-k8s-rdma](https://github.com/nimbix/jarvice-k8s-rdma) plugin, which passes through all RDMA devices to the container when requested; regardless of how many devices are on the system, this plugin will always present ```1``` available (meaning "all"), or ```0``` if none are present; the main use case is for HPC which should assume use of all resources on each system
```lxcfs```|Applies ```lxcfs``` FUSE mounts in ```/proc``` for the container, to present ```cpuinfo```, ```meminfo```, etc. to reflect the ```cgroup``` values|Requires the [Kubernetes Initializer for LXCFS](https://github.com/nimbix/lxcfs-initializer) DaemonSet deployed on the cluster, or ```lxcfs``` installed and started on the host, and ```cpuinfo``` won't work correctly unless ```static``` CPU manger policy is used - but see above warning about this policy!
```privileged```|Runs application container in "privileged" mode and with host's `/dev`, giving access to all devices|**USE WITH EXTREME CAUTION!!!** - intended for testing/debugging only, and may be disallowed explicitly by cluster's *PodSecurityPolicy*
```fpga-xilinx-<*>[:n]```|```xilinx.com/fpga-xilinx-<*>[:n]```|Requests Xilinx FPGA of a specific type and DSA, where *<*>* defines the type and DSA (Xilinx-specific) and *n* specifies the number of devices to request, which defaults to 1 if not specified; requires a DaemonSet that deploys the [xilinxatg/xilinx_k8s_fpga_plugin](https://hub.docker.com/r/xilinxatg/xilinx_k8s_fpga_plugin/) container
```/<host-path>=<container-path>[:ro\|:rw]```|Applies *VolumeMount* to pod of a *HostPath* volume|Specifies an absolute path on the host (*host-path*) to bind into the container in *container-path* with either read/only (*:ro*) or read/write (*:rw*) permissions; if permissions are not specified, the default is read/only; note that commas cannot be used in either path
```*[:n]```|direct passthrough of resource request|Requests any other resource directly from Kubernetes, but cannot be used for resources that JARVICE already handles in the machine definition; use with caution as this is not checked and can cause jobs to not start properly; *n* refers to scale, and defaults to 1 if not specified

### Examples

#### Requests all RDMA devices, and maps a public data set mounted on the host

```
ibrdma,/mnt/dataset=/mnt/dataset:ro
```
(Note that the ```:ro``` is optional since this is the default)

#### Requets LXCFS, all RDMA devices, a public data set mounted on the host, and shared scratch mounted on the host
```
ibrdma,lxcfs,/mnt/dataset=/mnt/dataset,/mnt/scratch=/scratch:rw
```

## JARVICE HPC Pod Scheduler Notes

JARVICE provides an HPC-class scheduler for Kubernetes and starts by default with the Helm deployment.  This scheduler supports tightly coupled parallel jobs, using a concept known as "gang scheduling", to ensure that jobs don't run unless resources for all parallel pods can "fit".  The JARVICE Pod scheduler also delivers additional advantages over the ```default-scheduler``` Kubernetes scheduler, such as:
- *Best Fit* - available nodes are weighed, classified, and pods are placed on the nodes with the least amount of total capacity to fit the jobs' pods.  This ensures for example that nodes with GPUs don't run non-GPU work unless all CPU-only nodes are busy, etc.
- *Node Grouping* - pods will not be spread across nodes with different characteristics, ensuring that CPU-intensive parallel solvers will not suffer from timing issues on heterogeneous clusters; for example, it would generally not be a good idea to group 2 (or more) different CPU families to run a CFD algorithm as this may skew results with certain solvers; jobs remain in queue until a complete group of like nodes are available to run all pods requested
- *Configurable Resource Weighting* - users can configure a multiplier for resource counts, so that for example a single GPU can weigh more than 64GB of RAM if it has a multiplier of 64 (or more); note that this feature may not be available in all JARVICE versions (see [Release Notes](ReleaseNotes.md)) for availability

**Important Note**:
A multi-pod job is assumed to be multi-node; the scheduler does not attempt to pack multiple pods for the same jobs on the same node, so avvoid trying to schedule work on parallel fractional nodes if possible; e.g. if a 2 pod job is run, and both pods can fit on one node, the scheduler will not fit the this way - they will spread across 2 nodes only, which may result in unintended queuing.

### Best Practices
1. Avoid significant pod activity using other schedulers (e.g. default-scheduler) on the same nodes, especially with guaranteed QoS, as much as possible; this can lead to race conditions or to pod evictions after pods are bound to nodes that are accidentally overcommitted. It's fine to use constructs such as DaemonSets, but avoid constant scheduling activity as much as possible with other schedulers if using the JARVICE pod scheduler to place work on the same nodes
2. Use node roles wisely; this can be specified in machine properties
3. Avoid scheduling parallel fractional containers as much as possible (e.g. use mc_scale > 1 only for "full" nodes if possible); see Limitations above

### Troubleshooting

The default verbosity for logging in the pod scheduler is WARNING, which means warnings and errors only; to increase verbosity, edit the ```jarvice-pod-scheduler``` deployment, e.g.:

```kubectl edit deployment --namespace=jarvice-system jarvice-pod-scheduler```

and set the container environment value ```JARVICE_POD_SCHED_LOGLEVEL``` to ```20``` or ```10``` for INFO or DEBUG, respectively.  Note that DEBUG is extremely verbose but also details Kubernetes API call data and other important information.  Generally, INFO is enough to see why jobs are queuing, etc.

Once you edit this value, find the ```jarvice-pod-scheduler-*``` pod, and tail its logs - e.g.:

```kubectl logs -f --namespace=jarvice-system $(kubectl get pods --namespace=jarvice-system |grep ^jarvice-pod-scheduler|awk '{print $1}')```

Note that the above examples assume the JARVICE system namespace is configured as ```jarvice-system```; please adjust accordingly if you are using a different namespace.

## Running Custom Applications

Building, deploying, and running custom applications on JARVICE is the same as described in the [JARVICE Developer Documentation](https://jarvice.readthedocs.io/en/latest/) for the Nimbix cloud.  Note that if attempting to use the API, ensure to use the address of the endpoint configured in the local deployment rather than the upstream ```https://api.jarvice.com/``` from the Nimbix Cloud!

### Running "non-native" Applications

JARVICE also supports "non-native" applications, such as arbitrary Docker containers.  This is a good way to test functionality before exercising the full process to produce user-friendly catalog applications.  JARVICE provides a web-shell (via ingress or load balancer, depending on cluster setup), and also allows you to run arbitrary commands in these containers as "batch" jobs.

To create an application target for a "non-native" container, simply add it in the *PushToCompute* tab.  Be sure to place the correct registry address in the *Docker or Singularity Repository* field when creating the application.  This should be the same address you would pass into a ```docker pull``` command, versus an actual URL.  Note that this version of JARVICE does not support pulling Singularity containers (e.g. from ```shub://```), so limit container use to Docker.

Once you define the application target, there is no need to pull it explicitly - simply click on it to run it.  Pulling it loads metadata for the catalog (e.g. the *AppDef*), but this is not necessary with non-native applications since they don't usually provide a JARVICE-style *AppDef*.

Use the *Server* endpoint to launch a web-based interactive shell; note that if the container has ```/sbin/init``` installed, such as ```systemd```, it will be booted as if it were a machine first.  This works with almost any flavor of Linux as tested.  If there is no ```/sbin/init```, the web-based shell interface simply runs the default shell for the user ```root```.  It's best to ```su``` to the ```nimbix``` user once inside, but for non-native applications it's of minor consequence to run as the ```root``` user in the environment.

Use the *Run* endpoint to launch a batch command, and monitor the output directly in the web portal.  In this mode, the command runs as the user ```nimbix```, which JARVICE creates automatically on Linux flavors that support user management (such as containers based from ```centos``` and ```ubuntu``` official images).  Once the command completes, the job shuts down.  There is no ingress into the job if using the *Run* endpoint - this mechanism is meant to mimick the ```docker run``` command but without ```-it``` parameter.

### Differences versus "docker run"
1. ```ENTRYPOINT``` and ```CMD``` are ignored - see above for what each endpoint does
2. ```VOLUME``` directives are ignored - use ```/data``` to store persistent data, if the user has a persistent data vault configured in his/her JARVICE account; otherwise the ```/data``` volume is ephemeral
3. ```EXPOSE``` directives are ignored - JARVICE supports ingress via load balancer on popular ports automatically, or are reported in ```/etc/NAE/url.txt``` to connect to the web portal button for end users; if you want to configure a web service that end users can click into, consider creating a native JARVICE application from the container and configure a proper ```/etc/JARVICE/url.txt``` instead

### Other information
Please see [Nimbix Application Environment](https://jarvice.readthedocs.io/en/latest/nae/) in the JARVICE developer documentation for more information on the execution model for containers running on JARVICE.  Please note that JARVICE is optimized to run large scale parallel batch and interactive appliations versus microservices and web services.  Consider running service oriented applications directly on the underlying Kubernetes cluster instead.
