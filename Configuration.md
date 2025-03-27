# JARVICE System Configuration Notes

## Configuring User Accounts

New JARVICE cluster deployments configure with a ```root``` and a ```jarvice``` user; the ```jarvice``` user should not be used directly, as it's used for storing synchronized application catalog metadata from an upstream service catalog.  Use the *Users* view of the *Administration* tab to manage user accounts.  Note tat users must be invited to the platform and should have an email address to complete the registration.

### Best Practices

JARVICE has a concept of teams, with team leaders known as "payers" - this concepts comes from its multi-tenant service provider platform lineage.  The following best practices should be observed:
1. Avoid using the ```root``` account to lead a team; instead invite a user, and have that user in turn invite other users from their own *Account* section to join their respective team
2. Avoid deleting user accounts, and this can cause referential integrity errors when auditing job history and other historical metrics; instead, unused user accounts should be locked or disabled

## Configuring for MPI Applications

JARVICE supports various MPI libraries and fabric providers/endpoints.  The platform detects fabrics and advises application environments, which in turn configure specific applications to use either JARVICE-provided OpenMPI libraries or their own packaged versions.

### Enabling Cross Memory Attach (CMA)

Cross Memory Attach (CMA) accelerates communication between MPI ranks on a given machine by allowing shared memory rather than network transport to be used for message passing between those ranks.  Many Linux systems and images disable a fundamental feature that allows processes to `PTRACE_ATTACH` in order to facilitate this.  JARVICE detects CMA capabilities automatically and informs applications about this at runtime.  While certain exploits are possible if this is enabled, it is also known to improve performance as well as reliability of MPI applications, particularly if using TCP endpoints (e.g. on Ethernet-only fabrics).

To enable CMA, ensure the following command runs on each cluster worker node:
```
echo 0 > /proc/sys/kernel/yama/ptrace_scope || /bin/true
```

If it is not possible to affect node configuration directly, the `node_init` DaemonSet can be used.  Note that by default it does not explicitly run this command, but you can add it to the end of the `daemonsets.node_init.env.COMMAND` section in your `override.yaml` file, or insert the entire override for the `node_init` DaemonSet into your `terraform/override.auto.tfvars` file if using Terraform to deploy.

Note that JARVICE runs job containers with `CAP_SYS_PTRACE` automatically, so only `/proc/sys/kernel/yama/ptrace_scope` set to 0 is required to enable CMA for MPI applications.

For additional details on the general security implications, see [https://www.kernel.org/doc/Documentation/security/Yama.txt](https://www.kernel.org/doc/Documentation/security/Yama.txt).

**WARNING:** It is possible for jobs running on machine definitions with the `privileged` pseudo-device to reset the value of `/proc/sys/kernel/yama/ptrace_scope`, effectively disabling CMA on the particular node(s) they run on for all subsequent jobs.  This is especially true if using a default *Server* endpoint for an application where an in-container `systemd` runs system initialization scripts that may reset kernel parameters.  As always, the use of `privileged` is not recommended on production systems, and should be used with extreme caution regardless.

### Huge Pages

Certain RDMA-style provider endpoints, such as Amazon EFA, require the use of Huge Pages to ensure page-aligned, contiguous memory for certain operations.  Please consult the documentation for the particular fabric endpoint you intend to use for details.  Huge pages must be reserved on nodes (or instances) before the Kubernetes kubelet starts in order to make this an allocatable resource, and should be enabled as early as possible in the boot sequence of a node or instance to reduce the effect of memory fragmentation.

For example, for Amazon EFA, it is known that each MPI rank on a given node will require 2 endpoints of approximately 110MB of contiguous memory (or a total of approximately 220MB per rank).  On a 72 vCPU machine where each vCPU is used as an MPI rank (via the cores parameter in the JARVICE machine definition), this equates to 15840MB.  `c5n.18xlarge` instance types configured as node groups in Terraform reserve 15842MB of the `hugepages-2Mi` resource, which is enough to meet this requirement.

To support this in JARVICE, it is both necessary for Kubernetes kubelets to report either `hugepages-1Gi` or `hugepages-2Mi` resources of the appropriate size as allocatable, and for the corresponding machine definition to request either `hugepages2mi` or `hugepages1gi` as described in the [Devices](#devices) section of [Configuring Machine Types](#configuring-machine-types) below.  Note that the availability of 2Mi versus 1Gi huge pages is system dependent.  In most cases, 2Mi huge pages will suffice.

For additional details on huge pages in the Linux kernel, see [https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt](https://www.kernel.org/doc/Documentation/vm/hugetlbpage.txt).

### Increasing available space in `/dev/shm`

By default, JARVICE will run jobs with the Kubernetes default of 64Mi `tmpfs` attached to `/dev/shm`.  This is generally not sufficient for certain fabric providers and/or endpoints.  It is recommended that machine definitions used for MPI jobs have the `devshm` pseudo-device defined, which will allow up to half of physical RAM in `/dev/shm` (the default for a host-mounted `tmpfs` filesystem).

### Supporting OFI MPI stacks over InfiniBand

OFI MPIs (e.g. newer versions of OpenMPI and Intel MPI) require the InfiniBand IP-over-IB device to be passed through into jobs even to use the `verbs` provider of `libfabric`.  The [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) can be used to provide this level of passthrough.  When the `ibrdma` pseudo-device is used in machine definitions, JARVICE will set the annotation `k8s.v1.cni.cncf.io/networks` to `jarvice-ipoib` by default.  If you need to change this name, you can override it with the Helm chart value `jarvice.JARVICE_IB_CNI_NETWORKS`.

For a detailed example of deploying the Multus CNI, please see [CNI Support for MPI over InfiniBand](InfiniBandCNI.md).

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
```egl```|```jarvice.com/dri-optional:1```|Requests the EGL offload feature for accelerated 3D graphics - best effort, may result in software rendering if selected compute nodes do not have proper GPU stack configured; please see [Accelerated 3D Remote Display Capabilities](3D.md) for details
```gpuall```|N/A|Configures the NVIDIA runtime directly rather than using the Kubernetes device plugin; this can be used if the NVIDIA device plugin is not installed, or if it's not working properly (as is the case on some platforms); note that all GPUs will be plumbed into the job container(s), assuming the NVIDIA container runtime is installed and set as default on the target nodes.  If used with the `gpu` count set to 0 in the machine definition, ensure that you are using an alternate way to select a GPU-capable node, such as using a label selector in `properties`; note that since all GPUs are plumbed it's recommended that either a full node is used since there will be no device resource management between jobs on target node(s).  This pseudo-device can also be used to share all GPUs among all jobs running on a node, if appropriate.  Use with caution!
```lxcfs```|Applies ```lxcfs``` FUSE mounts in ```/proc``` for the container, to present ```cpuinfo```, ```meminfo```, etc. to reflect the ```cgroup``` values|Requires the [Kubernetes Initializer for LXCFS](https://github.com/nimbix/lxcfs-initializer) DaemonSet deployed on the cluster, or ```lxcfs``` installed and started on the host, and ```cpuinfo``` won't work correctly unless ```static``` CPU manger policy is used - but see above warning about this policy!
```privileged```|Runs application container in "privileged" mode and with host's `/dev`, giving access to all devices|**USE WITH EXTREME CAUTION!!!** - intended for testing/debugging only, and may be disallowed explicitly by cluster's *PodSecurityPolicy*
```fpga-xilinx-<*>[:n]```|```xilinx.com/fpga-xilinx-<*>[:n]```|Requests Xilinx FPGA of a specific type and DSA, where *<*>* defines the type and DSA (Xilinx-specific) and *n* specifies the number of devices to request, which defaults to 1 if not specified; requires a DaemonSet that deploys the [xilinxatg/xilinx_k8s_fpga_plugin](https://hub.docker.com/r/xilinxatg/xilinx_k8s_fpga_plugin/) container
```/<host-path>=<container-path>[:ro\|:rw]```|Applies *VolumeMount* to pod of a *HostPath* volume|Specifies an absolute path on the host (*host-path*) to bind into the container in *container-path* with either read/only (*:ro*) or read/write (*:rw*) permissions; if permissions are not specified, the default is read/only; note that commas cannot be used in either path
```$<key>=<value>```|Sets the environment variable named *key* to the value of *value* for containers running on machines of this type|The environment setting is passed verbatim, but note that some common variables are overridden during container initialization; use only for specialized variables for applications rather than common ones such as `${HOME}`
```devshm```|N/A|Attaches a `tmpfs` filesystem to the `/dev/shm` of containers run on this machine type equal to approximately half the size of physical RAM of the underlying node; recommended use for MPI applications as the default 64Mi `/dev/shm` may be insufficient for correct operation
```hugepages2mi:<n>```|```hugepages-2Mi:<n>Mi```|Requests 2Mi huge pages to enable, where `n` is in megabytes; underlying nodes must be configured to provide at least this number of 2Mi huge pages in order for jobs to be schedulable on them; note that this may be required for certain forms of RDMA utilized by MPI
```hugepages1gi:<n>```|```hugepages-1Gi:<n>Gi```|Requests 1Gi huge pages to enable, where `n` is in gigabytes; underlying nodes must be configured to provide at least this number of 1Gi huge pages in order for jobs to be schedulable on them; note that this may be required for certain forms of RDMA utilized by MPI
```*[:n]```|direct passthrough of resource request|Requests any other resource directly from Kubernetes, but cannot be used for resources that JARVICE already handles in the machine definition; use with caution as this is not checked and can cause jobs to not start properly; *n* refers to scale, and defaults to 1 if not specified

### Slurm cluster nodes

Machines definition is important, as many parameters will be passed to Slurm scheduler.

When creating machines, please consider the following available parameters:

* **Cores** will determine the value of cores requested per node. If sharing nodes between jobs is expected, this parameter will allow Slurm to properly allocate CPU cores to jobs (assuming Slurm configuration allows it).
* **Ram** will determine the amount of ram memory requested per node. Note that if `slurm.conf` do not configure `RealMemory` per node, value should be set to `0` to prevent errors at submission.
* **Gpus** will determine the amount of GPU requested per node.

It is also possible to restrict machine to a dedicated Slurm partition. To do so, add devices property of machine profile (see **Devices** section above), and add to the list `partition=all` for example to set partition to `all`, or `partition=Intel_32c_128Gb_GPU` for a specific partition, etc. Note that devices parameters are comma separated.

Machines can also be shared between jobs. To do so, simply add to devices list the `exclusive=False` property (comma separated). Note that by default, exclusive is assumed `True`. Note also that sharing enabling still requires that local Slurm administrator allowed it.

If needed, it is also possible to pass specific parameters to sbatch call (qos, account, etc) using the `sbatch_` prefix as device parameter. For example, to set qos as BIG for this machine, add in the comma separated devices list `sbatch_qos=BIG` which will result in `sbatch --qos=BIG ...` at sbatch call.

**IMPORTANT NOTE**: even if `exclusive=False` is used in the machine definition, a job that runs interactively (e.g. desktop, webshell, or other web service) will override this and request exclusive node access instead.  This is for security reasons due to Singularity's use of the host's network namespace.  Additionally, jobs that request GPUs will force node exclusivity as well.  GPU-level resource management for multiple containers is not currently implemented.

#### Overlayfs size

While default overlayfs image size is set by `JARVICE_SLURM_OVERLAY_SIZE` global variable, it is possible to define overlayfs size per machine, by setting `overlay=XXX` in machine devices comma separated parameters, with `XXX` the overlay size in mb. This parameter will precedence the global variable, and allow fine grained machine definition.

Note that if set to `0`, like with `JARVICE_SLURM_OVERLAY_SIZE` variable, scheduler will attempt to use writable-tmpfs singularity feature instead of overlayfs. This degraded mode allow some applications to run when singularity binary is not shipped with setuid feature.

#### Custom sbatch environment

On some system, it might be needed to load a specific environment for Slurm job's execution (a good example would be to load singularity via an Lmod module).

It is possible to load an environment during job, before any action (even before singularity execution), by adding a specific file to be sourced (must be source-able via "source" bash command) at job beginning. This file must be called `.jarvice_custom_env` and be placed inside `JARVICE_SLURM_SCRATCH_DIR` (which by default is the nimbix user's $HOME folder).

#### 3D-accelerated visualization using EGL

On systems with EGL-capable GPUs, JARVICE will automatically attempt to offload OpenGL rendering to them via EGL if the machine definition for a job requests at least 1 GPU.  Support for EGL offload is hardware and driver dependent, but generally works on any NVIDIA GPU with a recent driver installed on the host.  JARVICE falls back to software rendering if EGL is not available on the GPU.

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
