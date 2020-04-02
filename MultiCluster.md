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

Refers to a group of one or more clusters that a user explicitly selects.  Data sets (Vaults) can be bound to zones as well, to provide easy federation of data.  At the time of this writing, JARVICE XE supports only a single zone, but will support multiple zones in the future.  In single zone mode, the user is not allowed to select a zone explicitly, since there is nothing to choose from.  Users target work by selecting machines to run jobs on, which in turn target individual clusters underneath.

## Unified Cluster Storage Considerations

- All clusters in a given zone must be able to access datasets selected by users when switched into that zone.
- In a single zone configuration (such as what is currently supported), all clusters must be able to access the same storage (e.g. network-attached), or have the same user *PersistentVolume* objects created to match volume/storage class requests from jobs.
- Since users cannot explicitly select zones to manage data sets in this version, it is recommended that either all clusters have network access to the same storage (e.g. NFS), or some other data replication technology is in place to copy data to volumes between clusters transparently.  Alternatively, the user should have some non-JARVICE mechanism for uploading files to different clusters, and understand which machine types run on each cluster so they can ensure their data is in the right place.

### Example 1: Multi-cluster NFS

If all clusters can access the same NFS server (e.g. the network routing is in place to do this, and the performance is adequate for processing on the data remotely), a *PersistentVolume* can be created to point at the NFS server and this can be set as the default *PVC Vault* for all users logging in.  This would ensure all data is accessible from all clusters.  For more information on setting up such a shared *PersistentVolume*, see [Sharing Large Volumes Among Multiple Users](Storage.md#sharing-large-volumes-among-multiple-users) in *User Storage Patterns and Configuration*.

### Example 2: Dynamic Provisioning of Private Storage per User

If each cluster has a dynamic provisioner on a specific storage class, this can be configured as the default *PVC Vault* for users; each time a user runs a job on a cluster, the dynamic provisioner would create the storage target if it does not already exist.  Note that this mechanism requires the user to manage their own data on the target cluster, or assumes some underlying storage replication technology.  See [Example 1: YAML values for dynamically provisioned block volumes](Storage.md#example-1-yaml-values-for-dynamically-provisioned-block-volumes) in *User Storage Patterns and Configuration* for example Helm chart parameters to support dynamically provisioned private storage on each cluster.  The example assumes that the storage class is defined on each cluster the user runs compute on.
