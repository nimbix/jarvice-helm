# BIRD portal

The BIRD portal provides a UI for users to interact with the JARVICE XE platform.

Identity and Access Management provided by [Keycloak](https://keycloak.org).

## Table of Contents

* [Setup Keycloak deployment](#setup-keycloak-deployment)
    - [Using Keycloak helm chart](#using-keycloak-helm-chart)
    - [Keycloak realm admin for JARVICE](#keycloak-realm-admin-for-jarvice)
    - [Configure Keycloak SMTP server](#configure-keycloak-smtp-server)
    - [Keycloakx sample helm values](#keycloakx-sample-helm-values)
    - [Backup Keycloak database](#backup-keycloak-database)
    - [Use external Keycloak deployment](#use-external-keycloak-deployment)    
* [JARVICE BIRD configuration](#jarvice-bird-configuration)
    - [Environment variables](#environment-variables)
    - [BIRD sample helm values](#bird-sample-helm-values)
* [Migration from mc portal](#migration-from-mc-protal)
    - [Standard users](#standard-users)
    - [LDAP/SAML configuration](#ldapsaml-configuration)
    - [JARVICE System Administration users](#jarvice-system-administration-users)

------------------------------------------------------------------------------

## Setup Keycloak deployment

BIRD uses Keycloak to manage users for the JARVICE platform. The Keycloak helm chart is included as a [subchart](https://helm.sh/docs/chart_template_guide/subcharts_and_globals/) to optionally deploy Keycloak alongside JARVICE.

### Using Keycloak helm chart

JARVICE uses the [Keycloakx helm chart](https://artifacthub.io/packages/helm/codecentric/keycloakx) to deploy Keycloak. Experienced Keycloakx helm users can override any value defined in the keycloakx helm chart by using the `keycloakx` stanza in your `override.yaml` file used to deploy JARVICE.

### Keycloak realm admin for JARVICE

The BIRD service in JARVICE manages all Keycloak settings after the initial deployment. To enable this, JARVICE needs the credentials for a realm admin to manage its client inside Keycloak.

```bash
keycloakx:
  env:
    JARVICE_KEYCLOAK_ADMIN: jarvice
    JARVICE_KEYCLOAK_ADMIN_PASSWD: Pass1234
    JARVICE_REALM_ADMIN: nimbix
    JARVICE_REALM_ADMIN_PASSWD: abc1234!
```

* `JARVICE_KEYCLOAK_ADMIN`
  - Credentials used to create the Keycloak master realm admin.
* `JARVICE_REALM_ADMIN`
  - This account will be created by a helm hook when installing JARVICE to interact with the `jarvice` Keycloak client. `JARVICE_REALM_ADMIN` permissions are isolated to the realm that contains the `jarvice` client.

### Configure Keycloak SMTP server

Setting up the SMTP server will allow Keycloak to directly communicate with users via email. This can be useful for password reset requests or setting other [required actions](https://www.keycloak.org/docs/21.1.1/server_admin/#con-required-actions_server_administration_guide).

|                | Description | Example |
| -------------- | ----------- | ------- |
| KEYCLOAK_SMTP_FROM | A user-friendly name for the 'From' address | `donotreply@example.com` |
| KEYCLOAK_SMTP_HOST | SMTP host | `smtp.example.com` |
| KEYCLOAK_SMTP_PORT | SMTP port | `587` |
| KEYCLOAK_SMTP_START_TLS | Start TLS encryption | `true` |
| KEYCLOAK_SMTP_AUTH | Enable SMTP authentication | `true` |
| KEYCLOAK_SMTP_USER | SMTP user | `<user>@smtp.example.com` |
| KEYCLOAK_SMTP_PASSWORD | SMTP user password | `<smtp-password>` |

### Keycloakx sample helm values

```bash
keycloakx:
  create_realm: true
  enabled: true
  env:
    JARVICE_KEYCLOAK_ADMIN: jarvice
    JARVICE_KEYCLOAK_ADMIN_PASSWD: Pass1234
    JARVICE_REALM_ADMIN: nimbix
    JARVICE_REALM_ADMIN_PASSWD: abc1234!  
  smtpServer: # smtp server settings for keycloak realm
    KEYCLOAK_SMTP_FROM:      donotreply@example.com
    KEYCLOAK_SMTP_HOST:      smtp.example.com
    KEYCLOAK_SMTP_PORT:      587
    KEYCLOAK_SMTP_START_TLS: true
    KEYCLOAK_SMTP_AUTH:      true
    KEYCLOAK_SMTP_USER:      <user>@smtp.example.com
    KEYCLOAK_SMTP_PASSWORD:  <smtp-password>
  ingress:
    enabled: true
    annotations:
      cert-manager.io/issuer: letsencrypt-staging
    rules:
      -
        # Ingress host
        host: keycloak.example.com
        # Paths for the host
        paths:
          - path: /
            pathType: Prefix        
    # TLS configuration
    tls:
      - hosts:
          - keycloak.example.com
        secretName: "tls-keycloak.example.com"
```

### Backup Keycloak database

It is recommended that Keycloak database backups are regularly scheduled. The JARVICE helm chart includes an optional [kubernetes CronJob](./README.md#set-up-database-backups) which can be enabled to regularly back up both Keycloak and JARVICE databases. Note, Keycloak database backups need to be enabled:

```bash
jarvice_db_dump:
  enabled: true
  keycloak:
    enabled: true
```

### Use external Keycloak deployment

An external Keycloak deployment not managed by the JARVICE helm chart can be used by BIRD. JARVICE requires its own realm which helm creates automatically when `create_realm` is set:

```bash
keycloakx:
  create_realm: true
  enabled: false
```

## JARVICE BIRD configuration

Please review the `jarvice_bird` stanza in `values.yaml` for more configuration details. The minimal settings are described below.

### Environment variables

|                  | Description  | Example  |
| ---------------- | ------------ | -------- |
| KEYCLOAK_URL     | Ingress for Keycloak deployment | `https://keycloak.example.com/auth` |
| JARVICE_KEYCLOAK_ADMIN_USER | Keycloak realm admin | `nimbix` |
| JARVICE_KEYCLOAK_ADMIN_PASS | Keycloak realm admin password | `abc1234!` |

### BIRD sample helm values

```bash
jarvice_bird:
  enabled: true
  ingressHost: bird.example.com
  env:
    KEYCLOAK_URL: https://keycloak.example.com/auth
    JARVICE_KEYCLOAK_ADMIN_USER: nimbix
    JARVICE_KEYCLOAK_ADMIN_PASS: abc1234!
```

## Migration from MC portal

Existing JARVICE users will need to be imported into Keycloak when migrating from the MC portal. 

### Standard users

Standard JARVICE user can be imported into Keycloak using [jarvice-create-keycloak-users.sh](https://github.com/nimbix/jarvice-create-keycloak-users).

### LDAP/SAML configuration

LDAP/SAML settings remain self-service for each payer account. Payers will need to login to the BIRD portal to configure their LDAP/SAML settings under the `Account` page. Previously configured setting from the MC portal will be auto populated in all non-password fields.

**NOTE**  Payers must fill in the remaining required LDAP/SAML fields and click `SAVE` to enable LDAP and/or SAML on the BIRD portal.

### JARVICE System Administrator users

JARVICE system administrators cannot be a LDAP or SAML user. Only standard JARVICE users can be promoted to a System Administrator.
