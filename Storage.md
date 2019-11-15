# User Storage Patterns and Configuration

JARVICE provides comprehensive mechanisms to attach end-user persistent storage to jobs dynamically.

* [Basic Pattern](#basic-pattern)
* [Configuring Default Vault for New Users](#configuring-default-vault-for-new-users)
* [Summary](#summary)

## Basic Pattern

The standard pattern for user persistent storage in JARVICE is for the system administrator to define it, either implicitly (via Helm Chart configuration), or explicitly (by managing "vaults" via the portal's *Users* view in *Administration*), and the end user to select it for workflows or share it with other users.  Regardless of the underlying topology, the metadata describing volumes is called a *Vault*.  The standard pattern also describes storage volumes as separate and assigned to each user in a 1:1 fashion, as implemented originally in the Nimbix Cloud, where each user has their own private storage.

### The Vault Object

The Vault object consists of a "plugin" type along with attributes.  JARVICE has various plugins, including the ability to access NFS or CephFS directly, or utilize a *PersistentVolume* in Kubernetes.  For most purposes, the *PVC* vault type should be used to assign *PersistentVolumes* to users and jobs.  This supports both dynamic and static provisioning, as well as all access modes.

### Selecting and Sharing Vaults

Users have the opportunity to select which vault to use for data when submitting a job via the task builder in the *STORAGE* tab.  Workflows that offer the ability to select files as part of the job parameters will automatically access files in the selected vault.  Once the user submits the job, the storage will be attached to the application across all nodes.  JARVICE transparently enables file sharing within a job and across multiple jobs if a *ReadWriteOnce* (e.g. block) storage volume type is used.  The application environment can read and write files to the `/data` directory, which is where JARVICE mounts the storage dynamically for each job.

Users can also share vaults with other users on their team, via the *Vaults* view in *Account*.  This includes restricting access to specific users.  Note that currently any shared vault is shared as both read/write.  However, if `jarvice-idmapper` is used as specified in [In-container Identity Settings and Best Practices](Identity.md) is used, not all users may have Linux permissions to write or even read from shared vaults.

### Sharing Large Volumes Among Multiple Users

While this is not a desirable cloud pattern, it may be useful for sites where a large "projects" share exists and users share files and run workflows from that data.  In this case the end users manage the directories and hierarchy of this share themselves.  This is common in traditional HPC environments.  Note that this is different than user home directories, which are ephemeral in JARVICE unless `jarvice-idmapper` is used as described in [In-container Identity Settings and Best Practices](Identity.md).

The recommended way to share large volumes among multiple users in JARVICE is to use a *PVC* vault that specifies both a storage class and a volume name.  This way a single *PersistentVolume* can be defined in Kubernetes to map to that storage, and it can be shared by multiple users.  Note that JARVICE supports all access modes and performs sharing transparently in the case where only *ReadWriteOnce* is supported, for instance (see above).

## Configuring Default Vault for New Users

There are 2 methods for creating default vaults automatically for new users, whether they register accounts explicitly (via invitation and registration) or implicitly (via SAML or Active Directory logon for the first time).  Note that this does not apply to the `root`, which gets an `ephemeral` vault instead.

### Helm Chart

The following values can be set either in YAML or `helm` command line:

|**Name**|**Value**|**Description**|
|---|---|---|
|`jarvice.JARVICE_PVC_VAULT_NAME`|16 characters or less, no spaces|vault name appearing in users' inventory|
|`jarvice.JARVICE_PVC_VAULT_STORAGECLASS`|Kubernetes `storageClass`|required for dynamic or static provisioning
|`jarvice.JARVICE_PVC_VAULT_VOLUMENAME`|Kubernetes `volumeName`|if set at the Helm Chart level, provisions the same volume for all users; see [Sharing Large Volumes Among Multiple Users](#sharing-large-volumes-among-multiple-users); leave blank if using dynamic provisioning
|`jarvice.JARVICE_PVC_VAULT_ACCESSMODES`|`ReadWriteOnce`, `ReadOnlyOnce`, or `ReadWriteMany`|Kubernetes access mode for volume (*PersistentVolume* dependent)
|`jarvice.JARVICE_PVC_VAULT_SIZE`|integer, in gigabytes (*Gi*)|size of volume to request (*PersistentVolume* dependent)

(Note that in `values.yaml`, these parameters are in the `jarvice` section rather than containing the `jarvice.` prefix - e.g. `jarvice.JARVICE_PVC_VAULT_NAME` is `JARVICE_PVC_VAULT_NAME` in the `jarvice` section.)

The above parameters will cause JARVICE to create a *PersistentVolumeClaim* per user on account creation, and describe it as a vault in their inventory.  Note that in order for this to happen, all parameters must be specified with the exception of `jarvice.JARVICE_PVC_VAULT_VOLUMENAME`, which is used only for statically provisioned volumes.  No vault is created for new user accounts if the 4 required parameters are not all set.

In the case where static provisioning is used, only 1 *PersistentVolumeClaim* per jobs namespace is created.  This is in line with binding rules in Kubernetes.

#### Example 1: YAML values for dynamically provisioned block volumes

```
jarvice:
  JARVICE_PVC_VAULT_NAME: block
  JARVICE_PVC_VAULT_STORAGE_CLASS: gp2
  JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  JARVICE_PVC_VAULT_SIZE: 32
```

The above values would provision a 32GB block volume per user on account creation using the `gp2` storage class (e.g. AWS EBS)

#### Example 2: YAML values for statically provisioned shared projects volume

```
jarvice:
  JARVICE_PVC_VAULT_NAME: projects
  JARVICE_PVC_VAULT_STORAGE_CLASS: projects-class
  JARVICE_PVC_VAULT_VOLUME_NAME: projects-volume
  JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteMany
  JARVICE_PVC_VAULT_SIZE: 100
```

The above values would provision a mount from a shared volume (e.g. NFS) where users exchange project data.  Note that this assumes a Kubernetes *PersistentVolume* exists with the name `projects-volume` and storage class `projects-class`.  Also note that the size may not be relevant in these types of volumes, but the best practice is to set it to the approximate size of the entire volume.


### DAL Hook

The `jarvice-dal` pods support running scripts as hooks to new account creation.  The [dal_hook_newuser.sh](jarvice-settings/dal_hook_newuser.sh) script in the `jarvice-settings` directory is a stub that can be used as the baseline for a custom script.  For information on how to deploy these site-specific customizations, see [Customize JARVICE files via a ConfigMap](README.md#customize-jarvice-files-via-a-configmap).

The `jarvice-vault` command inside the hook is used to create a vault for each user.  Note that vault definition is in JSON format.  It only makes sense to use this for NFS volumes and specific paths per user, when an appropriate *PersistentVolume* pattern is not available or the paths themselves must be customized.  This script also allows for pre processing such as custom code to create remote storage folders, etc.

#### Example dal_hook_newuser.sh to Map User Directories from NFS Share

```
#!/bin/sh

# note that a directory with the user's name must exist on the NFS server;
# additional logic may be needed here to create it, including ssh'ing to the
# NFS server and creating it with the appropriate permissions

exec /usr/bin/jarvice-vault "$1" create data nfs "{\"address\": \"nfs1.localdomain.com:/users/$1\"}"
```

The above example creats a vault named `data` for each user that mounts from `nfs1.localdomain.com:/users/<username>`, where `<username>` is the JARVICE username of the user account.  Note that this path must exist ahead of time.

## Summary

|Use Case|Recommended Configuration|Notes|
|---|---|---|
|Ephemeral storage only|*default*|Default system configuration, no changes needed|
|Private storage per user|All parameters set except `jarvice.JARVICE_PVC_VAULT_VOLUMENAME`|Requires dynamic provisioning for the storage class in Kubernetes|
|Shared storage across all users|All parameters set, including `jarvice.JARVICE_PVC_VAULT_VOLUMENAME`|Statically provisioned *PersistentVolume* per namespace|
|Custom|[DAL Hook](#dal-hook)|Expert configuration with unlimited flexibility using scripting|
