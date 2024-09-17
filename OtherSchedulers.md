# Support for Other 3rd-party HPC Schedulers

JARVICE natively supports Kubernetes as well as [Slurm-powered](SlurmScheduler.md) clusters.  The former deploys an HPC-capable scheduler that leverages the existing OCI container runtime, while the latter relies on Slurm itself for HPC scheduling, plus Singularity for containerization.  The precise scheduling and containerization technology is opaque to end-users.

To support running workloads on other HPC schedulers, systems must provide Slurm-style command compatibility for select operations.  These can be implemented as wrapper scripts in `${PATH}`, for example.  Regardless of precise implementation, Singularity must also be deployed in order to run the scripted workloads submitted to the scheduler.

Additional components are required, including SSH connectivity.  Please review the precise requirements in [JARVICE Slurm Scheduler Overview](SlurmScheduler.md#jarvice-slurm-scheduler-overview) for the most up-to-date list.

* [Required Scheduling Concepts](#required-scheduling-concepts)
* [Minimum Required Emulation of Slurm Commands](#minimum-required-emulation-of-slurm-commands)
* [Enabling Emulation](#enabling-emulation)
* [Troubleshooting](#troubleshooting)


---

## Required Scheduling Concepts

### Mandatory

* Unique, system-wide job numbering assigned as a response to job submission
* Ability to submit arbitrary shell scripts as jobs
* Ability to assign arbitrary job names at submission time
* Ability to request resources such as CPU, GPU, and memory
* Ability to direct real-time job output to files
* Ability to identify queued versus running jobs
* Ability to abort running jobs
* Ability to submit jobs with preset walltime limits
* Ability to submit "held" jobs, to be released at a later time

### Optional

* Ability to target "partitions" (or queues) by name, and support arbitrary license tokens for license-based queuing
* Ability to optionally submit node-exclusive jobs
* Ability to return free-form scheduler information for specific jobs (unspecified format)

---

## Minimum Required Emulation of Slurm Commands

**IMPORTANT NOTE:** the JARVICE Slurm scheduler interface does not perform any error checking for format or parameterization - it assumes Slurm commands behave exactly as documented in the [Slurm Workload Manager Documentation](https://slurm.schedmd.com/documentation.html).  **Eviden does not support derivations and it's up to the developers of the emulation layer to ensure both input and output formats are precisely as expected.  Failure to do so will result in instability at best or complete failure at worst.**  This includes unhandled exceptions in the code, which can be seen by inspecting the `jarvice-slurm-scheduler` component pod logs in the control plane of either upstream or downstream clusters, depending on deployment.  Please ensure the implementation of the emulation layer is 100% correct before contacting Eviden support!

The JARVICE Slurm interface relies on a small set of commands with minimum parameterization.  Please note that these requirements may evolve or change over time without notice, so it's important to review this document and its revision history with each JARVICE release.

**If there is no direct emulation possible of specific parameters, the emulation layer should approximate the intended behavior of these parameters instead.  This may include successfully parsing but ultimately ignoring parameters, fabricating output, etc.**

### sbatch

All jobs are submitted with the [`sbatch`](https://slurm.schedmd.com/sbatch.html) command.  Note that it's not necessary to support both the long and short form of parameters, only the form listed below.

#### Mandatory sbatch Parameters

```
-J
-n
-N
-o
-H
--mem
--gpus-per-node
--time
--parsable
```

#### Optional sbatch Parameters

```
-p
-L
--exclusive
```

#### sbatch stdin

JARVICE passes a properly formatted shell script via `stdin`, which it expects will be executed once the job runs.

#### sbatch stdout

On successful submission, `stdout` should return only the system-wide unique job number associated with the newly submitted job.

#### sbatch return codes

Any nonzero code will be treated as an error, and the contents of `stderr` will be exposed to the end-user.  All successful submissions must return 0.

#### Additional sbatch notes

1. The `-A`/`--account` option will be used in the future to associate an account in order to allow "coordinators" to list queued jobs for multiple user accounts.  If it's already possible to list jobs for multiple user accounts as non-root users without account coordination roles, then this parameter should be parsed but can be safely ignored.
2. The job should be executed with the user identity that submits it; JARVICE will log in via SSH with said identity in order to execute the `sbatch` command.
3. Both the `stdout` and `stderr` of the job should be combined into the output file requested with the `-o` option.
4. It is possible for the control plane to specify additional parameters but these are passed through verbatim without inspection; this mechanism may be convenient to support advanced mechanisms not ordinarily possible with Slurm.  See the notes in [Slurm cluster nodes](Configuration.md#slurm-cluster-nodes) for more information.

### scancel

JARVICE uses [`scancel`](https://slurm.schedmd.com/scancel.html) to terminate queued or running jobs.

#### Mandatory scancel Parameters

```
-f
```

Following any of the above parameters, the job ID number will be specified; e.g.: `scancel -f 12345`.  This job ID number will match a previously submitted job as returned by `sbatch` (see above)

#### scancel return codes

Any nonzero code will be treated as failure to terminate the job, and the contents of `stderr` will be exposed to the end-user.  All successful terminations must return 0, and `stdout` is ignored.

### squeue

JARVICE uses [`squeue`](https://slurm.schedmd.com/squeue.html) for two purposes:
1. to list running and queued jobs
2. to determine exit status of terminated or completed jobs

The emulation layer can easily detect the second condition since JARVICE will specify a single job number to inspect.  Without this parameter, JARVICE expects information on all queued jobs.

#### Mandatory squeue Parameters

```
-u
-j
-t R,RH,RS,SI,ST,S,CG,SO
-t PD,RD,RF
-t all
-o %j|%A
-o %j|%A|%t
-o %j|%A|%u
-o %j|%A|%u|%t
-o %t|%M|%N
--noheader
```

Note that various permutations of the `-t` and `-o` parameters are listed; the emulation layer can implement those specific conditions rather than the entire Slurm-documented mechanism for each respective parameter and still be compatible with JARVICE.

The numeric job ID of a previously submitted job may follow the above parameters, indicating only information about that specific job should be returned.

#### squeue stdout

JARVICE expects `stdout` to be in the exact format specified by the `-o` parameter, including the omission of any human-readable header as specified by the `--noheader` option.  Please implement the precise format as specified in the Slurm documentation to avoid failures in the interface.

#### squeue return codes

Any nonzero code will be treated as failure, and the contents of `stderr` will be logged and optionally presented to the end user depending on the context.

#### Additional squeue notes

1. JARVICE performs post listing filtering to return only jobs that it submits, identified with a clear pattern in the requested job name at submission time.  The emulation layer may implement a more efficient filtering mechanism in case of very large queues as long as it's opaque to JARVICE.  Note that JARVICE does not concern itself with jobs it did not submit.
2. Jobs that are neither running nor queued are considered terminated.  In this case, JARVICE attempts an [`sacct`](https://slurm.schedmd.com/sacct.html) operation to determine the exit status.  Implementing emulation for `sacct` is not recommended.  Instead, the emulation layer should expose the exit status via `squeue` even if the job is no longer in queue, using whatever internal mechanism it has to query this in an opaque fashion.

### scontrol

JARVICE uses [`scontrol`](https://slurm.schedmd.com/scontrol.html) for two purposes:
1. to release "held" jobs
2. to request scheduler-specific information text for a specific job

The latter is optional functionality but can help system administrators troubleshoot resource request and scheduling issues from the JARVICE control plane.

### Mandatory scontrol Parameters

```
release
```

The numeric job ID assigned at job submission for a held job will be specified after `release` as a second parameter.

`stdout` is ignored.

### Optional scontrol Parameters

```
show job
```

The numeric job ID assigned at job submission will be specified after `job` as a third parameter.

The format of the information in `stdout` is arbitrary and may be any human-readable format that makes sense for the scheduler.

#### scontrol return codes

Any nonzero code will be treated as failure, and the contents of `stderr` will be presented to the end user in context.

---

## Enabling Emulation

Simply having the above-documented commands, plus the additional requirements such as `singularity` in `${PATH}` when the JARVICE scheduling service connects via SSH is sufficient to enable this layer.  JARVICE does not specify an absolute path to any of these commands.

To restrict the emulation to just JARVICE jobs, please see [Custom sbatch environment](Configuration.md#custom-sbatch-environment).

---

## Troubleshooting

Job submission as well as termination failures are communicated directly to the end-user and are therefore simpler to diagnose.  `squeue` failures will likely result in unhandled exceptions in the `jarvice-slurm-scheduler` component pod logs.  The most common case will be improperly formatted output.  In all failure cases, it's recommended to compare the exact output of `squeue` on a "real" Slurm cluster versus an emulated one, and ensure that all formatting is identical - including newlines and blank space.  In particular, compare all the permutations of `-o` and `-t` listed in [Mandatory squeue Parameters](#mandatory-squeue-parameters), and ensure that any returned states match a subset of those documented for Slurm.

