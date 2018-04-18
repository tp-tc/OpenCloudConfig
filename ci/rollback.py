import requests


def get_aws_creds():
  """
  fetch aws credentials from taskcluster secrets
  """
  url = 'http://taskcluster/secrets/v1/secret/repo:github.com/mozilla-releng/OpenCloudConfig:updateworkertype'
  s = requests.get(url).json().secret
  return s.aws_tc_account_id, s.TASKCLUSTER_AWS_ACCESS_KEY, s.TASKCLUSTER_AWS_SECRET_KEY


account_id, access_key, secret_key = get_aws_creds()
