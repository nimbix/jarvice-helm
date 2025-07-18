# Global settings that apply to all cluster types

global = {
    meta = {
        ssh_public_key = "~/.ssh/id_rsa.pub"
    }

    helm = {
        jarvice = {
            repository = "https://nimbix.github.io/jarvice-helm/"
            # null version installs latest release from the helm repository.
            # Subsequent helm upgrades require that a specific release version
            # be set.  e.g. "3.0.0-1.XXXXXXXXXXXX"
            # Visit the following link for the latest release versions:
            # https://github.com/nimbix/jarvice-helm/releases
            version = null  # "../"  # "~/github/nimbix/jarvice-helm"

            # Available helm values for a released version can be found via:
            # version=3.0.0-1.XXXXXXXXXXXX; curl https://raw.githubusercontent.com/nimbix/jarvice-helm/$version/values.yaml
            values_file = "values.yaml"  # ignored if file does not exist
            # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
            # user_java_cacert = "/etc/ssl/certs/java/cacerts"
            values_yaml = <<EOF
# Global JARVICE configuration
# These values apply to all clusters unless overridden

# Update per cluster values_yaml to override these global values.

#jarvice:
  # imagePullSecret is a base64 encoded string.
  # e.g. - echo "_json_key:$(cat key.json)" | base64 -w 0
  #imagePullSecret:
  #JARVICE_LICENSE_LIC:

  # JARVICE_REMOTE_* settings are used for application synchronization
  #JARVICE_REMOTE_API_URL: https://cloud.nimbix.net/api
  #JARVICE_REMOTE_USER:
  #JARVICE_REMOTE_APIKEY:
  #JARVICE_APPSYNC_USERONLY: "false"

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

  # HTTP/S Proxy settings, no_proxy is set for services
  #JARVICE_HTTP_PROXY:   # "http://proxy.my-domain.com:8080"
  #JARVICE_HTTPS_PROXY:  # "https://proxy.my-domain.com:8080"
  #JARVICE_NO_PROXY:     # "my-other-domain.com,192.168.1.10,domain.com:8080"

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

  #ingress:
  #  tls:
  #    issuer:
  #      name: "letsencrypt-prod"  # "letsencrypt-staging" # "selfsigned"
  #      # An admin email is required when letsencrypt issuer is set. The first
  #      # JARVICE_MAIL_ADMINS email will be used if issuer.email is not set.
  #      email: # "admin@my-domain.com"
  #    # If crt and key values are provided, issuer settings will be ignored
  #    crt: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.pem
  #    key: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.key
EOF
        }
    }
}
