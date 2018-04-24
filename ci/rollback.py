import boto3
import datetime
import json
import os
import re
import requests
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


def get_commit_message(sha, org='mozilla-releng', repo='OpenCloudConfig'):
    """
    retrieves the git commit message associated with the given org, repo and sha 
    """
    url = 'https://api.github.com/repos/{}/{}/commits/{}'.format(org, repo, sha)
    return requests.get(url).json()['commit']['message']
    #return 'blah blah\nrollback: gecko-1-b-win2012 d9db25eaf90c'


def filter_by_sha(ami_list, sha):
    """
    filters the specified ami list by the specified git sha
    """
    for ami in ami_list:
       if ami['GitSha'].startswith(sha) or sha.startswith(ami['GitSha']): yield ami


def log_prefix():
    return '[occ-rollback {0}Z]'.format(datetime.datetime.utcnow().isoformat(sep=' ')[:-3])


current_sha = os.environ.get('GITHUB_HEAD_SHA')
if current_sha is None:
    print '{} environment variable "GITHUB_HEAD_SHA" not found.'.format(log_prefix())
else:
    current_commit_message = get_commit_message(current_sha)
    rollback_syntax_match = re.search('rollback: (gecko-[123]-b-win2012(-beta)?|gecko-t-win(7-32|10-64)(-[^ ])?) ([0-9a-f]{7,40})', current_commit_message, re.IGNORECASE)
    if rollback_syntax_match:
        worker_type = rollback_syntax_match.group(1)
        rollback_sha = rollback_syntax_match.group(5)
        ami_list = get_ami_list(name_patterns=[worker_type + ' version *'])
        sha_list = set([ami['GitSha'] for ami in ami_list])
        if True in (sha.startswith(rollback_sha) or rollback_sha.startswith(sha) for sha in sha_list):
            print '{} rollback in progress for worker type: {} to amis with git sha: {}'.format(log_prefix(), worker_type, rollback_sha)
            print json.dumps(list(filter_by_sha(ami_list, rollback_sha)), indent=2, sort_keys=True)
        else:
            print '{} rollback aborted. no amis found matching worker type: {}, and git sha: {}'.format(log_prefix(), worker_type, rollback_sha)
    else:
        print '{} rollback request not detected in commit syntax.'.format(log_prefix())