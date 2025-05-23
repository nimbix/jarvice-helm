# Storage Management
## Overview
In terms of data and storage management, Jarvice does not manage volumes directly in the same way as Kubernetes. However, it provides a mechanism, Vault object, which holds metadata describing the storage volume locations and paths to access storage. The System admin can configure the user persistent storage explicitly through the Administration settings, or implicitly by predefined policies. Each user is typically assigned a separate, private storage volume.

Furthermore, Vaults are assigned upstream but refer to capabilities downstream, ensuring that the storage is collocated with compute for better performance. For more details on user storage patterns and configuration, refer to [Storage](Storage.md).

## Vault Attributes

| Attribute | Description |
| -------- | -------- |
|Zone of the storage  | - Abstraction of an area within which compute and other resources are located <br>- Relates to [federation](#federation) <br>- Users can only use compute in the same zone as a vault <br>- Some vaults can be unzoned, which can refer to transient storage (e.g. ephemeral) or external storage (e.g. object storage) |
| Volume | - Storage resource that allows containers to store and access data persistently <br>- Downstream-specific <br>- For Kubernetes downstreams, it generally refers to PersistentVolume (for which JARVICE generates and manages claims automatically).  <br>- For other downstreams such as Slurm, it generally refers to a mounted filesystem path |
|Subpath | - Separates volumes logically for multiple users and is especially useful for non-Kubernetes clusters or for clusters with large, shared filesystems attached, for example, traditional HPC|
| Size & access | - Size (in giga bytes) of the volume (where applicable) <br>- In many cases such as when referring to shared filesystem mounts, dummy values such as “1” are typically used for size |


## Managing Vaults
Vaults are managed by using two mechanisms as follows. 

- **Explicit:** The system administrator creates, manages, and assigns vaults for each user. 
- **Implicit:** By policy, the system administrator creates a vault template when inviting a tenant/payer. Each user in that tenancy/team inherits this pattern and the vaults are automatically created. 

In addition, end users can also share their vaults with other users on their team or tenancy. 

## Preparing Data/Storage for Vaults
Since JARVICE does not manage the storage by itself, it must exist before JARVICE can assign it through a vault. Based on the container management platform used, the storage is managed accordingly, and the following storage resources must exist. 

### Kubernetes using Persistent Volumes (via PVC Vaults)
In Kubernetes, the most efficient way to provision and manage storage is by using Persistent Volumes (PVs) and Persistent Volume Claims (PVCs). A Persistent Volume is a resource in Kubernetes that represent storage in a cluster, independent of the lifecycle of the pods. With a PVC, users or applications can request for storage by specifying the type and amount of storage required. Kubernetes binds it to the suitable PV accordingly.  

PVCs can request storage statically or dynamically, and the following storage resources must exist: 

- **Static provisioning:** Refers to the process by which PVs are pre-created by an administrator manually, while the PVCs can then be created by users to request specific storage. 
  - The **PV object** must exist. It holds the metadata about the storage such as capacity, access modes, etc. 
  - It is not restricted to a namespace and is cluster wide. 
- **Dynamic provisioning:** Refers to the process by which PVs are created automatically when they are requested by workloads through PVCs. 
  - The **Storage class** must exit. It is a template that defines how storage must be provisioned. PV object is dynamically created based on the Storage class. 
  - It is not restricted to a namespace and is cluster wide.

**Note:** Currently, it is not possible for applications to have several vaults mounted.

### Non-Kubernetes or other Filesystems
For non-Kubernetes environments, the underlying filesystem must be in place and accessible on the host machine such as Server or virtual machine in data center or cloud, where the data or vaults are being managed. (Unless an NFS vault is used in Kubernetes, which is no longer best practice. It is recommended to use PVC vaults for better efficiency.) 

Furthermore, the filesystem must have the appropriate permissions as follows: 

- For a static path without substitutions, it must be world-readable (at least) or readable by the JARVICE user ID in the job attached to it. 
- If user expects to be able to write data, it must be world-writable or writable by the JARVICE user ID in the job attached to it. 
- If using substitutions, JARVICE will attempt to create the subpath for a user, which means the path above must be either world-writable or writable by the JARVICE user ID in the job attached to it. 

Additionally, JARVICE has a mode in Kubernetes downstreams, which automatically sets volume mount path permissions to match the target job user ID when running work.  This makes it easy to use dynamic provisioning, especially in the cloud. 

#### Configuring Storage Volume for Slurm
For each user in Jarvice, a PVC is created as a vault inside the Slurm zone. The access mode is set as ReadWriteMany with the required size. Volume name is optional. However, ensure that the sub_path is set properly. The path must be READABLE and WRITABLE by the Jarvice user and dedicated to the current user.

**Note:** JARVICE does not directly interact with storage in any way other than from inside a job.  At this point, the permissions and privileges that exist in the runtime environment apply to storage as well.  In Kubernetes, they can still allow root access (which is then dropped) to do things like change directory ownership, but in Slurm, this is typically the target user that runs the container and cannot elevate. 

## Types of Vaults 
Broadly, there are three types of Vaults: 

- **PVC (Persistent Volume Claim):** This vault stores metadata associated with PVCs by linking the PVC to appropriate PV. In Kubernetes, it refers to a persistent volume, and in Slurm, it is used to define storage. For more information, refer to [Configuring Storage Volume in Slurm](#configuring-storage-volume-for-slurm).
- **NFS (Network File System):** This vault stores metadata and manages configuration of NFS based storage and binds the PVC. This is applicable only in Kubernetes downstream environments.
- **File System:**  This vault provides metadata about file system storage such as volumes, directories, and paths. The persistent files are stored in /data, regardless of downstream. This is applicable only in Kubernetes downstream environments.

## Selecting and Sharing Vaults
Users have an opportunity to choose the vault to use for data when submitting a job. Once the user submits the job, the storage is attached to the application. JARVICE transparently enables file sharing within a job and across multiple jobs if a ReadWriteOnce (e.g. block) storage volume type is used.

The application environment can read and write files to the **/data** directory, where JARVICE mounts the storage dynamically for each job. It is a best practice to store persistent data in **/data** directory, as a nimbix user. Users may transfer files to and from this directory without having to run the application. It can be accessed outside the application as well. 

Users can also share vaults with other users on their team, via the Vaults view in the Account section. This includes restricting access to specific users. Note that a shared vault is shared as both read/write currently. However, if **jarvice-idmapper** service is used, not all users may have Linux permissions to write or even read from shared vaults.

## Transferring Data in and out of Vaults 
Currently, Jarvice does not provide an integrated data transfer mechanism. Users must ensure that the data is transferred by using external tools or by designing the workflow in such a way that the data is transferred as needed, for the application to run. 

Here are the two ways of transferring data in and out of Vaults: 

- **Application domain data transfer:** Since vaults are not directly accessible by the users (e.g. cloud-provisioned file or block storage), this method involves accessing the vault by using an application, typically running inside a job, to transfer data. Here, JARVICE File Browser is the application which runs as a job and attaches to a vault, enabling the data transfer. 

  **Note:** In case of hybrid cluster using on-premises and cloud downstream, the data must be accessible from the downstream before the application is launched or as a part of a workflow to define.

- **Platform domain data transfer:** Considering user has access to underlying vault storage (e.g. on-site HPC or in the future, external object storage), this method involves transfer of data by directly interacting with the underlying vault storage by using native tooling like POSIX FS or for S3 API/tools, without running a JARVICE job. 

## Workflow of External Data Storage
External data storage refers to the data stored outside the local Jarvice environment, file servers, or storage systems, and is accessed by using APIs. Here, external storage typically refers to object storage. 

**Note:** JARVICE does not automate external data currently.   

### Application Domain Object Storage Patterns 
Generally, the closer the knowledge of data is to the application, the more efficient the data transfers can be. The most efficient way of data transfer to and from the object storage systems is when an application supports streaming directly or can communicate with the object storage native directly, like Amazon S3 for example. This is most effective because it guarantees that the application has knowledge of precisely what data to transfer, when, and can even parallelize this effort (e.g. transfer and computation). 

However, in case of standard applications that are designed to work with filesystem, to integrate object storage, there are the two patterns: 

#### Data Transfer to and from Ephemeral Storage (Before and after App Execution) 
This pattern is best embodied by the work done to enable the Illumina DRAGEN FPGA-based bioinformatics workflow on Google Cloud, by using Eviden baremetal servers in colocation.  

 In this workflow, jobs are invoked via the JARVICE API (which gets called by Google Batch) and the application parameters include both input and output objects/buckets.  By using a wrapper inside the application domain, input objects are downloaded from Google Cloud Storage (using S3-like API) and placed in transient ephemeral storage on a local filesystem. Then, the S3 URLs are rewritten to ordinary file paths in the dragen command-line and passed in as files.  Once the dragen application completes, the output files are automatically uploaded to the object storage bucket as parameterized.   

**Note:** The Eviden cluster has no persistent storage or shared scratch space – all transfers happen to ephemeral node-level storage. This is effectively a disk-less cluster as far as the user is concerned, despite local SSDs on nodes.  Google Cloud Storage is authoritative and the workflow transfers data from and to it automatically. 

In pseudo code: 

*Foreach command-line-argument beginning with “s3://”:<br>download object into local storage<br> 
rewrite argument to point to local storage path for object<br> 
run application with updated arguments <br>
if successful: <br>
upload output file(s) into target storage bucket* 

Note that the application must provide the logic and tooling to interface with the object storage and must also modify any command-line arguments as applicable for its solver.  The example above closely mirrors what is being done in production currently.  The application-domain wrapper script is [here](https://github.com/nimbix/jarvice-dragen-batch/blob/master/examples/google-batch.sh) in a public repository for your reference. 

#### Live Mount of Remote Object Storage 
Live mounting refers to the process of mounting an object storage service (such as Amazon S3) to the system in such a way that it functions like a real-time, accessible file system. The mounted storage can be accessed like other local directories, allowing users and applications to work with the objects stored remotely in the same way as they would with the files stored locally. 

Tools such as s3fs (general S3) and gcs-fuse (Google) with Kubernetes CSIs can be used to mount object storage that looks like filesystems.  However, this process has the following limitations: 

- Typically, this mechanism does not allow random access, so most implementations address this by using a basic “read ahead” method which downloads entire objects or large portions of them when a file is opened for reading.  This approach can cause large delays.  Since the system cannot determine whether subsequent reads will be sequential or random, it often caches the entire object locally. 
- HTTP(s) headers and connections (layer 7) are expensive, much less efficient than layer 4 protocols such as NFS. This is another reason why reads are cached in large volumes rather than initiating a connection for each minor read. 
- Local storage becomes a problem, since it’s the backing store for these objects; if they are not cached, they suffer from the problems described above. 
- It is possible that some pure streaming solution can exist (as google claims with gcs-fuse) but this is still to be validated with real world workflows at scale. 
- Some object stores have filename restrictions that differ from POSIX standards and may confuse applications – e.g. some are case insensitive (like S3). 
- Authentication can be complex in a multi-tenant/multi-user environment; this can certainly be helpful with the external data source management feature, but will also require changes to storage provisioning in JARVICE as it relates to jobs. 

It is possible to automate this mechanism in JARVICE at the platform level, which will solve the limitation related to multi-tenant/ multi-user environment, but the other limitations remain and is generally not recommended.  

This level of automation is best applied to Kubernetes, but if FUSE implementations are deployed on a Slurm cluster for example, it can work there too. Furthermore, system admins can mount large buckets via FUSE directly on cluster nodes and then create the corresponding vaults for the mount path for users.  The most obvious use case would be large reference data sets, but with all the performance caveats above.  

### Federation  
Federation refers to managing multiple clusters as a unified system, enabling cross-cluster coordination and resource sharing. In addition, Vault zoning refers to a process of grouping areas within which vault and compute resources are located.  

As described earlier, vault zoning directly relates to federation. They work together to provide secure, controlled access model for managing sensitive information across multi-cluster, multi-cloud environments. This works very well for HPC and low-latency network-attached storage, where storage and compute must coexist. (e.g. Lustre, GPFS and even NFS). 

External data (such as object storage) is treated as unzoned since it must be transferred or remote mounted anyway. For more information, refer to [Application Domain Object Storage Patterns](#application-domain-object-storage-patterns). 

### Advanced Topics 
#### Custom Storage/Vault Provisioning 
JARVICE provides a “hook” mechanism that can be used to provision storage and/or create vault objects the first time a user logs in. This initial log in action triggers a JARVICE account creation and custom code execution. The execution runs in the Data Abstraction layer (DAL) container, and thus, upstream only. 

Generally, hooks are shell scripts that execute custom commands to implement business logic around storage provisioning on a per-user basis.  However, advanced examples can also make Data Abstraction Layer (DAL) API calls as they are running inside the control plane perimeter. Moreover, the code can be implemented in Python rather than bash for such advanced versions. 

Here are a few examples of what can be achieved with these Data Abstraction Layer (DAL) hooks: 

- Provision and/or deprovision volumes underneath vaults. For example, call storage-specific APIs on external systems such as block storage or object storage. 
- Create external accounts on adjacent systems, for business/operational support or even user-facing mechanisms outside of JARVICE. For example, data transfer solutions outside the platform. 
- Create vaults using customized logic – users may have multiple vaults. 
- Configure storage parameters, such as quotas, on a per-account or per-project basis. For example, Lustre quotas. 
- Run any type of validation logic that may or may not be related to storage. For example, a failure exit status from user account creation hooks leads to login failure. 

It’s also possible to pass opaque metadata to Data Abstraction Layer (DAL)hooks when deploying JARVICE (e.g. site-specific data), or as part of team account creation (in the user invite function).  This metadata is available as an environment variable inside hook scripts, along with variables for other vault parameters. 

#### Kubernetes CSI Storage Types Supported 
JARVICE supports volumes with both the access modes ReadWriteMany and ReadWriteOnce for user-persistent data. In the former case, this is treated as a filer and attached to multiple pods.  In the latter case, this is treated as block storage and automatically fronted with a user-space filer that JARVICE provisions and garbage collects as needed.  This allows block volumes to be shared across users, jobs (multiple single jobs or multi-node jobs, or both).  The block storage sharing feature is built-in to JARVICE and transparent to jobs.  It can be used with both static and dynamically provisioned block volumes and is effective in cloud applications.  However, since the filer runs in userspace, it will not perform as well for very large-scale jobs as dedicated external filers or parallel filesystems. 

In Kubernetes environment, CSI (Container Storage Interface) drivers are managed by the infrastructure operator. JARVICE interacts with the Kubernetes API to select the appropriate CSI driver for storage operations. The choice of driver is determined by the storage class or persistent volume (PV) configuration, which is beyond the control of JARVICE. This process aligns with standard Kubernetes practices for how applications utilize storage.

