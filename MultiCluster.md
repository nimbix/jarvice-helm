# JARVICE Multi-cluter Overview

## Modes

### Federated

Federated mode is the default deployment of JARVICE XE, which involves discrete clusters unified with single sign on (via SAML or LDAP) and app sync from HyperHub.  In this mode each cluster is administered separately, and has its own complete control plane.

![Federated Cluster Architecture](federated_cluster.svg)

In federated mode, user identity and experience is identical across clusters, but users must explicitly target a cluster's control plane (e.g. web portal or API) in order to submit jobs to it.  There is no unified view of jobs running across clusters.

### Unified

Unified mode is an upstream/downstream architecture where a single control plane directs work to remote clusters by policy, and abstracts this from end users.  All administration is centralized, user identity and experience is identical, and all policies apply across the entire system of clusters.  Administrators target clusters by assigning them to machine definitions.  A downstream deployment runs on downstream clusters, which is a subset of services that run on the upstream cluster.  

![Unified Cluster Architecture](unified_cluster.svg)

Data management (other than explicit selection of data sets) is out of scope at the time of this writing.

## Definitions

### Cluster

Refers to a Kubernetes cluster or namespace running a full JARVICE deployment (Federated mode) or a downstream cluster deployment (Unified mode).  In unified mode, the upstream cluster runs both control plane and compute components on the same cluster.  This is known as the "Default" cluster target for jobs.

### Zone

Refers to a group of one or more clusters that a user explicitly selects.  Data sets (Vaults) can be bound to zones as well, to provide easy federation of data.

#### Zone Rules

1. All deployments have a default zone with a default cluster in it
2. All clusters must belong to a single zone (default or otherwise)
3. All machines must belong to a single cluster (default or otherwise)
4. Vaults can either belong to a zone or be unzoned
5. Users with vaults in multiple zones will be able to switch zones to access different vaults
6. Users with unzoned vaults will be able to select them regardless of what zone they are switched into
7. The JARVICE API will not allow jobs to be scheduled if the specified machine and vault are in different zones
8. Apps that refer to machines in a single zone will not be available to users after switching to a different zone
9. Regardless of zone, machine and app limits continue to apply to users


## Unified Cluster Storage Considerations

- All clusters in a given zone must be able to access datasets selected by users when switched into that zone.
- In a single zone configuration, all clusters must be able to access the same storage (e.g. network-attached), or have the same user *PersistentVolume* objects created to match volume/storage class requests from jobs.

### Example 1: Multi-cluster NFS

If all clusters can access the same NFS server (e.g. the network routing is in place to do this, and the performance is adequate for processing on the data remotely), a *PersistentVolume* can be created to point at the NFS server and this can be set as the default *PVC Vault* for all users logging in.  This would ensure all data is accessible from all clusters.  For more information on setting up such a shared *PersistentVolume*, see [Sharing Large Volumes Among Multiple Users](Storage.md#sharing-large-volumes-among-multiple-users) in *User Storage Patterns and Configuration*.

### Example 2: Dynamic Provisioning of Private Storage per User

If each cluster has a dynamic provisioner on a specific storage class, this can be configured as the default *PVC Vault* for users; each time a user runs a job on a cluster, the dynamic provisioner would create the storage target if it does not already exist.  Note that this mechanism requires the user to manage their own data on the target cluster, or assumes some underlying storage replication technology.  See [Example 1: YAML values for dynamically provisioned block volumes](Storage.md#example-1-yaml-values-for-dynamically-provisioned-block-volumes) in *User Storage Patterns and Configuration* for example Helm chart parameters to support dynamically provisioned private storage on each cluster.  The example assumes that the storage class is defined on each cluster the user runs compute on.

In a multi-zone configuration, the user will be able to explicitly manage their own data in each zone by switching into each zone and using an application to either generate it or upload/download it (e.g. *JARVICE File Manager*).  In order to enable the *JARVICE File Manager*, each node will need a machine type defined whose name matches the `n0*` wildcard, such as `n0`, `n0_z2`, etc.

## Multi-Zone use cases

Zones should only be defined when necessary, as users must make infrastructure topology decisions when running work in a multi-zone environment by explicitly switching into specific zones.  The following table describes typical use cases and whether they should be addressed with single or multi-zone configurations:

Multi-zone|Single Zone
:---|:---
User runs jobs in 2 different geographies, and data is not replicated automatically|User runs jobs on 2 different clusters that do not produce important data, such as ephemeral results or short-lived scratch data|
User runs jobs in 2 different data centers and uses discrete data for each one (e.g. for regulatory or compliance reasons)|User runs jobs on 2 different clusters on the same network|
 |User runs jobs in 2 different data centers or geographies but proper data replication is in effect|

### Technical Considerations

The following table describes the technical considerations when selecting single or multi-zoned setups; please note that these are guidelines only:

Single zone|Single or multi-zone[^1]|Multi-zone
:---|:---|:---
NFS/CephFS/(other NAS) is on the same physical network as compute|NFS/CephFS/(other NAS) is on a very low latency network to compute - e.g. across a campus, across data centers with dedicated connectivity - even Internet if using certain cloud storage|Against the law or policies to allow certain compute to access certain storage
Vault is ephemeral|PVC vault points to PV *storageClass* and *volumeName* in different clusters mounting the exact same storage|Vault is geographically separated by a high latency network (e.g. control plane in U.S., storage in Asia)
Storage is correctly replicated underneath JARVICE using 3rd party technology| |PVC vault points to a dynamically provisioned PV *storageClass*, where data will differ across clusters

[^1]: *choosing multiple zones for the either/or case largely driven by network latency between storage and compute*




