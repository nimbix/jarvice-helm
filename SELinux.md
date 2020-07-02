# SELinux Configuration for JARVICE

JARVICE can run jobs on worker nodes set to SELinux "enforcing" mode, as long as the underlying Kubernetes system and related components (such as CNI plugins) are able to operate in this environment.  Note that JARVICE always assumes Kubernetes is configured properly and networking functions correctly for pods and services.

## Configuration Parameters

The `jarvice.JARVICE_SELINUX_ENFORCING` parameter should be set to `"true"` if underlying worker nodes are configured in "enforcing" mode.  This parameter can be configured as a helm chart argument either on the command line or in an `override.yaml` file (derived from [values.yaml](values.yaml)).  Note that the default is "false", which assumes SELinux is disabled or in permissive mode.

Note that this is required for any cluster that will run jobs, upstream (adjacent to the JARVICE control plane) or downstream, and is to be considered a per-cluster configuration.  This means that for a given multi-cluster configuration, some clusters may require it and some may not.

When set to `"true"`, JARVICE uses a platform-level `init` mechanism to start in-container services such as `sshd` and *Nimbix Desktop*, if applicable.  Note that other services are not started via this mechanism, even if configured as `systemd` services in the container.

## Compatibility

`jarvice.JARVICE_SELINUX_ENFORCING` set to `"true"` is currently compatible with containers derived from Ubuntu 16.04 (xenial) or CentOS 7.  Newer versions may be supported but are not certified at this time.

For best results, it is recommended this option be set to its default value of `"false"` unless the target compute worker nodes are indeed in "enforcing" mode.

