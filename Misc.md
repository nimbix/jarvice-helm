# Miscellaneous values

## JARVICE portal setup

### Environment

* `JARVICE_PORTAL_JOB_TERMINATE_LIMIT` (jarvice_mc_portal.env.JARVICE_PORTAL_JOB_TERMINATE_LIMIT): by default, **TERMINATE ALL** button in Admininstration.Jobs view terminates all current running jobs. It is possible to limit the scope of this action by setting `JARVICE_PORTAL_JOB_TERMINATE_LIMIT` value. Setting `JARVICE_PORTAL_JOB_TERMINATE_LIMIT: 10` will limit the terminate action to latest 10 jobs.

## JARVICE Apps execution

### Environment

* `JARVICE_APP_ALLOW_PRIVILEGE_ESCALATION`: (default to false) if set to true, unlock privilege escalation inside apps containers 
during execution. This allows sudo or su commands usage if properly configured in pulled image. Note that this 
variable only unlock privilege escalation at kernel level: it does not configure sudo nor install it. Sudo installation 
and configuration as to be made by app packager.
