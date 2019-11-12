#!/bin/bash

temp_dir=$(mktemp -d)
current_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
current_script_name=$(basename ${0##*/} .sh)

echo ${temp_dir}

rm -f ${current_script_dir}/../cfg/generic-worker/*.json.gpg
rm -f ${current_script_dir}/../cfg/OpenCloudConfig.private.key.gpg

mkdir -p ${temp_dir}/gnupg
chmod 700 ${temp_dir}/gnupg

accessToken=$(pass Mozilla/TaskCluster/client/project/releng/generic-worker/bitbar-gecko-t-win10-aarch64)
clientId=project/releng/generic-worker/bitbar-gecko-t-win10-aarch64
provisionerId=bitbar
workerGroup=bitbar-sc
workerType=gecko-t-win64-aarch64-laptop
rootURL=https://firefox-ci-tc.services.mozilla.com
taskDrive=C

for pub_key_path in ${current_script_dir}/../keys/*; do
  workerId=$(basename ${pub_key_path})
  workerNumberPadded=${workerId/t-lenovoyogac630-/}
  workerNumber=$((10#$workerNumberPadded))
  # most instances have an ip address of 10.7.204.(instance-number + 20) but there are exceptions.
  if [ "${workerId}" == "t-lenovoyogac630-003" ]; then
    publicIP=10.7.205.32
  elif [ "${workerId}" == "t-lenovoyogac630-012" ]; then
    publicIP=10.7.205.85
  elif [ "${workerId}" == "t-lenovoyogac630-020" ]; then
    publicIP=10.7.205.48
  else
    publicIP=10.7.204.$(( 20 + workerNumber ))
  fi
  gpg2 --homedir ${temp_dir}/gnupg --import ${pub_key_path}
  jq --sort-keys \
    --arg accessToken ${accessToken} \
    --arg clientId ${clientId} \
    --arg provisionerId ${provisionerId} \
    --arg publicIP ${publicIP} \
    --arg rootURL ${rootURL} \
    --arg taskDrive ${taskDrive} \
    --arg workerGroup ${workerGroup} \
    --arg workerId ${workerId} \
    --arg workerType ${workerType} \
    '. | .accessToken = $accessToken | .clientId = $clientId | .provisionerId = $provisionerId | .publicIP = $publicIP | .rootURL = $rootURL | .workerGroup = $workerGroup | .workerId = $workerId | .workerType = $workerType | .cachesDir = $taskDrive + ":\\caches" | .downloadsDir = $taskDrive + ":\\downloads" | .tasksDir = $taskDrive + ":\\tasks"' \
    ${current_script_dir}/../userdata/Configuration/GenericWorker/generic-worker.config > ${current_script_dir}/../cfg/generic-worker/${workerId}.json
  if [ ! -f ${current_script_dir}/../cfg/generic-worker/${workerId}.json.gpg ]; then
    gpg2 --homedir ${temp_dir}/gnupg --batch --output ${current_script_dir}/../cfg/generic-worker/${workerId}.json.gpg --encrypt --recipient yoga-${workerNumberPadded} --trust-model always ${current_script_dir}/../cfg/generic-worker/${workerId}.json
  else
    gpg2 --list-only -v -d ${current_script_dir}/../cfg/generic-worker/${workerId}.json.gpg
  fi
done
recipientList=$(gpg2 --homedir ${temp_dir}/gnupg --list-keys --with-colons --fast-list-mode | awk -F: '/^pub/{printf "-r %s ", $5}')
if [ ! -f ${current_script_dir}/../cfg/OpenCloudConfig.private.key.gpg ]; then
  gpg2 --homedir ${temp_dir}/gnupg --batch --output ${current_script_dir}/../cfg/OpenCloudConfig.private.key.gpg --encrypt ${recipientList} --trust-model always ${current_script_dir}/../cfg/OpenCloudConfig.private.key
else
  gpg2 --list-only -v -d ${current_script_dir}/../cfg/OpenCloudConfig.private.key.gpg
fi
rm -rf ${temp_dir}