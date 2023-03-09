# JARVICE Queue Limits

* [Overview](#overview)
* [Multi-tenant Terminology for Limits](#multi-tenant-terminology-for-limits)
* [Resource Limit Types](#resource-limit-types)
* [Administrator Limits](#administrator-limits)
* [Self-service Limits](#self-service-limits)
* [Limits Lifecycle and State Machine](#limits-lifecycle-and-state-machine)
* [User Interface](#user-interface)
* [Per-cluster Concurrent CPU Restriction: mL](#per-cluster-concurrent-cpu-restriction-ml)
* [Additional Notes](#additional-notes)

## Overview

JARVICE provides mechanisms to limit concurrent usage of resources across global infrastructure.  These mechanisms are called *Limits*, and operate in the control plane at a "meta-scheduling" level.  Limits are placed on infrastructure, both on specific resources (e.g. machine types) and across all resources (e.g. concurrent CPU limits).  They apply to tenants, or teams of end-users, and to indivdual end-users.  There are two general levels of limits, both offering the same configuration capabilities:

1. **Administrator limits** - govern tenants/teams either individually (by "payer") or groups (by "billing code")
2. **Self-service limits** - tenant/team administrators can further apply granular limits at the team level or end-user level within the constraints of any Administrator limits applied

Each level of limit can apply individually - e.g. Administrator limits can exist without self-service limits, and vice-versa.  However, if Administrator limits are applied, team limits are constrained within them (e.g. team administrators can reduce resource use within the limits set by system administrators, but not increase it).

## Multi-tenant Terminology for Limits

Because JARVICE is a platform with multi-tenant capabilities, some terminology is used interchangeably whether it's deployed as an Enterprise product (generally single-tenant) or Service Provider product (generally multi-tenant), such as:

Term|Single-tenant meaning|Multi-tenant meaning
---|---|---
Tenant|Team or department|Customer company or organization
Payer|Main user account for team or department|Main user account for customer company or organization
Billing code|Attribute applied to payer account(s) in order to group teams or departments for accounting purposes|Attribute applied to payer account(s) for billing and invoicing outside of JARVICE

These terms are used throughout this section to explain the various limits capabilities.

### Notes

1. Payers can delegate self-service administrative capabilities to one or more user account(s) on their team.
2. Each payer account represents a distinct tenant or team; billing code can be used to logically group them for accounting and/or billing purposes.
3. Some large Enterprise deployments may benefit from mutli-tenant administration techniques, especially if the operations team is acting as an internal service provider; for this reason, multi-tenant capabilities are pervasive in the JARVICE architecture.

## Resource Limit Types

Each limit level (Administrator or self-service) operates on the same resource types:

1. **Job concurrency and scale limits for specific machine types** - use to limit use of specific resources - e.g. scarce resources such as GPUs, limited to specific users.  Machine types not included in limit definitions are not available for job submission for the users affected.
2. **Total CPU concurrency either for an entire tenant or per-user within a tenant, regardless of machine type used** - typically used for cost control or ensuring enough infrastructure is available.
3. **Combined** - concurrent CPU limits can used in combination with concurrency limits for specific machine types.

## Administrator Limits

System administrators can apply limits either to payer accounts or to billing code ranges.  Payer account limits override billing code range limits.  Configuration is via the *Administration->Limits* view in the portal.

### Sample Use Cases

Use case|Implementation
---|---
Limiting concurrent resource use for different tiers of tenants (e.g. academic versus commercial, or trial versus paid)|Limits for a billing code range - e.g. all trial users may have billing code 1 applied to their payer account, or all academic users may range between billing code 500 and 1000
Limiting concurrent resource use for an individual tenant|Limits for payer account
Exempting a specific tenant from concurrency limits for their tier|Limits for a billing code range + Limits for a specific payer account to override them

## Self-service Limits

Tenant/team administrators can apply limits either to the entire team or to specific users.  Individual user limits override team limits, if any.  Self-service limits obey the constraints set by Administrator limits on the account, if any.  Configuration is via the *Account->Limits* views.

### Sample Use Cases

Use case|Implementation
---|---
Limiting concurrent resource use for different machine types for the entire team (e.g. to limit use of scarce resources)|*Team default* concurrency limits for specific machine types.
Limiting concurrent CPU use for the entire team regardless of machine type (e.g. to limit spend)|*Team default* concurrent CPU limits regardless of machine type, either per team or per user
Limiting concurrent CPU use for the entire team within a specific set of machine types|*Team default* combination of both limit types
Exempting a specific user from all limits (e.g. power user)|User-specific limit with neither maximum concurrent CPU nor specific machine concurrency limits set
Applying higher limits to a specific user (e.g. power user)|User-specific limit with concurrent CPU and/or specific machine concurrency limits set

## Limits Lifecycle and State Machine

Limits are applied at the control plane (upstream) cluster level, for any and all downstream clusters (including default), as a "meta-scheduling" construct.  This means that jobs with limits applied will be in "held" state until concurrency constraints for that user, tenant, or groups of tenants can be met.  Once limited jobs meet concurrency limit constraints, they are "released" to proceed via the downstream scheduling technology (e.g. Kubernetes or Slurm).  Once released, it's up to the downstream scheduler to place and execute the job.  If infrastructure is not available, jobs will still queue.

![Job lifecycle state machine when limits applied](limits_state_machine.svg)

Released (but still queued) jobs still count toward concurrency constraints - e.g. if a 16 CPU job is released but queued downstream, and the user or tenant has a 20 concurrent CPU limit applied, a newly submitted 16 core job will be held for limits immediately after submission.

Note that other holding conditions may still apply after jobs are determined to meet limit constraints and released, such as license-based queuing.  This is evaluated **after** concurrency limits.

## User Interface

Jobs queued for limits will appear to end users with a substatus that indicates this on the *Dashboard->Current* view.

System administrators can see this substatus in job details in the *Administration->Jobs* view.

## Per-cluster Concurrent CPU Restriction: mL

The **mL** setting can be applied per cluster in the *Administration->Clusters* view.  A value greater than 0 will be used in *MIN()* calculations for concurrent CPU limits, when applied.  For example, if a specific job is governed by a 16 concurrent CPU limit, but submitted on a downstream cluster with an *mL* value of 8, the limit will be adjusted to 8 concurrent CPUs.  This value can be used to govern small downstream clusters without using specific per-machine limits, especially in situations where users submit jobs to multiple concurrent clusters.  For example, a team administrator may want to limit a given user (or entire team) to 128 concurrent CPUs, regardless of which downstream clusters jobs are submitted to.  Users may be limited to 8 concurrent CPUs on a specific small downstream cluster, but able to consume a further 120 concurrent CPUs on larger clusters simultaneously.

**IMPORTANT NOTE:** *mL* values apply **only** when concurrent CPU limits apply; otherwise ordinary infrastructure capacity is the initial arbitrer of resource availability.  *mL* values apply in both system administrator and self-service limits which define a concurrent CPU limit.

## Additional Notes

1. For the purpose of limits, cores and CPUs are used interchangeably; concurrent CPU constraints are calculated with the *cores* property of a given machine definition, as defined in the *Administration->Machines* view.
2. A specific team user can be overridden to exceed the team constraints, and is evaluated separately; system administrator limits should be used to govern the payer or billing code below this to enforce maximum limits, if desired.
3. In multi-zone deployments, self-service limits can only operate on machine types the tenant has access to.
4. All limits enforce concurrency, not total use over a period of time, and will not terminate jobs once released to be processed; for cost controls, on deployments where machines are priced, JARVICE will estimate the maximum montly spend for given limits as a guide.
