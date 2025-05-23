#!/usr/bin/env python3

import jwt
import requests
from urllib.parse import urlencode
import urllib.parse
import os
import json

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

def keycloakCreateRealmIfNotExist(realm_name):
    access_token = getKeycloakClientToken()
    headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(access_token)
    }
    # List existing realms
    resp = requests.get(
        '{}/admin/realms?briefRepresentation=true'.format(
            keycloak_url
        ),
        headers=headers,
        verify=cacert
    )
    if resp.status_code != 200:
        print(resp.status_code)
        print(resp.content)
        raise SchedError("Keycloak failed to list realms.")
    # print(json.loads(resp.content))
    realm_exists = False
    realm_id = None
    for realm in json.loads(resp.content):
        # print(realm)
        if realm['realm'] == realm_name:
            realm_id = realm['id']
            realm_exists = True
            break

    if not realm_exists:
        payload = {"realm": realm_name, "enabled": "true"}
        # Create realm
        resp = requests.post(
            '{}/admin/realms/'.format(
                keycloak_url
            ),
            data=json.dumps(payload),
            headers=headers,
            verify=cacert
        )
        if int(resp.status_code) != 201:
            print(resp.status_code)
            print(resp.content)
            raise SchedError("Keycloak realm creation failed.")
        realm_id = resp.headers['Location'].split("/")[-1]

    return realm_id

def keycloakCreateClient(payload, client_name, realm_name):
    access_token = getKeycloakClientToken()
    headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(access_token)
    }
    # Create client
    resp = requests.post(
        '{}/admin/realms/{}/clients'.format(
            keycloak_url,
            realm_name
        ),
        data=json.dumps(payload),
        headers=headers,
        verify=cacert
    )
    if int(resp.status_code) != 201:
        print(resp.status_code)
        print(resp.content)
        raise SchedError("Keycloak client creation failed.")
    client_id = resp.headers['Location'].split("/")[-1]
    # Get client (with its secret) and its id
    resp = requests.get(
        '{}/admin/realms/{}/clients/{}'.format(
            keycloak_url,
            realm_name,
            client_id
        ),
        headers=headers,
        verify=cacert
    )
    if resp.status_code != 200:
        print(resp.status_code)
        print(resp.content)
        exit(1)
    client = json.loads(resp.content)
    return client_id, client['secret']

def keycloakCreateClientRole(payload, client_id, realm_name):
    access_token = getKeycloakClientToken()
    headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer {}'.format(access_token)
    }
    # Create client role
    resp = requests.post(
        '{}/admin/realms/{}/clients/{}/roles'.format(
            keycloak_url,
            realm_name,
            client_id
        ),
        data=json.dumps(payload),
        headers=headers,
        verify=cacert
    )
    if int(resp.status_code) != 201:
        print(resp)
        print(resp.status_code)
        print(resp.content)
        exit(1)
    # Get role id
    resp = requests.get(
        '{}/admin/realms/{}/clients/{}/roles/kns-role'.format(
            keycloak_url,
            realm_name,
            client_id
        ),
        headers=headers,
        verify=cacert
    )
    role_id = json.loads(resp.content.decode('utf-8'))['id']

    return role_id


realm_id = keycloakCreateRealmIfNotExist(jarvice_realm)
print(realm_id)


client_name = "jarvice"
redirect_url = "https://jarvice-development-bird.jarvicedev.com"
payload = {
    'protocol': 'openid-connect',
    'clientId': '{}'.format(client_name),
    'name': '',
    'description': '',
    'authorizationServicesEnabled': False,
    'serviceAccountsEnabled': True,
    'implicitFlowEnabled': False,
    'directAccessGrantsEnabled': True,
    'standardFlowEnabled': True,
    'publicClient': False,
    'clientAuthenticatorType': "client-secret",
    'frontchannelLogout': True,
    'attributes': {
        'saml_idp_initiated_sso_url_name': '',
        'oauth2.device.authorization.grant.enabled': False,
        'oidc.ciba.grant.enabled': False
    },
    'alwaysDisplayInConsole': False,
    'rootUrl': '',
    'baseUrl': '',
    'redirectUris': [
        'https://{}/*'.format(redirect_url)
    ],
    'webOrigins': [
        '+'
    ]
}

client_id, client_secret = keycloakCreateClient(payload=payload, client_name=client_name, realm_name=jarvice_realm)

payload = {
    "name": "jarvice-user",
    "description": "",
    "attributes": {}
}
role_id = keycloakCreateClientRole(payload=payload, client_id=client_id, realm_name=jarvice_realm)