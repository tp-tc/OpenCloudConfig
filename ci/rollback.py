import boto3
import datetime
import json
import os
import re
import requests


def get_aws_creds():
    """
    fetch aws credentials from taskcluster secrets.
    """
    url = 'http://{}/secrets/v1/secret/repo:github.com/mozilla-releng/OpenCloudConfig:updateworkertype'.format(os.environ.get('TC_PROXY', 'taskcluster'))
    secret = requests.get(url).json()['secret']
    return secret['aws_tc_account_id'], secret['TASKCLUSTER_AWS_ACCESS_KEY'], secret['TASKCLUSTER_AWS_SECRET_KEY']


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
    aws_account_id,
    regions=['eu-central-1', 'us-west-1', 'us-west-2', 'us-east-1', 'us-east-2'],
    name_patterns=['gecko-*-b-win* version *', 'gecko-t-win* version *']):
    """
    retrieves a list of amis in the specified regions and matching the specified name patterns
    """
    images = []
    for region_name in regions:
        ec2 = boto3.client('ec2', region_name=region_name)
        response = ec2.describe_images(
            Owners=[aws_account_id],
            Filters=[{'Name': 'name', 'Values': name_patterns}])
        images += [mutate(image, region_name) for image in response['Images']]
    return images


def get_security_groups(
    region,
    groups=['ssh-only', 'rdp-only', 'livelog-direct']):
    """
    retrieves a list of security group ids
    - for the specified security group names
    - in the specified region
    """
    ec2 = boto3.client('ec2', region_name=region)
    response = ec2.describe_security_groups(GroupNames=groups)
    return [x['GroupId'] for x in response['SecurityGroups']]


def get_commit_message(sha, org='mozilla-releng', repo='OpenCloudConfig'):
    """
    retrieves the git commit message associated with the given org, repo and sha 
    """
    url = 'https://api.github.com/repos/{}/{}/commits/{}'.format(org, repo, sha)
    return requests.get(url).json()['commit']['message']
    #return 'blah blah\nrollback: gecko-1-b-win2012 23b390b'


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
    quit()


aws_account_id, aws_access_key_id, aws_secret_access_key = get_aws_creds()
boto3.setup_default_session(aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)

current_commit_message = get_commit_message(current_sha)
rollback_syntax_match = re.search('rollback: (gecko-[123]-b-win2012(-beta)?|gecko-t-win(7-32|10-64)(-[^ ])?) ([0-9a-f]{7,40})', current_commit_message, re.IGNORECASE)
if rollback_syntax_match:
    worker_type = rollback_syntax_match.group(1)
    rollback_sha = rollback_syntax_match.group(5)
    ami_list = get_ami_list(aws_account_id, name_patterns=[worker_type + ' version *'])
    sha_list = set([ami['GitSha'] for ami in ami_list])
    print 'rollback available for shas: {}'.format(', '.join(sha_list))
    if True in (sha.startswith(rollback_sha) or rollback_sha.startswith(sha) for sha in sha_list):
        print '{} rollback in progress for worker type: {} to amis with git sha: {}'.format(log_prefix(), worker_type, rollback_sha)
        ami_dict = dict((x['Region'], x['ImageId']) for x in filter_by_sha(ami_list, rollback_sha))
        url = 'http://{}/aws-provisioner/v1/worker-type/{}'.format(os.environ.get('TC_PROXY', 'taskcluster'), worker_type)
        provisioner_config = requests.get(url).json()
        provisioner_config.pop('workerType', None)
        provisioner_config.pop('lastModified', None)
        old_regions_config = provisioner_config['regions']
        print '{} old config'.format(log_prefix())
        print json.dumps(old_regions_config, indent=2, sort_keys=True)
        new_regions_config = [
            {
                'launchSpec': {
                    'ImageId': ami_id,
                    'SecurityGroupIds': get_security_groups(region=region_name)
                },
                'region': region_name,
                'scopes': [],
                'secrets': {},
                'userData': {}
            } for region_name, ami_id in ami_dict.iteritems()]
        print '{} new config'.format(log_prefix())
        print json.dumps(new_regions_config, indent=2, sort_keys=True)
        provisioner_config['regions'] = new_regions_config
        # todo: push new (rollback) config back to aws provisioner
    else:
        print '{} rollback aborted. no amis found matching worker type: {}, and git sha: {}'.format(log_prefix(), worker_type, rollback_sha)
else:
    print '{} rollback request not detected in commit syntax.'.format(log_prefix())