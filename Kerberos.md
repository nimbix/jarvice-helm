

##  Feature description

Kerberos based AD SSO allows Windows users logged into a domain, to sign into the Jarvice MC portal, without needing to enter a username and password.

The user needs to have been configured to authenticate via LDAP on the MC portal by their team owner (under the Account/LDAP page). Note that the team owner needs the SAML/LDAP Admin role flag to be assigned to them by the system administrator (via the Administration/Users page)



## Technical and implementation details

### Client 
When a browser is configured to use Kerberos SPNEGO for a given domain, it sends a special cryptographic hash token based on the Kerberos ticket that the client has acquired from the Kerberos KDC (key distribution center)
A web server or other service, when configured properly can verify the token is authentic and start a login session for the user.

On Windows domains, the domain controller performs the role of the KDC and automatically grants a ticket when a user logs in to the workstation.
Such a user can access the endpoint `/portal/ad-login/tag` to sign in directly (where tag is the Jarvice LDAP tag configured by the users team owner) 

---

### AD Server 

The AD admin creates a specific service account and configures it to provide tickets for access to the Jarvice MC portal by creating a keytab file, that needs to deployed on the portal container

---

### Portal web server
The nginx webserver is compiled with SPNEGO support and configured to use GSS authentication for the `/portal/ad-login/` endpoint.
If the request made by the browser to that endpoint has a valid authentication token, the portal logs in the user.  

The GSS/SPNEGO support is enabled or disabled by setting values in the config map, without needing to rebuild the container

---

### Notes

 - Since kerberos was designed to work without transport layer security, the keytab file or the request token even if intercepted cannot be easily used to break the user domain credentials
 -  The user needs to manually login via the LDAP login page once at `/portal/ldap-login/tag` (which initially creates the user account), after which the automatic logon can be used

---

## Admin guide

### AD server setup



#### Service account Setup:

 - Login with administrative privileges on the AD domain controller.
 - Open the **Active Directory User and Computers** tool
 - Click on the **Managed service account** folder on the left pane
 - Create an account for the service named for e.g. "portal"
   - Set the "**Password Never Expires**" flag 


#### User keytab generation


The `kt_pass` utility is used to generate a keytab file for the user to use the "HTTP" service.

Example:

    ktpass -out krb5.keytab -princ HTTP/jarvice.company.io@DC.COMPANY.IO -mapUser portal@dc.company.io -pass Pass1234 -crypto all -ptype KRB5_NT_PRINCIPAL

 - **jarvice.company.io** represents the FQDN of the ingress URL for the JARVICE MC portal (which should be on the same domain as the Windows AD Domain Controller)   
 - **DC.COMPANY.IO** is the Kerberos realm name - typically the FQDN of the Windows AD Domain Controller
 - **portal@dc.company.io** is the complete user principal of the service account created above, including the domain

 The following output should be seen:

    C:\Users\sysadmin>ktpass -out krb5.keytab -princ HTTP/jarvice.company.io@DC.COMPANY.IO -mapUser portal@dc.company.io -pass Pass1234 -crypto all -ptype KRB5_NT_PRINCIPAL
    Targeting domain controller: dc.company.io
    Using legacy password setting method
    Successfully mapped HTTP/jarvice.company.io to portal.
    Key created.
    Key created.
    Key created.
    Key created.
    Key created.
    Output keytab to krb5.keytab:
    --- snip ---

<br/>
This will establish the **portal**  service account as being able to provide authentication for the service at HTTP/jarvice.company.io where the Jarvice MC Portal runs.
This operation has to be done only once unless any of the domain names changes.

**Notes**:

  - The `ktpass` utility is only available on Windows Server versions, hence it has to be run on the domain controller machine under an Administrator command prompt
  - The service account will never be used for any other purpose than provision of authentication for this service
  - The `-crypto all` flag causes `ktpass` to generate multiple keys, each with a different cryptographic standard - this is convenient as it does not enforce any particular setting 

---
### JARVICE portal setup

---

#### Limit TERMINATE ALL jobs scope

By default, **TERMINATE ALL** button in Admininstration.Jobs view terminates all current running jobs.
It is possible to limit the scope of this action by setting `JARVICE_PORTAL_JOB_TERMINATE_LIMIT` value.
Setting `JARVICE_PORTAL_JOB_TERMINATE_LIMIT: 10` will limit the terminate action to latest 10 jobs.

#### Enable GSS/SPNEGO authentication 

Specify the following settings via the helm chart for the JARVICE MC portal deployment:

 - `JARVICE_PORTAL_GSS_REALM`: Realm name
 - `JARVICE_PORTAL_GSS_DOMAIN`: The FQDN of the ingress URL for the JARVICE MC portal
 - `JARVICE_PORTAL_GSS_LOG`: Set to **debug** to enable logging of the GSS authentication process for troubleshooting

Once `JARVICE_PORTAL_GSS_REALM` and `JARVICE_PORTAL_GSS_DOMAIN` are set, any user logged into the domain can access an endpoint like `/portal/ad-login/tag` to get logged in directly without needing a password.

`tag` is the Jarvice LDAP tag which has been configured by the payer for this user 

**Note:**
The current implementation requires that the user logging in has been configured by their payer to allow LDAP login. 
It also requires that the user have logged in via LDAP manually to the portal once, via `/portal/ldap-login/tag`

#### Deploy keytab to the portal pods

The krb5.keytab file generated needs to be deployed to the portal containers as a kubernetes secret. 

  - Use the script `kt_deploy.sh` to deploy after setting the following environment variables:
      - `JARVICE_MC_PORTAL_NS`: K8S namespace where the JARVICE MC Portal containers run
      - `JARVICE_MC_PORTAL`: JARVICE MC Portal container name

  - Verify that the secret has been deployed (the same environment variables as above are required) with `kt_check.sh`. The script prints the MD5 digest of the `krb5.keytab` file in the current directory and that of the file that was deployed.
  If the MD5 digest matches, the deployment has completed

**Note:**

The portal containers are restarted by  `kt_deploy.sh` , hence the deployment may take a while to complete, depending on the network and cluster configuration and load.

---
### Client / Browser setup

---

#### Firefox

Open the **about:config** page and change the following setting:

```
network.negotiate-auth.trusted-uris
```

This is a comma separated list of domain names for which Kerberos/GSS authentication will be applied - add or append the the FQDN of the ingress URL for the JARVICE MC portal to that value.

 
#### Chrome/Chromium/Edge

Add this command line option to the shortcut target 

```
--auth-server-whitelist="jarvice.company.io"
```
---
### Troubleshooting
---

#### Enabling logging

The webserver cannot always communicate the exact error that caused it to fail, so we need to enable the debug log:

- Set `JARVICE_PORTAL_GSS_LOG=debug` for the container config map and restart the portal containers
- Navigate to `jarvice.company.io/ad-login/tag` on the users web browser 
<br/>

####  Kerberos authentication error

First verify the client side ticket as follows:

- Open a command prompt on the client machine and run the `klist`  command
- Verify that a ticket with the following settings is seen
```
Client: username @ DC.COMPANY.IO
Server: HTTP/jarvice.company.io @ DC.COMPANY.IO
```

- If this ticket exists, then there is probably something wrong with the browser configuration - try these steps on the users system
   - Verify browser config and try again
   - Run `klist purge` on the command prompt and get the user to logoff and logon from Windows, and try again

- If no tickets are seen, that means the client did not receive any during Windows logon - try the following:
  -  Verify the settings as described in the **Account Settings** subsection under **AD Setup**"  above.
  - Get the user to logoff and logon from their Windows session, and run `klist` again to verify that the ticket entry above is present, and retry

 
#### Server side issues 

- Open the K8S logs for the JARVICE Portal containers and look at the messages starting with `SSO auth handling IN`

 - The following messages should be seen
    ```
      SSO auth handling IN: token.len=0, head=0, ret=401
      Begin auth
      Detect SPNEGO token
      Token decoded: <base64 data>
    ```
- If the **Token decoded** message is missing, it means the browser is misconfigured

- If the token data starts with `TlRMTQ` it means the browser is sending an NTLM token, which it does only if the client has no Kerberos ticket assigned at logon - Try the same resolution steps as described above for **Kerberos authentication error**

- If the token starts with `YII` it is probably a valid GSS token and you should see
    ```
    Client sent a reasonable Negotiate header
    GSSAPI authorizing
    Use keytab /etc/krb5.keytab
    ```

-  If the keytab file is invalid you will see:
    ```
    Use keytab /etc/krb5.keytab
    Using service principal: ...
    my_gss_name HTTP/jarvice.company.io@DC.COMPANY.IO
    GSSAPI failed
    ```
       
    Verify that the krb5.keytab generated was valid with ```kt_list.sh``` and if so, verify that the file was deployed successfully with ```kt_check.sh```

- If you see:
    ```
    gss_accept_sec_context() failed: Cannot find key for HTTP/jarvice.company.jarvice.io@DC.COMPANY.IO kvno NN in keytab:
    ```

	It means that the key version number the client believed was latest is actually older. This can happen if you ever run `ktpass` again after the initial setup (this increments the key version number).
	The solution is to get the user to logoff and logon again so that they receive the latest ticket
<br/>

#### Payer LDAP configuration issues

In such cases, you will see the LDAP Login dialog with a self explanatory error message


##### No such LDAP config 

The LDAP tag at the end of the url is wrong for e.g. `jarvice.company.io/ad-login/invalid` 

Note:
Since the tag is wrong, trying to enter an LDAP username and password on the dialog will fail again, so you need to re-enter the URL


##### User unauthorized

This could be due to the following:

* The user has never logged in via LDAP manually before
* The user is not in the allowed list of users for their payers LDAP config

---


### Utility scripts reference

---

In order to run these scripts, be sure to set the environment variables ```JARVICE_MC_PORTAL_NS``` and ```JARVICE_MC_PORTAL``` as described above.
If the deployment is not within a namespace, you need to remove the ```-n``` flags from the commands below

---
#### kt_list.sh

Lists the entries in a keytab file

Usage: ```kt_list.sh [keytab]```

If ```keytab``` is omitted ```./krb5.keytab``` is used.

```
#!/bin/bash

ktutil <<< "rkt ${1:-krb5.keytab}
list" | grep -v "ktutil"
echo
``` 
 
 ---


#### kt_deploy.sh

Deploys the file ```./krb5.keytab``` to the Jarvice MC portal and restarts the containers

```
#!/bin/sh
kubectl -n ${JARVICE_MC_PORTAL_NS} create secret generic krb5.keytab --from-file krb5.keytab -o yaml --dry-run | kubectl replace -f -
kubectl -n ${JARVICE_MC_PORTAL_NS} rollout restart deployment ${JARVICE_MC_PORTAL}
```
 
 ---

#### kt_check.sh

Checks if the deployed krb5.keytab file matches the local file ./krb5.keytab

```
#!/bin/bash
POD=$(kubectl -n ${JARVICE_MC_PORTAL_NS} get pods -l deployment=jarvice-mc-portal -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n ${JARVICE_MC_PORTAL_NS} $POD -- md5sum /etc/krb5.keytab
md5sum ./krb5.keytab
```
 
 