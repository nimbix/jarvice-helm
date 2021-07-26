# Long-running Job Notification Configuration

JARVICE can automatically notify users of long-running jobs.  In some cases, users launch interactive jobs only to leave them running after their work is done, consuming cluster resources and potentially acruing costs.  Email notifications can be used as a tool to remind users that these jobs were left running, and that they should shut them down if finished.

* [Parameters](#parameters)
* [Notification Email Template](#notification-email-template)

## Parameters

The following values can be set when deploying the Helm chart of Terraform overrides to affect long-running jobs:

Parameter|Value|Notes
---|---|---
`jarvice.JARVICE_LRJ_WALLTIME`|wall time, in hours, before a job is considered "long-running"|default: 0 (notifications disabled)
`jarvice.JARVICE_LRJ_PERIOD`|period between long-running job notifications, in hours|default: 0 (notifications disabled)
`jarvice.JARVICE_LRJ_BATCH`|`"true"` if batch jobs should be counted as well|default: `"false"` (only interactive jobs considered for notifications)
`jarvice.JARVICE_LRJ_PAYER_NOTIFY`|`"true"` if job "payer" should be notified as well as job "owner"|default: `"false"` (only job "owner" is notified)
`jarvice.JARVICE_LRJ_OWNER_BLACKLIST`|comma-separated list of "owner" usernames to avoid sending notifications to|default: all "owners" notified if noticications enabled
`jarvice.JARVICE_LRJ_PAYER_BLACKLIST`|comma-separated list of "payer" usernames to avoid sending notifications to|default: all "payers" notified if notifications enabled
`jarvice.JARVICE_LRJ_CURRENCY_FMT`|`printf`-style format string for currency, where value is a floating point number (`"%f"`)|default: `"$%.2f"`

#### Notes

1. Both `jarvice.JARVICE_LRJ_WALLTIME` and `jarvice.JARVICE_LRJ_PERIOD` must be set to non-zero values (in hours) in order to enable this functionality; if either parameter is unset or 0, notifications are disabled.
2. Notification email addresses are based on what users have configured in their respective accounts, with their registration address being set by default.  Users may change, add, or remove notification email addresses at any time, which could affect this functionality.
3. Settings are deployment-wide; if in the future additional self-service notification preferences are added to the platform, they would override deployment-wide settings.
4. Notification email delivery is "best effort", and does not validate addresses or retry on errors.  These notifications flow through the same component that ordinary job status emails do.
5. Settings can be changed via their corresponding environment variables dynamically in the `jarvice-scheduler` deployment, but this may change in the future.

## Notification Email Template

The default notification email template can be overriden via the `jarvice-settings` ConfigMap.  The default template is distribued in [jarvice-settings/mailLRJ.template](jarvice-settings/mailLRJ.template).  The following substitutions are supported, anywhere in the text:

Substitution|Meaning
---|---
`{{username}}`|JARVICE username of job "owner"
`{{nicename}}`|Human name of job "owner", as registered
`{{number}}`|Job number
`{{hours}}`|Number of hours job has been running (wall time)
`{{cpuhours}}`|Number of CPU hours job has been running (wall time multiplied by total number of CPUs)
`{{cost}}`|Approximate accrued cost of job, if applicable (includes currency symbol as prefix or suffix)

For additional information on customizing JARVICE templates, please see [Customize JARVICE files via a ConfigMap](README.md#customize-jarvice-files-via-a-configmap).

