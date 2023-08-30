# JARVICE Scheduler Job Throughput Benchmark Suite

Scheduler throughput benchmarks to run from a client computer against a remote JARVICE API endpoint.

* [Client System Requirements](#client-system-requirements)
* [Job Submission and Start Benchmark - jobperf](#job-submission-and-start-benchmark---jobperf)
* [Kubernetes API Object CRUD Benchmark - crudperf](#kubernetes-api-object-crud-benchmark---crudperf)

## Client System Requirements

* Linux shell or Windows 10/11 PowerShell -- or:
* POSIX subsystem (e.g. WSL or Mac OS X)
* Python 3.x
* `requests` package installed with `pip3`

## Job Submission and Start Benchmark - jobperf

`jobperf` benchmarks the amount of time it takes to submit and run a set of jobs.  By default it times how long it takes for all jobs to enter a running state, then schedules termination for them.

The main purpose of `jobperf` is to tune scheduler and infrastructure parameters on JARVICE deployments based on Kubernetes compute clusters.

### Usage

Linux/POSIX with `/usr/bin/python3`:

```
./jobperf -h
```

Others:

```
python3 jobperf -h
```

### Examples

For illustration purposes, the following usage examples use a fictitious username, API key, and JARVICE API URL endpoint.  They also use the Linux/POSIX invocation method described above.

#### Basic

To submit, start, and schedule termination for 100 jobs:

```
./jobperf -u USER -k APIKEY https://jarvice-api.localdomain 100
```

#### "Busy Queue"

This test mimics a job submission storm on a cluster that is already running some number of jobs.

First, submit and start, but don't terminate, 100 jobs:

```
./jobperf -N -u USER -k APIKEY https://jarvice-api.localdomain 100
```

Next, submit, start, and schedule termination for 100 jobs:

```
./jobperf -u USER -k APIKEY https://jarvice-api.localdomain 100
```

The second command is the actual benchmark.

#### "Hot Cluster"

If testing on an autoscaling cluster, such as a public cloud endpoint, it's best to run the "Basic" benchmark twice.  Job termination is asynchronous, so check the job queue either in the JARVICE web portal (*Administration->Jobs*, then select *Active Jobs* from the drop-down) until all jobs exit after running the first iteration.  Then run the same test again, which will provide the job throughput benchmark free of variance from cluster autoscaling and container pull delays.

### System Logging

During a `jobperf` benchmark, the following Helm parameters are recommended:
* `jarvice.JARVICE_SCHED_PASS_LOGLEVEL=20` (upstream); note that level 10 may also be used for even more verbosity
* `jarvice.JARVICE_POD_SCHED_LOGLEVEL=20` (upstream and/or downstream); note that level 10 may also be used for more verbosity

### Troubleshooting

Failure|Reason|Notes
---|---|---
Traceback with *ModuleNotFoundError*|`requests` module missing|Install using `pip3 install requests` or appropriate OS package
Job submission fails with 401|Authentication Failed|Check the username and API key specified; use the `-d` flag to run in debug mode and dump the actual API JSON if necessary
Job submission fails with 503|Service Unavailable|Increase the number of `jarvice-api` service replicas on the JARVICE deployment, or reduce the concurrency limit with the `-l` flag; the default concurrency limit should not trigger this situation
Job submission fails|*Check error code*|Common causes: vault type invalid, machine type invalid, or network timeout
Jobs never start, or start too slowly|Infrastructure availability|Check to see if any pods leave *Pending* state using `kubectl get pods -n jarvice-system-jobs`; if some or all pods remain *Pending* after a long period of time, check the `jarvice-pod-scheduler` logs for why they are not binding; this is almost always due to lack of resources on the cluster
Jobs never start, or start too slowly|Pods bind but job status doesn't change|Check the `jarvice-sched-pass` logs for skipped jobs due to downstream timeouts, and inspect downstream cluster Kubernetes API deployment for performance and scale

### Performance Tuning

See: [Advanced: Scheduler Performance Tuning](../Scaling.md#advanced%3A-scheduler-performance-tuning) for parameter specification.

#### Recommendations

1. Increase the "pass budget" in the `jarvice-sched-pass` service if it's routinely logging that jobs are left unprocessed due to pass time budget limit.
2. Increase the "new job grace period" in `jarvice-sched-pass` service if it's logging that jobs are being garbage collected due to not enqueuing downstream.
3. Increase the `jarvice-k8s-scheduler` replicas as an alternative to #1, but note that this will put additional pressure on the underlying Kubernetes API
4. Increase the number of parallel workers for pod binding in `jarvice-pod-scheduler` if jobs are not binding quickly enough but note that this will put additional pressure on the underlying Kubernetes API

Ultimately, performance is highly dependent on the responsiveness of the underlying Kubernetes API, its `etcd` service, and the overall network bandwidth and quality between nodes.  Ensure that all the necessary steps are taken to properly size the Kubernetes services and leverage high-performance components such as solid state disks (SSDs) for local storage.  Network timeouts should also be carefully investigated as they could have a severe impact on overall performance if the root cause is not found.

## Kubernetes API Object CRUD Benchmark - crudperf

This benchmark times the parallel CRUD (Create, Read, Update, Delete) performance of the Kubernetes API using ConfigMap objects.  It requires an additional the additional package `kubernetes` installed via `pip3`, such as:

```
pip3 install kubernetes
```

### Usage

Linux/POSIX with `/usr/bin/python3`:

```
./crudperf -h
```

Others:

```
python3 crudperf -h
```

### Example

For illustration purposes, the example uses a separate Kubernetes namespace named `testing`; regardless of what you name it, it's highly recommended that you create a specific namespace for this benchmark.  It also uses the Linux/POSIX invocation method described above.

The following example times parallel CRUD using 16 threads for 1000 objects in the `testing` namespace:

```
./crudperf -l 16 -n testing 1000
```

### Sample Run Using Google Kubernetes Engine (GKE)

The following transcript should provide sample guidance on what a properly configured Kubernetes API may yield throughput-wise:

```
$ ./crudperf -q -l 16 -n testing 5000

*** CREATING OBJECTS ***


*** PATCHING OBJECTS ***


*** DELETING OBJECTS ***


*** SUMMARY ***

  # objects created:                5000
  Time to create all objects:       14.75 second(s)
  Time to patch all objects:        38.04 second(s)
  Time to delete all objects:       20.45 second(s)
  Total CRUD time on all objects:   73.23 second(s)
  CRUD performance index:           4096.47 object(s)/minute
```

### Notes

1. It may take several seconds (or minutes, depending on the total count value) for Kubernetes to fully delete all ConfigMap objects after this script ends.
2. To list objects while this script is running, or to delete orphaned objects in case of script failure, use the label selector `app=crudperf` - e.g.: `kubectl get cm -n testing -l app=crudperf` or `kubectl delete cm -n testing -l app=crudperf`
3. When relating to the JARVICE API, note that JARVICE creates 5 Kubernetes objects per interactive single-node job; therefore, using a count of 5000 would be roughly equivalent to the work needed to submit 5000 JARVICE jobs.
4. This benchmark does not measure any aspect of JARVICE performance itself other than what the underlying Kubernetes API can provide.  See [Job Submission and Start Benchmark - jobperf](#job-submission-and-start-benchmark---jobperf) for a JARVICE-specific benchmark.
