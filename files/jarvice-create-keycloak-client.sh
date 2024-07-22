set -e

get_token() {
    curl --fail --silent "${KEYCLOAK_URL}/realms/$KEYCLOAK_REALM/protocol/openid-connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "username=$JARVICE_KEYCLOAK_USER" \
        --data-urlencode "password=$JARVICE_KEYCLOAK_PASSWD" \
        --data-urlencode "grant_type=password" \
        --data-urlencode "client_id=admin-cli" | jq -r .access_token;
}

keycloak_get () {
    request="$1"
    token=$(get_token)
    curl --fail --silent -H "Authorization: Bearer $token" ${KEYCLOAK_URL}/admin/realms/$KEYCLOAK_REALM/$request
}

keycloak_post () {
    request="$1"
    data="$2"
    token=$(get_token)
    curl --fail --silent -d "$data" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        ${KEYCLOAK_URL}/admin/realms/$KEYCLOAK_REALM/$request
}

keycloak_put () {
    request="$1"
    data="$2"
    token=$(get_token)
    curl --fail --silent -X PUT -d "$data" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        ${KEYCLOAK_URL}/admin/realms/$KEYCLOAK_REALM/$request > /dev/null 2>&1
}

create_client() {
    keycloak_post "clients" "$(envsubst < /etc/jarvice/jarvice_client.json)" && \
        echo "Creating jarvice client on realm $KEYCLOAK_REALM" || true
}

create_client_roles () {
    jarvice_id=$1
    keycloak_post "clients/$jarvice_id/roles" "$(cat /etc/jarvice/jarvice_user_role.json | jq -c)" || return 0
    keycloak_post "clients/$jarvice_id/roles" "$(cat /etc/jarvice/jarvice_sysadmin_role.json | jq -c)"
    keycloak_post "clients/$jarvice_id/roles" "$(cat /etc/jarvice/jarvice_kcadmin_role.json | jq -c)"
    echo "Creating jarvice client roles on realm $KEYCLOAK_REALM";
}

create_auth_broker () {
    keycloak_post "authentication/flows" "{\"alias\":\"JARVICE first broker login\",\"description\":\"Actions taken after first broker login with identity provider account, which is not yet linked to any Keycloak account\",\"providerId\":\"basic-flow\",\"builtIn\":false,\"topLevel\":true}" || return 0
    echo "Creating JARVICE first broker login Authentication flow"
    keycloak_post "authentication/flows/JARVICE%20first%20broker%20login/executions/execution" "{\"provider\":\"idp-create-user-if-unique\"}"
    keycloak_post "authentication/flows/JARVICE%20first%20broker%20login/executions/execution" "{\"provider\":\"idp-email-verification\"}"
    ids=$(keycloak_get "authentication/flows/JARVICE%20first%20broker%20login/executions")
    keycloak_put "authentication/flows/JARVICE%20first%20broker%20login/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[0].id')\",\"requirement\":\"ALTERNATIVE\",\"displayName\":\"Create User If Unique\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"idp-create-user-if-unique\",\"level\":0,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20first%20broker%20login/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[1].id')\",\"requirement\":\"ALTERNATIVE\",\"displayName\":\"Verify existing account by Email\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"idp-email-verification\",\"level\":0,\"index\":1}"
}

create_auth_jarvice_user_rbac () {
    keycloak_post "authentication/flows" "{\"alias\":\"JARVICE jarvice-user RBAC\",\"description\":\"\",\"providerId\":\"basic-flow\",\"builtIn\":false,\"topLevel\":true}" || return 0
    echo "Creating JARVICE jarvice-user RBAC Authentication flow"
    keycloak_post "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions/flow" "{\"alias\":\"jarvice-user RBAC\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/jarvice-user%20RBAC/executions/flow" "{\"alias\":\"jarvice-user RBAC allow\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/jarvice-user%20RBAC/executions/flow" "{\"alias\":\"jarvice-user RBAC deny\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/jarvice-user%20RBAC%20allow/executions/execution" "{\"provider\":\"conditional-user-role\"}"
    keycloak_post "authentication/flows/jarvice-user%20RBAC%20allow/executions/execution" "{\"provider\":\"allow-access-authenticator\"}"
    keycloak_post "authentication/flows/jarvice-user%20RBAC%20deny/executions/execution" "{\"provider\":\"conditional-user-role\"}"
    keycloak_post "authentication/flows/jarvice-user%20RBAC%20deny/executions/execution" "{\"provider\":\"deny-access-authenticator\"}"
    ids=$(keycloak_get "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions")
    keycloak_post "authentication/executions/$(echo $ids | jq -r '.[2].id')/config" "{\"alias\":\"jarvice-user RBAC allow\",\"config\":{\"condUserRole\":\"jarvice.jarvice-user\"}}"
    keycloak_post "authentication/executions/$(echo $ids | jq -r '.[5].id')/config" "{\"alias\":\"jarvice-user RBAC deny\",\"config\":{\"condUserRole\":\"jarvice.jarvice-user\",\"negate\":\"true\"}}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[0].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"jarvice-user RBAC\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":0,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[1].id')\",\"requirement\":\"CONDITIONAL\",\"displayName\":\"jarvice-user RBAC allow\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":1,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[2].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Condition - user role\",\"alias\":\"jarvice-user RBAC allow\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"conditional-user-role\",\"level\":2,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[3].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Allow access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"allow-access-authenticator\",\"level\":2,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[4].id')\",\"requirement\":\"CONDITIONAL\",\"displayName\":\"jarvice-user RBAC deny\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":1,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[5].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Condition - user role\",\"alias\":\"jarvice-user RBAC deny\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"conditional-user-role\",\"level\":2,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-user%20RBAC/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[6].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Deny access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"deny-access-authenticator\",\"level\":2,\"index\":1}"
}

create_browser () {
    keycloak_post "authentication/flows" "{\"alias\":\"JARVICE browser\",\"description\":\"\",\"providerId\":\"basic-flow\",\"builtIn\":false,\"topLevel\":true}" || return 0
    echo "Creating JARVICE browser Authentication flow"
    keycloak_post "authentication/flows/JARVICE%20browser/executions/execution" "{\"provider\":\"auth-cookie\"}"
    keycloak_post "authentication/flows/JARVICE%20browser/executions/execution" "{\"provider\":\"identity-provider-redirector\"}"
    keycloak_post "authentication/flows/JARVICE%20browser/executions/flow" "{\"alias\":\"JARVICE browser forms\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/JARVICE%20browser%20forms/executions/execution" "{\"provider\":\"auth-username-password-form\"}"
    keycloak_post "authentication/flows/JARVICE%20browser%20forms/executions/flow" "{\"alias\":\"JARVICE browser Browser\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/JARVICE%20browser%20forms/executions/flow" "{\"alias\":\"JARVICE browser RBAC\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/JARVICE%20browser%20Browser/executions/execution" "{\"provider\":\"conditional-user-configured\"}"
    keycloak_post "authentication/flows/JARVICE%20browser%20Browser/executions/execution" "{\"provider\":\"auth-otp-form\"}"
    keycloak_post "authentication/flows/JARVICE%20browser%20RBAC/executions/flow" "{\"alias\":\"JARVICE RBAC allow\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/JARVICE%20browser%20RBAC/executions/flow" "{\"alias\":\"JARVICE RBAC deny\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/JARVICE%20RBAC%20allow/executions/execution" "{\"provider\":\"conditional-user-role\"}"
    keycloak_post "authentication/flows/JARVICE%20RBAC%20allow/executions/execution" "{\"provider\":\"allow-access-authenticator\"}"
    keycloak_post "authentication/flows/JARVICE%20RBAC%20deny/executions/execution" "{\"provider\":\"conditional-user-role\"}"
    keycloak_post "authentication/flows/JARVICE%20RBAC%20deny/executions/execution" "{\"provider\":\"deny-access-authenticator\"}"
    ids=$(keycloak_get "authentication/flows/JARVICE%20browser/executions")
    keycloak_post "authentication/executions/$(echo $ids | jq -r '.[9].id')/config" "{\"alias\":\"jarvice-user allow\",\"config\":{\"condUserRole\":\"jarvice.jarvice-user\"}}"
    keycloak_post "authentication/executions/$(echo $ids | jq -r '.[12].id')/config" "{\"alias\":\"jarvice-user deny\",\"config\":{\"condUserRole\":\"jarvice.jarvice-user\",\"negate\":\"true\"}}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[0].id')\",\"requirement\":\"ALTERNATIVE\",\"displayName\":\"Cookie\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"auth-cookie\",\"level\":0,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[1].id')\",\"requirement\":\"ALTERNATIVE\",\"displayName\":\"Identity Provider Redirector\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"identity-provider-redirector\",\"level\":0,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[2].id')\",\"requirement\":\"ALTERNATIVE\",\"displayName\":\"JARVICE browser forms\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":0,\"index\":2}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[4].id')\",\"requirement\":\"CONDITIONAL\",\"displayName\":\"JARVICE browser Browser\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":1,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[5].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Condition - user configured\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"conditional-user-configured\",\"level\":2,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[6].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"OTP Form\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"auth-otp-form\",\"level\":2,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[7].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"JARVICE browser RBAC\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":1,\"index\":2}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[8].id')\",\"requirement\":\"CONDITIONAL\",\"displayName\":\"JARVICE RBAC allow\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":2,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[9].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Condition - user role\",\"alias\":\"jarvice-user allow\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"conditional-user-role\",\"level\":3,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[10].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Allow access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"allow-access-authenticator\",\"level\":3,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[11].id')\",\"requirement\":\"CONDITIONAL\",\"displayName\":\"JARVICE RBAC deny\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":2,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[12].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Condition - user role\",\"alias\":\"jarvice-user deny\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"conditional-user-role\",\"level\":3,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20browser/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[13].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Deny access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"deny-access-authenticator\",\"level\":3,\"index\":1}"
}

create_auth_deny () {
    keycloak_post "authentication/flows" "{\"alias\":\"JARVICE deny\",\"description\":\"\",\"providerId\":\"basic-flow\",\"builtIn\":false,\"topLevel\":true}" || return 0
    echo "Creating JARVICE deny Authentication flow"
    keycloak_post "authentication/flows/JARVICE%20deny/executions/execution" "{\"provider\":\"deny-access-authenticator\"}"
    ids=$(keycloak_get "authentication/flows/JARVICE%20deny/executions")
    keycloak_put "authentication/flows/JARVICE%20deny/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[0].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Deny access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"deny-access-authenticator\",\"level\":0,\"index\":0}"
}

create_auth_cookie () {
    keycloak_post "authentication/flows"  "{\"alias\":\"JARVICE jarvice-sysadmin Cookie\",\"description\":\"\",\"providerId\":\"basic-flow\",\"builtIn\":false,\"topLevel\":true}" || return 0
    echo "Creating JARVICE jarvice-sysadmin Cookie Authentication flow"
    keycloak_post "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions/flow"  "{\"alias\":\"jarvice-sysadmin Cookie RBAC\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions/flow"  "{\"alias\":\"jarvice-sysadmin Cookie deny\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20RBAC/executions/execution"  "{\"provider\":\"auth-cookie\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20RBAC/executions/flow"  "{\"alias\":\"jarvice-sysadmin Cookie RBAC allow\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20RBAC/executions/flow"  "{\"alias\":\"jarvice-sysadmin Cookie RBAC deny\",\"description\":\"\",\"provider\":\"registration-page-form\",\"type\":\"basic-flow\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20RBAC%20allow/executions/execution"  "{\"provider\":\"conditional-user-role\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20RBAC%20allow/executions/execution"  "{\"provider\":\"allow-access-authenticator\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20RBAC%20deny/executions/execution"  "{\"provider\":\"conditional-user-role\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20RBAC%20deny/executions/execution"  "{\"provider\":\"deny-access-authenticator\"}"
    keycloak_post "authentication/flows/jarvice-sysadmin%20Cookie%20deny/executions/execution"  "{\"provider\":\"deny-access-authenticator\"}"
    ids=$(keycloak_get "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions")
    keycloak_post "authentication/executions/$(echo $ids | jq -r '.[3].id')/config" "{\"alias\":\"jarvice-sysadmin allow\",\"config\":{\"condUserRole\":\"jarvice.jarvice-sysadmin\"}}"
    keycloak_post "authentication/executions/$(echo $ids | jq -r '.[6].id')/config" "{\"alias\":\"jarvice-sysadmin deny\",\"config\":{\"condUserRole\":\"jarvice.jarvice-sysadmin\",\"negate\":\"true\"}}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[0].id')\",\"requirement\":\"ALTERNATIVE\",\"displayName\":\"jarvice-sysadmin Cookie RBAC\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":0,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[1].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Cookie\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"auth-cookie\",\"level\":1,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[2].id')\",\"requirement\":\"CONDITIONAL\",\"displayName\":\"jarvice-sysadmin Cookie RBAC allow\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":1,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[3].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Condition - user role\",\"alias\":\"jarvice-sysadmin allow\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"conditional-user-role\",\"level\":2,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[4].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Allow access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":false,\"providerId\":\"allow-access-authenticator\",\"level\":2,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[5].id')\",\"requirement\":\"CONDITIONAL\",\"displayName\":\"jarvice-sysadmin Cookie RBAC deny\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":1,\"index\":2}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[6].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Condition - user role\",\"alias\":\"jarvice-sysadmin deny\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"conditional-user-role\",\"level\":2,\"index\":0}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[7].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Deny access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"deny-access-authenticator\",\"level\":2,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[8].id')\",\"requirement\":\"ALTERNATIVE\",\"displayName\":\"jarvice-sysadmin Cookie deny\",\"description\":\"\",\"requirementChoices\":[\"REQUIRED\",\"ALTERNATIVE\",\"DISABLED\",\"CONDITIONAL\"],\"configurable\":false,\"authenticationFlow\":true,\"level\":0,\"index\":1}"
    keycloak_put "authentication/flows/JARVICE%20jarvice-sysadmin%20Cookie/executions" \
        "{\"id\":\"$(echo $ids | jq -r '.[9].id')\",\"requirement\":\"REQUIRED\",\"displayName\":\"Deny access\",\"requirementChoices\":[\"REQUIRED\",\"DISABLED\"],\"configurable\":true,\"providerId\":\"deny-access-authenticator\",\"level\":1,\"index\":0}"
}

set_jarvice_auth_flow () {
    echo "Setting jarvice client Authentication flow to JARVICE browser"
    browser_id=$(keycloak_get "authentication/flows" | jq -r '.[] | select(.alias=="JARVICE browser") | .id')
    jarvice_client=$(keycloak_get "clients?clientId=jarvice")
    client_id=$(echo $jarvice_client | jq -r .[].id)
    keycloak_put "clients/$client_id" "$(echo $jarvice_client | jq --arg id "$browser_id" '.[] | .authenticationFlowBindingOverrides.browser = $id')"
}

while [[ "$(curl -s -o /dev/null -m 3 -L -w ''%{http_code}'' ${KEYCLOAK_URL}/realms/master)" != "200" ]]; do
    echo "Waiting for keycloak" && sleep 30
done

create_client
client_id=$(keycloak_get "clients?clientId=jarvice" | jq -r .[].id)
create_client_roles "$client_id"
create_auth_broker
create_auth_jarvice_user_rbac
create_browser
create_auth_deny
create_auth_cookie
set_jarvice_auth_flow
