#!/usr/bin/env python3

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
        if str('${' + str(key) + '}') in string_to_update:
            string_to_update = string_to_update.replace(str('${' + str(key) + '}'), val)
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
#    print(resp.content)
#    print(resp)
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
        #print(resp.status_code)
        #print(resp.content)
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
        #print(resp.status_code)
        #print(resp.content)
        print("Failed HTTP POST at " + keycloak_url + url_prefix)
        exit(1)
    return resp


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
        #print(resp.status_code)
        #print(resp.content)
        print("Failed HTTP PUT at " + keycloak_url + url_prefix)
        exit(1)
    return resp

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
        #print(client)
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
    #purl = '/admin/realms/{}/clients/{}'.format(realm_name, client_id)
    #resp = getRequest(purl)
    #client = json.loads(resp.content)
    return client_id #, client['secret']

def keycloakCreateRoleIfNotExist(payload, role_name, realm_name):

    purl = '/admin/realms/{}/roles'.format(realm_name)

    # List existing roles
    resp = getRequest(purl)

    # Check role is in the list
    role_exists = False
    role_id = None
    for role in json.loads(resp.content):
        if role['name'] == role_name:
            role_id = role['id']
            role_exists = True
            break

    # Create role
    if not role_exists:
        print('Creating ' + role_name + ' role.')
        resp = postRequest(purl, payload)
        role_id = resp.headers['Location'].split("/")[-1]
    else:
        print('Role ' + role_name + ' already exists, updating it.')
        purl = '/admin/realms/{}/roles-by-id/{}'.format(realm_name, role_id)
        resp = putRequest(purl, payload)

    return role_id

def keycloakCreateUserIfNotExist(payload, user_name, realm_name):

    purl = '/admin/realms/{}/users'.format(realm_name)

    # List existing users
    resp = getRequest(purl)

    # Check user is in the list
    user_exists = False
    user_id = None
    for user in json.loads(resp.content):
        if user['username'] == user_name:
            user_id = user['id']
            user_exists = True
            break

    # Create user
    if not user_exists:
        print('Creating ' + user_name + ' user.')
        resp = postRequest(purl, payload)
        user_id = resp.headers['Location'].split("/")[-1]
    else:
        print('User ' + user_name + ' already exists, updating it.')
        purl = '/admin/realms/{}/users/{}'.format(realm_name, user_id)
        resp = putRequest(purl, payload)

    return user_id

def keycloakCreateClientRoleIfNotExist(payload, client_role_name, client_id, realm_name):

    purl = '/admin/realms/{}/clients/{}/roles'.format(realm_name, client_id)

    # List existing roles
    resp = getRequest(purl)

    # Check client role is in the list
    client_role_exists = False
    client_role_id = None
    for client_role in json.loads(resp.content):
        if client_role['name'] == client_role_name:
            client_role_id = client_role['id']
            client_role_exists = True
            break

    # Create client
    if not client_role_exists:
        print('Creating ' + client_role_name + ' client role.')
        resp = postRequest(purl, payload)
        client_role_id = resp.headers['Location'].split("/")[-1]
    else:
        print('Client role ' + client_role_name + ' already exists, updating it.')
        purl = '/admin/realms/{}/clients/{}/roles/{}'.format(realm_name, client_id, client_role_name)
        resp = putRequest(purl, payload)

    return client_role_id


print("Entering creation/update tree")

# List realms to create
for realm in os.listdir("./realms/"):
    print("Working on realm: " + str(realm)) 
    # Load realm configuration
    with open("./realms/" + str(realm) + "/main.json", 'r') as configuration_file:
        file_content = update_string_by_jarvice_env(configuration_file.read())
    realm_payload = json.loads(file_content)
    # Extract name from payload, dont user file name
    realm_name = str(realm_payload['realm'])
    # Create realm
    realm_id = keycloakCreateRealmIfNotExist(realm_name, realm_payload)

    # List roles to create
    if os.path.isdir("./realms/" + str(realm) + "/roles/"):
        for role in os.listdir("./realms/" + str(realm) + "/roles/"):
            print("Working on realm role: " + str(role))
            # Load role configuration
            with open("./realms/" + str(realm) + "/roles/" + str(role), 'r') as configuration_file:
                file_content = update_string_by_jarvice_env(configuration_file.read())
            role_payload = json.loads(file_content)
            # Extract name from payload, dont use file name
            role_name = role_payload['name']
            # Create client
            role_id = keycloakCreateRoleIfNotExist(payload=role_payload, role_name=role_name, realm_name=realm_name)

    # List users to create
    if os.path.isdir("./realms/" + str(realm) + "/users/"):
        for user in os.listdir("./realms/" + str(realm) + "/users/"):
            print("Working on realm user: " + str(user))
            # Load user configuration
            with open("./realms/" + str(realm) + "/users/" + str(user), 'r') as configuration_file:
                file_content = update_string_by_jarvice_env(configuration_file.read())
            user_payload = json.loads(file_content)
            # Extract name from payload, dont use file name
            user_name = user_payload['username']
            # Create client
            user_id = keycloakCreateUserIfNotExist(payload=user_payload, user_name=user_name, realm_name=realm_name)

    # List clients to create
    if os.path.isdir("./realms/" + str(realm) + "/clients/"):
        for client in os.listdir("./realms/" + str(realm) + "/clients/"):
            print("Working on client: " + str(client))
            # Load client configuration
            # There might be no client to create if it already exist by default, check if main.json exists
            # If not exist, assume it already exists and skip
            if os.path.isfile("./realms/" + str(realm) + "/clients/" + str(client) + "/main.json"):
                with open("./realms/" + str(realm) + "/clients/" + str(client) + "/main.json", 'r') as configuration_file:
                    file_content = update_string_by_jarvice_env(configuration_file.read())
                client_payload = json.loads(file_content)
                # Extract name from payload, dont use file name
                client_name = client_payload['clientId']
                # Create client
                client_id = keycloakCreateClientIfNotExist(payload=client_payload, client_name=client_name, realm_name=realm_name)

            # List client roles to create
            if os.path.isdir("./realms/" + str(realm) + "/clients/" + str(client) + "/roles/"):
                for client_role in sorted(os.listdir("./realms/" + str(realm) + "/clients/" + str(client) + "/roles/")):
                    print("Working on client role: " + str(client_role.replace('.json','')))
                    # Load client role configuration
                    with open("./realms/" + str(realm) + "/clients/" + str(client) +  "/roles/" + client_role, 'r') as configuration_file:
                        file_content = update_string_by_jarvice_env(configuration_file.read())
                    client_role_payload = json.loads(file_content)
                    # Special case: this could be a list of roles, check that
                    is_a_list = False
                    try:
                        buffer = client_role_payload.keys
                    except:
                        is_a_list = True
                    #print("COUCOUCOUCOUCOUCOUCOUCOUC ----->>>")
                    #print(is_a_list)
                    if not is_a_list:
                        # Extract name from payload
                        client_role_name = client_role_payload['name']
                        # Create client role
                        client_role_id = keycloakCreateClientRoleIfNotExist(payload=client_role_payload, client_role_name=client_role_name, client_id=client_id, realm_name=realm_name)
                    else:
                        #print(client_role_payload)
                        for role in client_role_payload:
                            #print("COUCOU")
                            #print(role)

                            # Extract name from payload
                            client_role_name = role['name']
                            # Create client role
                            client_role_id = keycloakCreateClientRoleIfNotExist(payload=role, client_role_name=client_role_name, client_id=client_id, realm_name=realm_name)


