set -e

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name="keycloakx" --timeout=600s --namespace="$JARVICE_SYSTEM_NAMESPACE" || true
# get Keycloak realm certificate
while [[ "$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' ${KEYCLOAK_URL}/realms/master)" != "200" ]]; do
    echo "Waiting for keycloak" && sleep 30
done
openid_config=$(curl --fail --silent --show-error \
    "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration")
cert_url=$(printf '%s' "$openid_config" | jq --exit-status --raw-output '.jwks_uri')
certs=$(curl --fail --silent --show-error "$cert_url")
cert=$(printf '%s' "$certs" | jq --exit-status --raw-output '.keys[] | select(.alg == "RS256") | .x5c[0]' | head -n 1)
header="-----BEGIN CERTIFICATE-----"
footer="-----END CERTIFICATE-----"
# extract public key
pubkey=$(printf "%s\n%s\n%s\n" "$header" "$cert" "$footer" | \
    openssl x509 -noout -pubkey | \
    awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' | \
    sed 's/\\n//g;s/-----BEGIN PUBLIC KEY-----//;s/-----END PUBLIC KEY-----//')
# create configmap for jarvice-api
[ -z "$pubkey" ] && exit 1
kubectl -n $JARVICE_SYSTEM_NAMESPACE create configmap \
    jarvice-keycloak-realm-public-key \
    --from-literal=public.key=$pubkey -o yaml --dry-run=client | \
    kubectl apply -f -
