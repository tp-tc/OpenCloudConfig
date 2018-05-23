import os
import requests


SECRET_KEY = {
    'AWS'     : 'repo:github.com/mozilla-releng/OpenCloudConfig:updateworkertype',
    'TOOLTOOL': 'repo:github.com/mozilla-releng/OpenCloudConfig:updatetooltoolrepo'
}

def get_secret(key, host=None):
    """
    fetch a secret from taskcluster secrets.
    """
    if host is None:
        host = os.environ.get('TC_PROXY', 'taskcluster')
    url = 'http://{}/secrets/v1/secret/{}'.format(host, key)
    response = requests.get(url)
    return response.json()['secret'] if response.status_code == 200 else response.json()


def get_tooltool_token():
    """
    fetch tooltool upload internal token from taskcluster secrets.
    """
    secret = get_secret(SECRET_KEY['TOOLTOOL'])
    return secret['tooltool']['upload']['internal']


def get_aws_creds(secret_key=):
    """
    fetch aws credentials from taskcluster secrets.
    """
    secret = get_secret(SECRET_KEY['AWS'])
    return secret['aws_tc_account_id'], secret['TASKCLUSTER_AWS_ACCESS_KEY'], secret['TASKCLUSTER_AWS_SECRET_KEY']