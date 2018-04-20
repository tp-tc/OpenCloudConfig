import boto3
import json
import requests
import os.path
from ConfigParser import ConfigParser


def get_aws_creds():
    """
    fetch aws credentials
    - from taskcluster secrets when running as a taskcluster github job
    - from aws credentials file when debugging
    """
    credentials_config = os.path.join(os.path.expanduser('~'), '.aws', 'credentials')
    if os.path.isfile(credentials_config):
        config = ConfigParser()
        config.read(credentials_config)
        return config.get('occ-taskcluster', 'aws_account_id'), config.get('occ-taskcluster', 'aws_access_key_id'), config.get('occ-taskcluster', 'aws_secret_access_key')

    url = 'http://taskcluster/secrets/v1/secret/repo:github.com/mozilla-releng/OpenCloudConfig:updateworkertype'
    s = requests.get(url).json().secret
    return s.aws_tc_account_id, s.TASKCLUSTER_AWS_ACCESS_KEY, s.TASKCLUSTER_AWS_SECRET_KEY


aws_account_id, aws_access_key_id, aws_secret_access_key = get_aws_creds()
boto3.setup_default_session(
    aws_access_key_id=aws_access_key_id,
    aws_secret_access_key=aws_secret_access_key)
ec2 = boto3.client('ec2')
response = ec2.describe_images(
    Owners=[aws_account_id],
    Filters=[{'Name':'name', 'Values':['gecko-*-b-win* version *', 'gecko-t-win* version *']}])
print json.dumps(response, indent=2, sort_keys=True)
