import datetime
import glob
import json
import multiprocessing
import os
import re
import requests


cache = {}
output = multiprocessing.Queue()


def log(source, message):
    print '[occ-deploy {}Z {}] {}'.format(datetime.datetime.utcnow().isoformat(sep=' ')[:-3], source, message)


def get_commit(sha, org='mozilla-releng', repo='OpenCloudConfig'):
    """
    retrieves the git commit associated with the given org, repo and sha 
    """
    if sha[:7] in cache:
        return cache[sha[:7]]
    url = 'https://api.github.com/repos/{}/{}/commits/{}'.format(org, repo, sha)
    gh_token = os.environ.get('GH_TOKEN')
    response = requests.get(url) if gh_token is None else requests.get(url, headers={'Authorization': 'token {}'.format(gh_token)})
    if response.status_code == 200:
        cache[sha[:7]] = response.json()['commit']
        return cache[sha[:7]]
    return {
        'message': None,
        'committer': {
            'date': None,
            'email': None,
            'name': None
        }
    }


def contains_json(file_path):
    try:
        with open(file_path) as f:
            json.load(f)
    except ValueError, e:
        return False
    return True


def tooltool_shas_exist(worker_type, file_path):
    with open(file_path) as f:
        manifest = json.load(f)
        for component in manifest['Components']:
            if 'sha512' in component:
                log(worker_type, 'checking tooltool for {}/{} ({})'.format(component['ComponentType'], component['ComponentName'], component['sha512']))
                # todo: check sha exists in tooltool
    return True



def is_deploy_requested(worker_type, commit_message):
    deploy_syntax_match = re.search('deploy:( )?([- a-z0-9]*)', commit_message, re.IGNORECASE)
    if deploy_syntax_match:
        worker_types = deploy_syntax_match.group(2).split()
        return worker_type in worker_types
    return False


def process_worker_type(manifest, output):
    """
    """
    worker_type = os.path.splitext(os.path.basename(manifest))[0]
    sha = os.environ.get('GITHUB_HEAD_SHA')
    commit = get_commit(sha)

    # check for valid json manifest
    json_loads = contains_json(manifest)
    log(worker_type, 'manifest contains valid json: {}'.format(json_loads))

    # check that manifest sha hashes exist in tooltool
    shas_exist = tooltool_shas_exist(worker_type, manifest)
    log(worker_type, 'manifest sha hashes exist in tooltool: {}'.format(shas_exist))

    # check if deployment is requested in commit syntax
    deploy_requested = is_deploy_requested(worker_type, commit['message'])
    log(worker_type, 'deployment{}requested for: {}'.format(' ' if deploy_requested else ' not ', worker_type))

    # add manifest/workertype decision logic to queue
    output.put({
        worker_type: {
            'valid': json_loads and shas_exist,
            'json_loads': json_loads,
            'shas_exist': shas_exist,
            'deploy_requested': deploy_requested
        }
    })


# manifests = [x for x in glob.iglob('./userdata/Manifest/gecko-*.json')]
manifests = [x for x in glob.iglob('./userdata/Manifest/gecko-*-beta.json')] + [x for x in glob.iglob('./userdata/Manifest/gecko-*-gpu-b.json')]
processes = [multiprocessing.Process(target=process_worker_type, args=(manifest, output)) for manifest in manifests]
for process in processes:
    process.start()
for process in processes:
    process.join()
results = [output.get() for process in processes]
print(results)
