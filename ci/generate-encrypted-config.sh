#!/bin/bash

temp_dir=$(mktemp -d)
current_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
current_script_name=$(basename ${0##*/} .sh)

echo ${temp_dir}

mkdir -p ${temp_dir}/gnupg
chmod 700 ${temp_dir}/gnupg

accessToken=$(pass Mozilla/TaskCluster/client/project/releng/generic-worker/bitbar-gecko-t-win10-aarch64)
clientId=project/releng/generic-worker/bitbar-gecko-t-win10-aarch64
provisionerId=bitbar
workerGroup=bitbar-sc
workerType=gecko-t-win64-aarch64-laptop
requiredDiskSpaceMegabytes=10240
rootURL=https://firefox-ci-tc.services.mozilla.com
taskDrive=C

for pub_key_path in ${current_script_dir}/../keys/*; do
  workerId=$(basename ${pub_key_path})
  gpg2 --homedir ${temp_dir}/gnupg --import ${pub_key_path}
  jq --sort-keys \
    --arg accessToken ${accessToken} \
    --arg clientId ${clientId} \
    --arg provisionerId ${provisionerId} \
    --arg requiredDiskSpaceMegabytes ${requiredDiskSpaceMegabytes} \
    --arg rootURL ${rootURL} \
    --arg taskDrive ${taskDrive} \
    --arg workerGroup ${workerGroup} \
    --arg workerId ${workerId} \
    --arg workerType ${workerType} \
    '. | .accessToken = $accessToken | .clientId = $clientId | .provisionerId = $provisionerId | .requiredDiskSpaceMegabytes = $requiredDiskSpaceMegabytes | .rootURL = $rootURL | .workerGroup = $workerGroup | .workerId = $workerId | .workerType = $workerType | .cachesDir = $taskDrive + ":\\caches" | .downloadsDir = $taskDrive + ":\\downloads" | .tasksDir = $taskDrive + ":\\tasks"' \
    ${current_script_dir}/../userdata/Configuration/GenericWorker/generic-worker.config > ${current_script_dir}/../cfg/generic-worker/${workerId}.json
  if [ ! -f ${current_script_dir}/../cfg/generic-worker/${workerId}.json.gpg ]; then
    gpg2 --homedir ${temp_dir}/gnupg --batch --output ${current_script_dir}/../cfg/generic-worker/${workerId}.json.gpg --encrypt --recipient yoga-${workerId/t-lenovoyogac630-/} --trust-model always ${current_script_dir}/../cfg/generic-worker/${workerId}.json
  fi
done
recipientList=$(gpg2 --homedir ${temp_dir}/gnupg --list-keys --with-colons --fast-list-mode | awk -F: '/^pub/{printf "-r %s ", $5}')
if [ ! -f ${current_script_dir}/../cfg/OpenCloudConfig.private.key.gpg ]; then
  gpg2 --homedir ${temp_dir}/gnupg --batch --output ${current_script_dir}/../cfg/OpenCloudConfig.private.key.gpg --encrypt ${recipientList} --trust-model always ${current_script_dir}/../cfg/OpenCloudConfig.private.key
fi
rm -rf ${temp_dir}