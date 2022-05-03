# Miscellaneous values

## JARVICE portal setup

### Environment

* `JARVICE_PORTAL_JOB_TERMINATE_LIMIT` (jarvice_mc_portal.env.JARVICE_PORTAL_JOB_TERMINATE_LIMIT): by default, **TERMINATE ALL** button in Admininstration.Jobs view terminates all current running jobs. It is possible to limit the scope of this action by setting `JARVICE_PORTAL_JOB_TERMINATE_LIMIT` value. Setting `JARVICE_PORTAL_JOB_TERMINATE_LIMIT: 10` will limit the terminate action to latest 10 jobs.