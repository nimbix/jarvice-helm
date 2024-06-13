set -e
# get Keycloak realm certificate
while [[ "$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' ${KEYCLOAK_URL}/realms/master)" != "200" ]]; do
    echo "Waiting for keycloak" && sleep 30
done
cert_url=$(curl --fail "${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration" 2>/dev/null | jq -r '.jwks_uri')
cert=$(curl --fail $cert_url 2>/dev/null | jq -r '.keys[] | select(.alg == "RS256") | .x5c[0]' )
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
