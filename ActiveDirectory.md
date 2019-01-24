# Active Directory Authentication Best Practices

JARVICE supports authentication against Active Directory using LDAP binding.  For simple user authentication, a service account is not needed.

## Overview

Each Active Directory scope or principal must be served with a JARVICE "payer" (or team) account.  Users that are part of that scope can then log in to JARVICE using their standard AD credentials, and inherit permissions and privileges from the payer account.  Note that each user who logs in via AD will have an internal JARVICE account automatically generated and maintained by the system, but team leaders can act on these accounts as if they had manually invited them.

When configuring LDAP for Active Directory, specify a base DN that describes the security principal for the group you are looking to authorize for that team.  To authorize multiple groups, create multiple teams (each needing its own "payer" account).  The ```dsquery``` tool (Windows) can be used to determine the base DN for any object in the directory, e.g.:

```
>dsquery user -name Test User
"CN=Test User,OU=dev,OU=corp,DC=acme,DC=io"
```

In the above example, to authorize multiple users from that scope, you would specify the base DN as `OU=dev,OU=corp,DC=acme,DC=io`

## Authorizing Machines and Apps to Active Directory

Once you've created a team that can authenticate AD users, you can assign privileges to machines and apps in the JARVICE system, and add the required privileges to the team "payer" account to authorize these objects for the given team.  This way, to authorize different objects to different teams, each would have its own set of privileges to match against machines and apps that offer them.

### Alternative: Team-visible Private Apps

When creating apps with PushToCompute, any team member can elect to make the app "team-visible"; for all other users in the team, it will show up in the *Team Apps* view of the *Compute* section.  This is a self-service way for team members to share applications without having to publish them and have administrators assign privileges to them.

## Troubleshooting LDAP login failures

The utility `jarvice-ldap-bind` in the pod(s) behind the `jarvice-mc-portal` deployment can be used to debug LDAP login failures that can be caused by either URI or user schema problems.  It can be used interactively or as a single command, and gives information as to what fails in more detail.

To use `jarvice-ldap-bind`, first find the name of any of the `jarvice-mc-portal` pods in the namespace where the JARVICE system is deployed.  For example, if the namespace is jarvice-system, the following command will list said pods:

```kubectl get pods -n jarvice-system |grep ^jarvice-mc-portal```

Any of the pods listed, if in `Running` state, can be used.  Simply use the `kubectl exec` command (with the optional `-it` argument if interactive) to run.  For example, this prints the usage assuming one of the pods is named `jarvice-mc-portal-746f94ff65-76xr6`:

```
kubectl exec -n jarvice-system jarvice-mc-portal-746f94ff65-76xr6 -- \
    jarvice-ldap-bind -h
```

### Examples

The following examples assume one of the pods is named `jarvice-mc-portal-746f94ff65-76xr6` and the JARVICE system namespace is `jarvice-system`.  For illustration purposes, the LDAP server URI is assumed to be `ldap://192.168.100.1`, and the domain is ```acme.io```.

#### Authenticate a user interactively with a base DN

```
kubectl exec -it -n jarvice-system jarvice-mc-portal-746f94ff65-76xr6 -- \
    jarvice-ldap-bind -u ldap://192.168.100.1 -b "OU=Users,DC=acme,DC=io" \
    "John Smith"
```

#### Authenticate a user with a password and a full schema

```
kubectl exec -n jarvice-system jarvice-mc-portal-746f94ff65-76xr6 -- \
    jarvice-ldap-bind -u ldap://192.168.100.1 -p Pass1234 \
    "CN=John Smith,OU=Users,DC=acme,DC=io"
```

#### Authenticate with a secure connection and require a valid certificate

```
kubectl exec -n jarvice-system jarvice-mc-portal-746f94ff65-76xr6 -- \
    jarvice-ldap-bind -u ldaps://dc1.acme.io -c -p Pass1234 \
    "CN=John Smith,OU=Users,DC=acme,DC=io"
```


## Additional Notes

1. Active Directory Users must log in to JARVICE with their common name (CN), not their user principal name (UPN)
2. Users can determine the account name JARVICE automatically generates for them by visiting the *Account* section
3. JARVICE does not support password reset via Active Directory - users must do this outside of JARVICE, including situations where new accounts require initial password setting
4. The team "payer" account must be a native JARVICE account and not an Active Directory one; typically, this user will be invited by the system administrator and will be given *SAML Admin* role after signup; note that *SAML Admin* role enables both SAML (federated) and LDAP (direct) configuration
5. Currently, each team will have its own dedicated login link; Active Directory logins cannot occur on the main JARVICE portal's login page; once you save configuration, JARVICE will generate a login link that you can send to users

