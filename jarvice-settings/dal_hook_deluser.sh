#!/bin/sh
#
#   DAL calls this script, running as the same user ID as the DAL service,
#   to perform custom actions associated with deleting a user account.
#
#   Parameters:
#       $1  user's login name
#       $2  user's API key
#       $3  delete user data? ("True" or "False", case sensitive)
#
#   Returns:
#       0 if successful, nonzero if not; nonzero return will stop the
#       process of deleting a user at the caller level
#

#
#   delete the ephemeral vault that was created in the newuser hook; if you
#   changed the newuser hook, you should change this one to correspond to avoid
#   account deletion errors
#
exec /bin/sh /usr/lib/jarvice/etc/$(basename $0) "$@"

