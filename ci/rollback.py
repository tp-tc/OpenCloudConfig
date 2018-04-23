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
    secret = requests.get(url).json().secret
    return secret.aws_tc_account_id, secret.TASKCLUSTER_AWS_ACCESS_KEY, secret.TASKCLUSTER_AWS_SECRET_KEY


def mutate(image, region_name):
    """
    retrieves the properties of interest from the ec2 describe_image json
    """
    name = image['Name'].split()
    return {
        'CreationDate': image['CreationDate'],
        'ImageId': image['ImageId'],
        'WorkerType': name[0],
        'GitSha': name[-1],
        'Region': region_name
    }


def get_ami_list(
    regions=['eu-central-1', 'us-west-1', 'us-west-2', 'us-east-1', 'us-east-2'],
    name_patterns=['gecko-*-b-win* version *', 'gecko-t-win* version *']):
    """
    retrieves a list of amis in the specified regions and matching the specified name patterns
    """
    aws_account_id, aws_access_key_id, aws_secret_access_key = get_aws_creds()
    boto3.setup_default_session(
        aws_access_key_id=aws_access_key_id,
        aws_secret_access_key=aws_secret_access_key)
    images = []
    for region_name in regions:
        ec2 = boto3.client('ec2', region_name=region_name)
        response = ec2.describe_images(
            Owners=[aws_account_id],
            Filters=[{'Name': 'name', 'Values': name_patterns}])
        images += [mutate(image, region_name) for image in response['Images']]
    return images


print json.dumps(get_ami_list(), indent=2, sort_keys=True)
