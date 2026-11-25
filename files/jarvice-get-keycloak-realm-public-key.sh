set -e

echo "Keycloak hook starting"
echo "  namespace: $JARVICE_SYSTEM_NAMESPACE"
echo "  realm: $KEYCLOAK_REALM"
echo "  URL: $KEYCLOAK_URL"

if kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name="keycloakx" --timeout=600s --namespace="$JARVICE_SYSTEM_NAMESPACE"; then
    echo "Keycloak Pod is Ready"
else
    echo "WARNING: timed out waiting for a Ready Keycloak Pod; continuing with URL checks"
fi

attempt=0
while true; do
    attempt=$((attempt + 1))
    master_status=$(curl -sS -o /dev/null -m 3 -L -w '%{http_code}' "${KEYCLOAK_URL}/realms/master" || true)
    echo "Keycloak readiness attempt ${attempt}: HTTP ${master_status}"
    if [ "$master_status" = "200" ]; then
        break
    fi
    echo "Waiting for Keycloak at ${KEYCLOAK_URL}/realms/master"
    sleep 30
done

openid_url="${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration"
echo "Requesting OpenID configuration: ${openid_url}"
openid_config=$(curl --fail --silent --show-error --location "$openid_url" 2>&1) || {
    echo "ERROR: OpenID configuration request failed"
    printf '%s\n' "$openid_config" | head -c 2000
    exit 1
}
echo "OpenID configuration response received (${#openid_config} bytes)"

if ! cert_url=$(printf '%s' "$openid_config" | jq --exit-status --raw-output '.jwks_uri'); then
    echo "ERROR: OpenID configuration was not valid JSON or did not contain jwks_uri"
    printf '%s\n' "$openid_config" | head -c 2000
    exit 1
fi
echo "JWKS URL: ${cert_url}"

certs=$(curl --fail --silent --show-error --location "$cert_url" 2>&1) || {
    echo "ERROR: JWKS request failed"
    printf '%s\n' "$certs" | head -c 2000
    exit 1
}
echo "JWKS response received (${#certs} bytes)"

if ! cert=$(printf '%s' "$certs" | jq --exit-status --raw-output '.keys[] | select(.alg == "RS256") | .x5c[0]' | head -n 1); then
    echo "ERROR: JWKS response did not contain an RS256 certificate"
    printf '%s\n' "$certs" | head -c 2000
    exit 1
fi
echo "RS256 certificate extracted (${#cert} characters)"

header="-----BEGIN CERTIFICATE-----"
footer="-----END CERTIFICATE-----"
if ! pubkey=$(printf "%s\n%s\n%s\n" "$header" "$cert" "$footer" | \
    openssl x509 -noout -pubkey 2>&1 | \
    awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' | \
    sed 's/\\n//g;s/-----BEGIN PUBLIC KEY-----//;s/-----END PUBLIC KEY-----//'); then
    echo "ERROR: failed to convert the RS256 certificate to a public key"
    exit 1
fi

[ -z "$pubkey" ] && { echo "ERROR: extracted public key is empty"; exit 1; }
echo "Updating ConfigMap jarvice-keycloak-realm-public-key"
kubectl -n "$JARVICE_SYSTEM_NAMESPACE" create configmap \
    jarvice-keycloak-realm-public-key \
    --from-literal=public.key="$pubkey" -o yaml --dry-run=client | \
    kubectl apply -f -
echo "Keycloak realm public key ConfigMap updated successfully"
