# JARVICE Troubleshooting Guide

This guide can be used to troubleshoot basic issues with a JARVICE deployment.

------------------------------------------------------------------------------

## Table of Contents

### JARVICE deployment

* [Checking status of JARVICE system pods](#checking-status-of-jarvice-system-pods)
    - [Describe the pod(s) that are not in the Running state](#describe-the-pods-that-are-not-in-the-running-state)
    - [Pod status showing `ImagePullBackOff`](#pod-status-showing-imagepullbackoff)
    - [`jarvice-db` pod is in the `Pending` state](#jarvice-db-pod-is-in-the-pending-state)
    - [Multiple JARVICE system pods are in the `Pending` state](#multiple-jarvice-system-pods-are-in-the-pending-state)
        - [Check kubernetes node labels and taints](#check-kubernetes-node-labels-and-taints)
        - [Insufficient resources available](#insufficient-resources-available)
    - [`jarvice-dal` pods are continually restarting](#jarvice-dal-pods-are-continually-restarting)

### JARVICE HPC jobs
* [Job status problems](#job-status-problems)
    - [Job pods remain in Pending state (Kubernetes)](#job-pods-remain-in-pending-state-kubernetes)
    - [Job status does not change](#job-status-does-not-change)
    - [Job status changes are too slow](#job-status-changes-are-too-slow)

------------------------------------------------------------------------------

## Checking status of JARVICE system pods

When JARVICE does not appear to be operating correctly, the status of the
JARVICE system pods is the first thing to check.  This can be done with the
following `kubectl` command:

```bash
$ kubectl --namespace jarvice-system get pods
NAME                                              READY   STATUS      RESTARTS   AGE
jarvice-api-658bd7dcd-4zwbn                       1/1     Running     0          15h
jarvice-api-658bd7dcd-7bqk5                       1/1     Running     0          15h
jarvice-api-experimental-689974999b-2l7hl         1/1     Running     0          15h
jarvice-api-experimental-689974999b-5whpc         1/1     Running     0          15h
jarvice-appsync-654f585fbc-j45wj                  1/1     Running     0          15h
jarvice-dal-54c8db44cc-65ddc                      1/1     Running     0          15h
jarvice-dal-54c8db44cc-hbkkq                      1/1     Running     0          15h
jarvice-db-bf4449ccc-l8chx                        1/1     Running     0          43h
jarvice-mc-portal-6c84b8864-dn9dq                 1/1     Running     0          15h
jarvice-mc-portal-6c84b8864-rwnw7                 1/1     Running     0          15h
jarvice-mc-portal-experimental-767b57f49c-bqsgv   1/1     Running     0          15h
jarvice-mc-portal-experimental-767b57f49c-wts7t   1/1     Running     0          15h
jarvice-memcached-0                               1/1     Running     0          6d17h
jarvice-memcached-1                               1/1     Running     0          43h
jarvice-memcached-2                               1/1     Running     0          20d
jarvice-pod-scheduler-7d45c6c9cc-j5r4b            1/1     Running     0          15h
jarvice-scheduler-5f5b9b566d-7652b                1/1     Running     0          15h
```

A healthy running system should look very similar to the output above.  An
unhealthy system may show status' similar to this:
```bash
$ kubectl --namespace jarvice-system get pods
NAME                                 READY   STATUS         RESTARTS   AGE
jarvice-api-cfd76ff6f-2j8qn          0/1     ErrImagePull   0          67s
jarvice-appsync-766ddb4b-d4l9t       0/1     ErrImagePull   0          66s
jarvice-dal-679d6b44cd-dtg27         0/1     ErrImagePull   0          66s
jarvice-db-bf4449ccc-xqxp6           1/1     Running        0          42h
jarvice-mc-portal-75c949fd4d-99nnx   0/1     ErrImagePull   0          65s
jarvice-scheduler-867d454b86-rv6ct   0/1     ErrImagePull   0          64s
```

The sections below provide more troubleshooting information.  For more detailed
information on the lifecycle of kubernetes pods, visit:
https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/

### Describe the pod(s) that are not in the Running state

In order to get more detail on pods that are not "Running", execute the
following `kubectl describe` command to find out what the issue may be:
```bash
$ kubectl --namespace jarvice-system describe pods jarvice-dal-679d6b44cd-dtg27
Name:           jarvice-dal-679d6b44cd-dtg27
Namespace:      jarvice-system
Priority:       0

...

Events:
  Type     Reason     Age                  From                        Message
  ----     ------     ----                 ----                        -------
  Normal   Scheduled  2m37s                default-scheduler           Successfully assigned jarvice-paulbsch/jarvice-dal-679d6b44cd-dtg27 to dal1k8s-worker-08
  Normal   Pulling    72s (x4 over 2m32s)  kubelet, dal1k8s-worker-08  Pulling image "gcr.io/jarvice-system/jarvice-dal:jarvice-master"
  Warning  Failed     72s (x4 over 2m32s)  kubelet, dal1k8s-worker-08  Failed to pull image "gcr.io/jarvice-system/jarvice-dal:jarvice-master": rpc error: code = Unknown desc = Error response from daemon: Get https://gcr.io/v2/jarvice-system/jarvice-dal/manifests/jarvice-master: unknown: Unable to parse json key.
  Warning  Failed     72s (x4 over 2m32s)  kubelet, dal1k8s-worker-08  Error: ErrImagePull
  Warning  Failed     47s (x6 over 2m32s)  kubelet, dal1k8s-worker-08  Error: ImagePullBackOff
  Normal   BackOff    35s (x7 over 2m32s)  kubelet, dal1k8s-worker-08  Back-off pulling image "gcr.io/jarvice-system/jarvice-dal:jarvice-master"
```

The clipped describe output above shows that there is an issue pulling the
JARVICE container images.

### Pod status showing `ImagePullBackOff`

If kubernetes is unable to pull the JARVICE container images, it is either
unable to contact the `gcr.io` container registry or the value of
`jarvice.imagePullSecret` is not valid.  Be sure that your `gcr.io` registry
key was properly converted for use in your `override.yaml` values file.
Here is the command to get the appropriate string to use for
`jarvice.imagePullSecret`:

```bash
$ echo "_json_key:$(cat file_path_to/gcr.io.json)" | base64 -w 0
```

### `jarvice-db` pod is in the `Pending` state

This will typically occur when using persistence for the `jarvice-db` pod
and it is unable to bind the PersistentVolumeClaim.  A `kubectl describe`
of the PersistentVolumeClaim may provide more information.  That command
should look similar to the following:

```bash
$ kubectl --namespace jarvice-system describe pvc jarvice-db-pvc
```

Please review the following for more information on using persistence with
the `jarvice-db`:
* [Kubernetes persistent volumes (for non-demo installation)](README.md#kubernetes-persistent-volumes-for-non-demo-installation)
* [Persistent volumes](README.md#persistent-volumes)


### Multiple JARVICE system pods are in the `Pending` state

#### Check kubernetes node labels and taints

If `kubectl describe` of JARVICE system pods shows that kubernetes is
unable find any nodes to place pods on due to node taints, please review
the section on
[Node taints and pod tolerations](README.md#node-taints-and-pod-tolerations).

#### Insufficient resources available

If `kubectl describe` of JARVICE system pods shows that kubernetes is
unable find any nodes to place pods on due to insufficient memory or CPU
resources, it will be necessary to add another node to the kubernetes cluster
for `jarvice-system` pods.  This could entail adding more physical/virtual
nodes and/or modifying taints on nodes already joined to the cluster.

If modifying taints on already existing nodes, please review the section on
[Node taints and pod tolerations](README.md#node-taints-and-pod-tolerations).


### `jarvice-dal` pods are continually restarting

This is typically due to the `jarvice-dal` pods not being able to communicate
with the database.  If using a database outside of the one provided in
the `jarvice-helm` chart, check that it is accessible from the kubernetes
cluster.  If using `jarvice-db` as provided in this chart, be sure that it's
pod is in the `Running` state.

If the above issues can be ruled out, it may be necessary to disable the
NetworkPolicy for the `jarvice-db` pod and/or globally for all
`jarvice-system` pods.
This can be done by setting `jarvice_db.networkPolicy.enabled` to `false`
and/or setting `jarvice.networkPolicy.enabled` to `false` respectively.

------------------------------------------------------------------------------

## Job status problems

The JARVICE control plane manages job status from all attached downstream clusters (including the default in a single or multi-cluster configuration).  The system is designed to reconcile job status changes periodically to not rely on complex notification mechanisms or even require full-time connectivity.  When troubleshooting any job status issue, log levels of respective component(s) will need to be increased from `30` (errors and warnings only) to at least `20` (informatinal) or even `10` (debug, very verbose) in some cases.  See each section below for details

### Job pods remain in Pending state (Kubernetes)

On Kubernetes clusters, job pods must be "bound" to compute nodes before processing can begin.  `jarvice-pod-scheduler` runs downstream and on the default cluster and attempts to "best-fit" pods onto nodes, packing where possible, and ensuring jobs with multiple pods are "gang-scheduled" on like nodes.  Putting this component in log level `20` via the `jarvice.JARVICE_POD_SCHED_LOGLEVEL` setting is the minimum recommended value to see a summary of why nodes are being skipped.  To see precise (but highly verbose) details for each node evaluated, including why it's disqualified from scheduling a particular job, set the log level to `10` (debug).

Common reasons for job pods not being bound include, but are not limited to:

1. Insufficient resources (the most common).
2. Lack of "like" nodes when trying to schedule a multi-node job - nodes are weighed and grouped by weight.
3. Improper taints or node label mismatches.

### Job status does not change

`jarvice-sched-pass` (upstream control plane only) is responsible for all job status changes.  Putting this component in log level `20` via the `jarvice.JARVICE_SCHED_PASS_LOGEVEL` is generally sufficient to see why.  Most errors are well spelled out.

Common reasons for job status not changing include, but are not limited to:

1. Unable to communicate with downstream components - in this case, check the connection from upstream to downstream including any Ingress controllers downstream.
2. Failures (not timeouts) when communicating with downstream components - in this case, examine `jarvice-k8s-scheduler` downstream (on Kubernetes clusters) by putting it in log level `20` (or `10` for additional verbosity) via the `jarvice.JARVICE_K8S_SCHED_LOGEVEL` setting.
3. Job pods not binding to nodes (on Kubernetes) - see [Job pods remain in Pending state (Kubernetes)](#job-pods-remain-in-pending-state-kubernetes)
4. Pass "budget" insufficient and not all jobs can be examined - see [Advanced: Scheduler Performance Tuning](Scaling.md#advanced-scheduler-performance-tuning) in the *Resource Planning and Scaling Guide*

### Job status changes are too slow

Generally, this relates to capacity and scaling parameter issues.  Putting `jarvice-sched-pass` in log level `20` via the `jarvice.JARVICE_SCHED_PASS_LOGLEVEL` parameter is recommended to determine why.

Generally, see [Advanced: Scheduler Performance Tuning](Scaling.md#advanced-scheduler-performance-tuning) in the *Resource Planning and Scaling Guide* for information on how to overcome this issue.

------------------------------------------------------------------------------

