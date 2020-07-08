# Air gapped Network Deployment

JARVICE can be deployed in an "air gapped" network environment, provided the follow requirements are met:
1. A local v2 Docker container registry is deployed, or a registry service is available from the infrastructure provider with access from the secure network.
2. The underlying Kubernetes deployment is already compatible with the network environment - e.g. containers are being pulled from the above mentioned registry, etc.
3. At least one "jump" node (or instance) is available to transfer JARVICE software from the Internet over to the secure network; the best practice is for this system to be able to access the same container registry that is available to the secure network, and ideally, also the Kubernetes API itself.

## Supported Air Gapped Configurations

There are 2 supported configurations, although JARVICE can be made to work with even more restrictions beyond this.  In both of the supported cases, the following is true:
1. "Node" can be either a physical compute node, a virtual machine, or a cloud provider instance
2. "Jump Node" refers to a Linux node that has Docker installed as well as a Git client
3. "Install Node" refers to a Linux node that has a Kubernetes and Helm client installed, with admin-level client certificates for the Kubernetes API; note that for the preferred configuration, this is combined with the "Jump Node"
4. "Registry" is any v2 Docker registry - note that if using a cloud infrastructure provider, it is best to use that platform's secure registry service, if any, in order to avoid having to configure "insecure registries" in each node on the secure network side.
5. Ingress (or LoadBalancer) into JARVICE and JARVICE jobs must still be configured and accessible by whatever clients expect to access it, whether in the secure network or not.  This configuration is not covered in this document and is implementation specific.

### Configuration 1 (Preferred)

This topology is most resource efficient and simplifies the deployment as much as possible.

![Preferred Secure Network Configuration](secure_config_1.svg)

Note that in this topology only the "Jump Node" + "Install Node" environment must be able to access the container registry as well as the Kubernetes API; it does not need to be able to access the Kubernetes workers directly.  This node will be used to pull, tag, and push containers from upstream (Internet) to the secure container registry, and deploy+update JARVICE using the Kubernetes and Helm clients.

### Configuration 2 (Alternate)

This topology provides increased security by reducing the amount of access, but requires additional resources provisioned in the secure network as well as additional steps for installing+updating JARVICE.
 
![Alternate Secure Network Configuration](secure_config_2.svg)

In addition to mirroring containers to the secure registry, the jump node in this configuration must be able to mirror the [JARVICE repository in GitHub](https://github.com/nimbix/jarvice-helm) over to the install node.

## Mirroring containers

### System Containers

The script [scripts/jarvice-pull-system-images](scripts/jarvice-pull-system-images) can be used to pull, tag, and optionally push JARVICE system containers from the upstream registry to the secure registry, and should be run on the Jump Node for both initial installs and updates.  Run without arguments for usage.  If specifying a push registry and push repository, make sure to populate these values into `jarvice.JARVICE_SYSTEM_REGISTRY` and `jarvice.JARVICE_SYSTEM_REPO_BASE` respectively as helm chart or overrides options for deployment.  The value of `--jarvice-version`, to the left of the branch (e.g. starting with the first numeric digit), should be specified as `jarvice.IMAGES_VERSION`; the value to the left (e.g. `jarvice-master`) should be specified as `jarvice.JARVICE_IMAGES_TAG`.

If not using this script to push (e.g. if using an alternate method to transfer container images from one registry to another), be sure to match the repository base and the version tag with what is configured in the Helm chart or overrides options, as explained above.

### Additional Containers

To determine additional containers to mirror, run the following command in the `jarvice-helm` repository:

```grep "image:" values.yaml|awk {'print $2'} && grep  '_IMAGE:' values.yaml|awk '{print $3}'```

The example output will show what containers need to be mirrored, tagged, and pushed to the secure registry, one on each line:

```
$ grep "image:" values.yaml|awk {'print $2'} && grep  '_IMAGE:' values.yaml|awk '{print $3}'
nimbix/jarvice-cache-pull:latest
nimbix/lxcfs:3.0.3-3
nvidia/k8s-device-plugin:1.11
xilinxatg/xilinx_k8s_fpga_plugin:latest
jarvice/k8s-rdma-device:1.0.1
mysql:5.6.41
nimbix/postfix:3.11_3.4.9-r0
nimbix/idmapper
memcached:1.5
registry:2
nimbix/unfs3
alpine:3.8
```

Once mirrored, edit the entries in the `override.yaml` file to the new tags, by searching for the matching tags from the list above.

### Application Containers

Appsync cannot be used in an air gapped configuration, so application containers must be mirrored individually.  A matching application target must be created manually in the JARVICE system (can be performed as the `root` user), and then those applications can be marked public in the *Administration->Apps* view of the portal.  Note that the desired list of application containers must be obtained from Nimbix.  Each application target should also be explicitly pulled after being created to download the in-container metadata (e.g. AppDef).

## Additional Configuration

1. The Jump node user must log in with the upstream service account for the JARVICE system and application containers.
2. The `jarvice.imagePullSecret` value must be set to the secure registry's service account (or username/password) since the containers will be pulled from there to be executed.  Note that this is different than the upstream service account, which must be used on the Jump node.

## Updates

Container mirroring should be repeated when the system is updated, including the Helm chart or overrides configuration.  The updated version of JARVICE will be deployed automatically by running a Helm upgrade after updating the configuration parameters.  Note that as a best practice, all containers should be mirrored, or at least checked, in case they changed between versions following the Git update of the `jarvice-helm` repository.

## Limitations

The following limitations in air gapped environments currently exist:
1. JARVICE is a multi-architecture platform but the default mirroring scheme will only pull containers for the current architecture.  In most cases, the infrastructure architecture (e.g. `amd64`) will match between the Jump node and the nodes on the secure network side; if they don't, additional work will be required to create manifests so that multiple architecture containers are available (and pulled correctly) - this is currently not explicitly supported.
2. Appsync cannot be used and should be disabled in the `override.yaml` file before deploying; see above for information on mirroring application containers and creating the appropriate application targets in the system.
3. If using a self-hosted container registry on the secure network, serving over HTTP rather than HTTPS, the Docker daemons on all nodes (including Jump node) must be configured to support this as an "insecure registry"; it is highly recommended that either you use an infrastructure-provider secure registry, or apply CA-signed certificates (and associated DNS configurations) to the self-hosted registry to avoid this problem.
