# CNI Support for MPI over InfiniBand

The following document is a HOWTO for how to enable Kubernetes support for using MPI over InfiniBand in JARVICE jobs.  Note that the referrenced components are managed by their respective third party maintainers.

## Howto enable IPoIB in Kubernetes

Assumptions
- working Kubernetes cluster with a functional primary CNI
- required drivers already installed for infiniband host adapter
- an existing IPoIB interface is up and active on the hosts
- This has only been tested with Mellanox infiniband cards and Mellanox OFED

### Required 3rd party tools
- [Multus](https://github.com/k8snetworkplumbingwg/multus-cni) project will be utilized to add the secondary IpoIB interface
- [ipoib-cni](https://github.com/Mellanox/ipoib-cni) from Mellanox
- [Whereabouts](https://github.com/dougbtv/whereabouts) for ipam

1. Install Multus by applying [multus-daemonset-thick-plugin.yaml](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/deployments/multus-daemonset-thick-plugin.yml). 
```
kubectl apply -f multus-daemonset-thick-plugin.yml
```
2. Deploy the [ipoib-cni](https://github.com/Mellanox/ipoib-cni/blob/master/images/ipoib-cni-daemonset.yaml).
```
kubectl apply -f ipoib-cni-daemonset.yaml
```
3. Install the whereabouts ipam.
```
git clone https://github.com/k8snetworkplumbingwg/whereabouts && cd whereabouts
kubectl apply \
    -f doc/crds/daemonset-install.yaml \
    -f doc/crds/whereabouts.cni.cncf.io_ippools.yaml \
    -f doc/crds/whereabouts.cni.cncf.io_overlappingrangeipreservations.yaml \
    -f doc/crds/ip-reconciler-job.yaml
```
4. Define the network for IPoIB with a NetworkAttachmentDefinition. Please modify ip range and master interface as required.

```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: jarvice-ipoib
spec:
  config: '{
  "cniVersion": "0.3.1",
  "type": "ipoib",
  "name": "jarvice-ipoib",
  "master": "ib0",
  "ipam": {
    "type": "whereabouts",
    "range": "192.168.0.0/24"
  }
}'
```

5. Validate that containers can launch and attach this secondary network by running the following pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ipoib-test
  annotations:
    k8s.v1.cni.cncf.io/networks: jarvice-ipoib
spec:
  restartPolicy: OnFailure
  containers:
  - image: us-docker.pkg.dev/jarvice/images/ubuntu-desktop:bionic
    name: ipoib-test
    securityContext:
      capabilities:
        add: [ "IPC_LOCK" ]
    resources:
      limits:
        jarvice.com/rdma: 1
    command:
    - sh
    - -c
    - |
      ls -l /dev/infiniband /sys/class/infiniband /sys/class/net
      sleep 1000000
```
