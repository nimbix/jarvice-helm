#!/usr/bin/env python3

import jwt
import requests
from urllib.parse import urlencode
import urllib.parse
import os
import json
import re

# Compute JARVICE_ environment, to replace strings later
prefix="JARVICE"
myPattern = re.compile(r'{prefix}\w+'.format(prefix=prefix))
jarvice_env_variables = {key:val for key, val in os.environ.items() if myPattern.match(key)}

def update_string_by_jarvice_env(string_to_update):
    for key, val in jarvice_env_variables.items():
        if key in string_to_update:
            string_to_update = string_to_update.replace(key, val)
    return string_to_update

cacert = '/etc/ssl/certs/ca-certificates.crt'

jarvice_realm = "oxedions"
keycloak_url = os.environ.get('JARVICE_KEYCLOAK_URL',)
keycloak_realm = os.environ.get('JARVICE_KEYCLOAK_REALM',)
keycloak_client_id = os.environ.get('JARVICE_KEYCLOAK_CLIENT_ID')
keycloak_client_secret = os.environ.get('JARVICE_KEYCLOAK_CLIENT_SECRET')

def getKeycloakClientToken():
    payload = {
        'client_id': keycloak_client_id,
        'client_secret': keycloak_client_secret,
        'grant_type': 'client_credentials'
    }
    headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
    }
    url = '{}/realms/{}/protocol/openid-connect/token'.format(
        keycloak_url,
        keycloak_realm
    )
    resp = requests.post(
        url,
        data=urlencode(payload),
        headers=headers,
        verify=cacert
    )
    token = json.loads(resp.content)
    return token['access_token']

def getRequest(url_prefix):
    access_token = getKeycloakClientToken()
    headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(access_token)
    }
    resp = requests.get(
        keycloak_url + url_prefix,
        headers=headers,
        verify=cacert
    )
    if int(resp.status_code) != 200:
        print(resp.status_code)
        print(resp.content)
        print("Failed HTTP GET at " + keycloak_url + url_prefix)
        exit(1)
    return resp


def postRequest(url_prefix, payload):
    access_token = getKeycloakClientToken()
    headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(access_token)
    }
    resp = requests.post(
        keycloak_url + url_prefix,
        data=json.dumps(payload),
        headers=headers,
        verify=cacert
    )
    if int(resp.status_code) != 201:
        print(resp.status_code)
        print(resp.content)
        print("Failed HTTP POST at " + keycloak_url + url_prefix)
        exit(1)


def putRequest(url_prefix, payload):
    access_token = getKeycloakClientToken()
    headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(access_token)
    }
    resp = requests.put(
        keycloak_url + url_prefix,
        data=json.dumps(payload),
        headers=headers,
        verify=cacert
    )
    if int(resp.status_code) != 204:
        print(resp.status_code)
        print(resp.content)
        print("Failed HTTP PUT at " + keycloak_url + url_prefix)
        exit(1)


def keycloakCreateRealmIfNotExist(realm_name, payload):
    
    # List existing realms
    resp = getRequest('/admin/realms?briefRepresentation=true')
    
    # Check realm is in the list
    realm_exists = False
    realm_id = None
    for realm in json.loads(resp.content):
        if realm['realm'] == realm_name:
            realm_id = realm['id']
            realm_exists = True
            break

    if not realm_exists:
        # Create realm
        print('Creating ' + realm_name + ' realm.')
        resp = postRequest('/admin/realms/', payload)
        realm_id = resp.headers['Location'].split("/")[-1]
    else:
        # Make sure it matches our needs
        print('Realm ' + realm_name + ' already exists, updating it.')
        purl = '/admin/realms/{}'.format(realm_name)
        resp = putRequest(purl, payload)

    return realm_id


def keycloakCreateClientIfNotExist(payload, client_name, realm_name):

    purl = '/admin/realms/{}/clients'.format(realm_name)

    # List existing clients
    resp = getRequest(purl)

    # Check client is in the list
    client_exists = False
    client_id = None
    for client in json.loads(resp.content):
        if client['clientId'] == client_name:
            client_id = client['id']
            client_exists = True
            break

    # Create client
    if not client_exists:
        print('Creating ' + client_name + ' client.')
        resp = postRequest(purl, payload)
        client_id = resp.headers['Location'].split("/")[-1]
    else:
        print('Client ' + client_name + ' already exists, updating it.')
        purl = '/admin/realms/{}/clients/{}'.format(realm_name, client_id)
        resp = putRequest(purl, payload)

    # Get client (with its secret) and its id
    purl = '/admin/realms/{}/clients/{}'.format(realm_name, client_id)
    resp = getRequest(purl)
    client = json.loads(resp.content)
    return client_id, client['secret']


def keycloakCreateClientRoleIfNotExist(payload, client_role_name, client_id, realm_name):

    purl = '/admin/realms/{}/clients/{}/roles'.format(realm_name, client_id)

    # List existing roles
    resp = getRequest(purl)

    # Check client role is in the list
    client_role_exists = False
    client_role_id = None
    for client_role in json.loads(resp.content):
        if client_role['roleId'] == client_role_name:
            client_role_id = client_role['id']
            client_role_exists = True
            break

    # Create client
    if not client_role_exists:
        print('Creating ' + client_role_name + ' client role.')
        resp = postRequest(purl, payload)
        client_role_id = resp.headers['Location'].split("/")[-1]
    else:
        print('Client role ' + client_name + ' already exists, updating it.')
        purl = '/admin/realms/{}/clients/{}/roles/{}'.format(realm_name, client_id, client_role_id)
        resp = putRequest(purl, payload)

    return client_role_id


print("Entering creation/update tree")

# List realms to create
for realm in os.listdir("./realms/"):
    
    # Load realm configuration
    with open("./realms/" + str(realm) + "/main.json", 'r') as configuration_file:
        file_content = update_string_by_jarvice_env(configuration_file.read())
    realm_payload = json.loads(file_content)
    # Extract name from payload, dont user file name
    realm_name = realm_payload['realm']
    # Create realm
    keycloakCreateRealmIfNotExist(realm_name, realm_payload)

    # List clients to create
    for client in os.listdir("./realms/" + str(realm) + "/clients/"):

        # Load client configuration
        with open("./realms/" + str(realm) + "/clients/" + str(client) + "/main.json", 'r') as configuration_file:
            file_content = update_string_by_jarvice_env(configuration_file.read())
        client_payload = json.loads(file_content)
        # Extract name from payload, dont user file name
        client_name = client_payload['clientId']
        # Create client
        keycloakCreateClientIfNotExist(client_payload, client_name, realm_name)

        # List client roles to create
        for client_role in os.listdir("./realms/" + str(realm) + "/clients/" + str(client) + "/roles/"):
            
            # Load client role configuration
            with open("./realms/" + str(realm) + "/clients/" + str(client) +  "/roles/" + client_role, 'r') as configuration_file:
                file_content = update_string_by_jarvice_env(configuration_file.read())
            client_role_payload = json.loads(file_content)
            # Extract name from payload
            client_role_name = client_role_payload['name']
            # Create client role
            keycloakCreateClientRoleIfNotExist(client_role_payload, client_role_name, client_name, realm_name)



# # Realm: jarvice
# realm_id = keycloakCreateRealmIfNotExist(jarvice_realm)
# print(realm_id)

# # Client: jarvice
# client_name = "jarvice"
# redirect_url = "https://jarvice-development-bird.jarvicedev.com"
# payload = {
#     'protocol': 'openid-connect',
#     'clientId': '{}'.format(client_name),
#     'name': '',
#     'description': '',
#     'authorizationServicesEnabled': False,
#     'serviceAccountsEnabled': True,
#     'implicitFlowEnabled': False,
#     'directAccessGrantsEnabled': True,
#     'standardFlowEnabled': True,
#     'publicClient': False,
#     'clientAuthenticatorType': "client-secret",
#     'frontchannelLogout': True,
#     'attributes': {
#         'saml_idp_initiated_sso_url_name': '',
#         'oauth2.device.authorization.grant.enabled': False,
#         'oidc.ciba.grant.enabled': False
#     },
#     'alwaysDisplayInConsole': False,
#     'rootUrl': '',
#     'baseUrl': '',
#     'redirectUris': [
#         'https://{}/*'.format(redirect_url)
#     ],
#     'webOrigins': [
#         '+'
#     ]
# }

# client_id, client_secret = keycloakCreateClientIfNotExist(payload=payload, client_name=client_name, realm_name=jarvice_realm)

# # Client role: jarvice-user 
# payload = {
#   "name": "jarvice-user",
#   "description": "",
#   "composite": true,
#   "composites": {
#     "client": {
#       "account": [
#         "manage-account"
#       ]
#     }
#   },
#   "clientRole": true,
#   "attributes": {}
# }
# client_role_name=payload['name']

# role_id = keycloakCreateClientRoleIfNotExist(payload=payload, client_role_name=client_role_name, client_id=client_id, realm_name=jarvice_realm)

# # Client role: jarvice-sysadmin
# payload = {
#   "name": "jarvice-sysadmin",
#   "description": "",
#   "composite": true,
#   "composites": {
#     "client": {
#       "realm-management": [
#         "realm-admin",
#         "manage-realm",
#         "query-realms",
#         "manage-clients",
#         "view-users",
#         "query-clients",
#         "manage-authorization",
#         "manage-identity-providers",
#         "view-authorization",
#         "manage-events",
#         "view-clients",
#         "view-realm",
#         "query-groups",
#         "impersonation",
#         "manage-users",
#         "query-users",
#         "view-identity-providers",
#         "view-events",
#         "create-client"
#       ],
#       "jarvice": [
#         "jarvice-user"
#       ]
#     }
#   },
#   "clientRole": true,
#   "attributes": {}
# }
# client_role_name=payload['name']

# role_id = keycloakCreateClientRoleIfNotExist(payload=payload, client_role_name=client_role_name, client_id=client_id, realm_name=jarvice_realm)

# # Client role: jarvice-kcadmin
# payload = {
#   "name": "jarvice-kcadmin",
#   "description": "",
#   "composite": true,
#   "composites": {
#     "client": {
#       "jarvice": [
#         "jarvice-sysadmin"
#       ]
#     }
#   },
#   "clientRole": true,
#   "attributes": {}
# }
# client_role_name=payload['name']

# role_id = keycloakCreateClientRoleIfNotExist(payload=payload, client_role_name=client_role_name, client_id=client_id, realm_name=jarvice_realm)

