#!/bin/sh
#
#   DAL calls this script, running as the same user ID as the DAL service,
#   to perform custom actions associated with unlocking a user account.
#
#   Parameters:
#       $1  user's login name
#       $2  user's API key
#
#   Returns:
#       0 if successful, nonzero if not; nonzero return will stop the
#       process of unlocking a user at the caller level
#

exec /bin/sh /usr/lib/jarvice/etc/$(basename $0) "$@"

