# In-container Identity Settings and Best Practices
By default, the Linux user identity inside containers run on JARVICE is:

username: `nimbix`

group name: `nimbix`

UID: `505`

GID: `505`


Given most in-container storage is ephemeral, this should be a reasonable default for most applications.

However, there are cases where in-container identity needs to be either derived from the logged in user, or set explicitly to a specific value.  Example use cases include:
* Accessing an external license server (e.g. FlexLM), which uses the currently logged in user name for authorization to license features; this is common with commercial simulation applications, for example
* Accessing shared storage with existing files owned by specific UID/GID (e.g. a network mounted home directory)
* (Not recommended) running a containerized application that requires specific user identity; note that JARVICE ignores `USER` directives in `Dockerfile` and instead performs setup as `root`, and later drops privileges to a given user; also note that JARVICE treats the in-container home directory of this user as ephemeral, so any files for the account must still be stored in `/etc/skel` as a best practice.  The reason this is not recommended is that it is not likely to work as intended!

To facilitate these (and other) use cases, JARVICE supports overriding the in-container identity via the API or via the *AppDef* for a given application.  This, along with best practices, is documented in the [JARVICE Developer Documentation](https://jarvice.readthedocs.io), specifically in the following sections:

* [Docker Images on JARVICE - Container Images Differences - Best Practices](https://jarvice.readthedocs.io/en/latest/docker/#best-practices)
* [Nimbix Application Environment - Execution Model](https://jarvice.readthedocs.io/en/latest/nae/#execution-model)
* [Application Definition Guide - Reference](https://jarvice.readthedocs.io/en/latest/appdef/#reference)
* [The JARVICE API - Job Control - /jarvice/submit](https://jarvice.readthedocs.io/en/latest/api/#jarvicesubmit)

# Job Identity Defaults

JARVICE provides self-service to team payers accounts (and delegated team admins) to change the default in-container identity for jobs run by users on each team.  The *Identity* view of the *Account* section for a team payer (or team admin) account has the following options:

## System Default

This is the recommended setting.  Jobs will run with the standard in-container identity unless a `jarvice-idmapper` service is running in the same Kubernetes namespace, and one of the following is true:

* The JARVICE user name of the logged in user has a network home directory
* The Active Directory User Principal Name (UPN) of the logged in user has a network home directory

See the below for more information on using `jarvice-idmapper`

Users are encouraged to use the *System Default* settings unless there are specific reasons not to.  Also note that some applications from the Nimbix application marketplace may not behave as intended without this setting.

## Automatic (derived from logged in user)

This setting sets the in-container user name to match that of the logged in user into the JARVICE portal, or if the job is submitted via API, the JARVICE user who submitted the job.  UID and GID remain `505` for each.

This setting is most appropriate for presenting client identity to external license servers and other network services with clients that will pass the user name as an authorization mechanism.

## Explicit

This setting allows specification of the exact user name and group name to use as the in-container identity for all jobs run by the team, regardless of the user logged in.

There are limited uses for this setting and should be used with caution.  Typically it will be used similarly to *Automatic* except that the external network service would authorize the team, rather than the user.

Another rare use case would be to defeat the use of `jarvice-idmapper` (which only works in *Automatic* mode) for a specific team.  This is considered a very advanced scenario and should not be used unless it's fully understood.

## Allow Users to Override Job Identity Settings via API

This option is on (checked) by default.  If disabled, users on the team cannot submit jobs via API with an explicit setting for `identity`; if they do, the job is rejected with a 403 error.  Uncheck this only if you intend users to only run with the default identity settings for the team.

Note that users must use the API directly to override the job identity at submission time.  This is not possible via the web portal.

## Allow Applications to Override Job Identity Settings via AppDef

This option is on (checked) by default.  If disabled, applications that users on the team run cannot override the team default identity via AppDef.  Rather than rejecting the job submission, JARVICE will run it, but use the team default.  It does this because non-developer users have no control over how these apps run.  However, note that apps may request a specific identity because they require it, and may actually not behave as expected when run with team defaults.  Future versions of the JARVICE portal will warn users when an app tries to override the default but the team settings do not permit it.

# Using the jarvice-idmapper to Map In-container Identity

The `jarvice-idmapper` is an open source service that examines a given network volume and provides the identity of users that have a home directory on this volume.  The assumption is that the home directory should be owned by the UID and GID that should be mapped to a given user.

JARVICE automatically selects the Active Directory User Principal Name (UPN) if the user is logged in via Active Directory.  If not, it selects the user name that submitted the job (via portal or API), and attempts to map it.

If the `jarvice-idmapper` is deployed with a service in the same Kubernetes namespace as the JARVICE system services, the JARVICE job scheduler will automatically contact it.  Additionally, JARVICE will "deep mount" the home directory of the user in the container after it discovers the identity.  Deep mount means that if for example the home directory is on an NFS exported volume such as `server:/home`, JARVICE will mount into the container `server:/home/user` directly.   This is for security reasons.

Deploying `jarvice-idmapper` is a matter of enabling and configuring it in the
JARVICE helm chart.  This can be done either by updating the `jarvice_idmapper`
stanza in an `override.yaml` file or via additional `helm` command line
arguments similar to:

```bash
--set jarvice_idmapper.enabled=true \
--set jarvice_idmapper.filesystem.path=/home \
--set jarvice_idmapper.filesystem.server=nfs.my-domain.com
--set jarvice_idmapper.env.HOMEPATH=/home/%u \
--set-string jarvice_idmapper.env.UPNPATH=false
```

Alternatively, deploying `jarvice-idmapper` from outside of this helm chart can be done by cloning its [public Git repository](https://github.com/nimbix/idmapper) and following the instructions in the `README.md`.  Given that it's open source, if the mechanisms do not work for a specific scenario, users are free to derive their own version.  The interface is quite simple and can be easily modified.  Deployment scripts and YAML templates are included in the repository and instructions.

## Caveats of Using jarvice-idmapper

* JARVICE only supports NFS or *hostPath* shares, and does not support using *PersistentVolumeClaim* volumes.  This may expand in the future but is required since JARVICE actually modifies mount paths as described above.  In cases where NFS is not possible, the volume should be mounted on the host and *hostPath* should be used.
* If *hostPath* is used, this path should be mounted on all compute nodes, not just the node(s) running `jarvice-idmapper`
* `jarvice-idmapper` is only contacted if the team identity type is set to *System Default*; this prevents users from being able to impersonate the identity of other users and mount their home directory (read/write) just by knowing their user name.
* It is not currently possible to *not* mount a network home directory if `jarvice-idmapper` is used and a successful map occurs.
