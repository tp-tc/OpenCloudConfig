#!/bin/bash

updateworkertype_secrets_url="taskcluster/secrets/v1/secret/repo:github.com/mozilla-releng/OpenCloudConfig:updateworkertype"
TASKCLUSTER_CLIENT_ID=$(curl ${password_url} | python -c 'import json, sys; a = json.load(sys.stdin); print a["secret"]["TASKCLUSTER_CLIENT_ID"]')

echo "TASKCLUSTER_CLIENT_ID: $TASKCLUSTER_CLIENT_ID"
