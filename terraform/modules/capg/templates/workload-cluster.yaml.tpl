---
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ${cluster_name}
  namespace: ${namespace}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - ${pod_cidr}
    services:
      cidrBlocks:
        - ${service_cidr}
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: GCPCluster
    name: ${cluster_name}
  controlPlaneRef:
    kind: KubeadmControlPlane
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    name: ${cluster_name}-control-plane
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: GCPCluster
metadata:
  name: ${cluster_name}
  namespace: ${namespace}
spec:
  project: ${project_id}
  region: ${region}
  network:
    name: ${network_name}
    autoCreateSubnetworks: false
    subnets:
    - name: ${subnet_name}
      cidrBlock: ${subnet_cidr}
      region: ${region}
      purpose: PRIVATE_RFC_1918
      secondaryIpRanges:
      - rangeName: pods
        cidrBlock: ${pod_cidr}
      - rangeName: services
        cidrBlock: ${service_cidr}
---
apiVersion: controlplane.cluster.x-k8s.io/v1beta1
kind: KubeadmControlPlane
metadata:
  name: ${cluster_name}-control-plane
  namespace: ${namespace}
spec:
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        timeoutForControlPlane: 20m
      controllerManager:
        extraArgs:
          enable-hostpath-provisioner: "true"
    initConfiguration:
      nodeRegistration:
        criSocket: unix:///var/run/containerd/containerd.sock
        kubeletExtraArgs:
          eviction-hard: nodefs.available<0%,nodefs.inodesFree<0%,imagefs.available<0%
    joinConfiguration:
      nodeRegistration:
        criSocket: unix:///var/run/containerd/containerd.sock
        kubeletExtraArgs:
          eviction-hard: nodefs.available<0%,nodefs.inodesFree<0%,imagefs.available<0%
  machineTemplate:
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
      kind: GCPMachineTemplate
      name: ${cluster_name}-control-plane
  replicas: 3
  version: ${kubernetes_version}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: GCPMachineTemplate
metadata:
  name: ${cluster_name}-control-plane
  namespace: ${namespace}
spec:
  template:
    spec:
      instanceType: ${control_plane_machine_type}
      image: ${control_plane_image}
      rootDeviceSize: ${control_plane_disk_size}
      rootDeviceType: pd-standard
      subnet: ${subnet_name}
      serviceAccount:
        email: ${cluster_name}-control-plane@${project_id}.iam.gserviceaccount.com
        scopes:
        - https://www.googleapis.com/auth/cloud-platform
---
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: ${cluster_name}-md-0
  namespace: ${namespace}
spec:
  clusterName: ${cluster_name}
  replicas: ${worker_replicas}
  selector:
    matchLabels: null
  template:
    spec:
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
          kind: KubeadmConfigTemplate
          name: ${cluster_name}-md-0
      clusterName: ${cluster_name}
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: GCPMachineTemplate
        name: ${cluster_name}-md-0
      version: ${kubernetes_version}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: GCPMachineTemplate
metadata:
  name: ${cluster_name}-md-0
  namespace: ${namespace}
spec:
  template:
    spec:
      instanceType: ${worker_machine_type}
      image: ${worker_image}
      rootDeviceSize: ${worker_disk_size}
      rootDeviceType: pd-standard
      subnet: ${subnet_name}
      serviceAccount:
        email: ${cluster_name}-md-0@${project_id}.iam.gserviceaccount.com
        scopes:
        - https://www.googleapis.com/auth/cloud-platform
---
apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: KubeadmConfigTemplate
metadata:
  name: ${cluster_name}-md-0
  namespace: ${namespace}
spec:
  template:
    spec:
      joinConfiguration:
        nodeRegistration:
          criSocket: unix:///var/run/containerd/containerd.sock
          kubeletExtraArgs:
            eviction-hard: nodefs.available<0%,nodefs.inodesFree<0%,imagefs.available<0%
