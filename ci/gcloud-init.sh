#!/bin/bash -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

names_first=(`jq -r '.unicorn.first[]' ${script_dir}/names.json`)
names_middle=(`jq -r '.unicorn.middle[]' ${script_dir}/names.json`)
names_last=(`jq -r '.unicorn.last[]' ${script_dir}/names.json`)

zone_uri_list=(`gcloud compute zones list --uri`)
zone_name_list=("${zone_uri_list[@]##*/}")

_echo() {
  if [ -n "$TERM" ]; then
    script_name=$(basename ${0##*/} .sh)
    message=${1//_bold_/$(tput bold)}
    message=${message//_dim_/$(tput dim)}
    message=${message//_reset_/$(tput sgr0)}
    echo "$(tput dim)[${script_name} $(date --utc +"%F %T.%3NZ")]$(tput sgr0) ${message}"
  else
    message=${1//_bold_/}
    message=${message//_dim_/}
    message=${message//_reset_/}
    echo ${message}
  fi
}

if command -v pass > /dev/null; then
  livelogSecret=`pass Mozilla/TaskCluster/livelogSecret`
  livelogcrt=`pass Mozilla/TaskCluster/livelogCert`
  livelogkey=`pass Mozilla/TaskCluster/livelogKey`
  pgpKey=`pass Mozilla/OpenCloudConfig/rootGpgKey`
  relengapiToken=`pass Mozilla/OpenCloudConfig/tooltool-relengapi-tok`
  occInstallersToken=`pass Mozilla/OpenCloudConfig/tooltool-occ-installers-tok`
elif curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes > /dev/null; then
  livelogSecret=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/livelogSecret")
  livelogcrt=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/livelogcrt")
  livelogkey=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/livelogkey")
  pgpKey=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/pgpKey")
  relengapiToken=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/relengapiToken")
  occInstallersToken=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/occInstallersToken")
else
  _echo "failed to determine a source for secrets_reset_"
  exit 1
fi
provisionerId=releng-hardware
GITHUB_HEAD_SHA=`git rev-parse HEAD`
deploymentId=${GITHUB_HEAD_SHA:0:12}

if [[ $@ == *"--open-in-browser"* ]] && which xdg-open > /dev/null; then
  xdg-open "https://console.cloud.google.com/compute/instances?authuser=1&folder&organizationId&project=windows-workers&instancessize=50&duration=PT1H&pli=1&instancessort=zoneForFilter%252Cname"
fi
_echo "deployment id: _bold_${deploymentId}_reset_"
for manifest in $(ls ${script_dir}/../userdata/Manifest/*-gamma.json); do
  workerType=$(basename ${manifest##*/} .json)
  _echo "worker type: _bold_${workerType}_reset_"
  if command -v pass > /dev/null; then
    accessToken=`pass Mozilla/TaskCluster/project/releng/generic-worker/${workerType}/production`
  elif curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes > /dev/null; then
    accessToken=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/access-token-${workerType}")
  else
    _echo "failed to determine a source for secrets_reset_"
    exit 1
  fi
  # determine the number of instances to spawn by checking the pending count for the worker type
  pendingTaskCount=$(curl -s "https://queue.taskcluster.net/v1/pending/${provisionerId}/${workerType}" | jq '.pendingTasks')
  _echo "${workerType} pending tasks: _bold_${pendingTaskCount}_reset_"

  # determine the number of instances already spawned that have not yet claimed tasks
  queue_registered_instance_count=0
  queue_unregistered_instance_count=0
  for running_instance_uri in $(gcloud compute instances list --uri --filter="labels.worker-type:${workerType}" 2> /dev/null); do
    running_instance_name=${running_instance_uri##*/}
    running_instance_zone_uri=${running_instance_uri/\/instances\/${running_instance_name}/}
    running_instance_zone=${running_instance_zone_uri##*/}
    if [ $(curl -s "https://queue.taskcluster.net/v1/provisioners/${provisionerId}/worker-types/${workerType}/workers" | jq --arg workerId ${running_instance_name} '[.workers[] | select(.workerId == $workerId)] | length') -gt 0 ]; then
      #((queue_registered_instance_count++))
      _echo "${workerType} working instance detected: _bold_${running_instance_name}_reset_ in _bold_${running_instance_zone}_reset_"
      (( queue_registered_instance_count = queue_registered_instance_count + 1 ))
    else
      #((queue_unregistered_instance_count++))
      _echo "${workerType} pending instance detected: _bold_${running_instance_name}_reset_ in _bold_${running_instance_zone}_reset_"
      (( queue_unregistered_instance_count = queue_unregistered_instance_count + 1 ))
    fi
  done
  _echo "${workerType} pending instances: _bold_${queue_unregistered_instance_count}_reset_"
  _echo "${workerType} working instances: _bold_${queue_registered_instance_count}_reset_"
  required_instance_count=0
  if [ ${queue_unregistered_instance_count} -lt ${pendingTaskCount} ]; then
    (( required_instance_count = pendingTaskCount - queue_unregistered_instance_count ))
  fi
  _echo "${workerType} required instances: _bold_${required_instance_count}_reset_"
  if [ ${required_instance_count} -gt 0 ]; then
    # spawn some instances
    for i in $(seq 1 ${required_instance_count}); do
      # pick a random machine type from the list of machine types in the provisioner configuration of the manifest
      instanceTypes=(`jq -r '.ProvisionerConfiguration.releng_gcp_provisioner.machine_types[]' ${manifest}`)
      instanceType=${instanceTypes[$[$RANDOM % ${#instanceTypes[@]}]]}
      instanceCpuCount=${instanceType##*-}
      # pick a random zone that has region cpu quota (minus usage) higher than required instanceCpuCount
      zone_name=${zone_name_list[$[$RANDOM % ${#zone_name_list[@]}]]}
      region=${zone_name::-2}
      cpuQuota=$(gcloud compute regions describe ${region} --project windows-workers --format json | jq '.quotas[] | select(.metric == "CPUS").limit')
      cpuUsage=$(gcloud compute regions describe ${region} --project windows-workers --format json | jq '.quotas[] | select(.metric == "CPUS").usage')
      while (( (cpuQuota - cpuUsage) < instanceCpuCount )); do
        _echo "skipping region: ${region} (cpu quota: ${cpuQuota}, cpu usage: ${cpuUsage})_reset_"
        zone_name=${zone_name_list[$[$RANDOM % ${#zone_name_list[@]}]]}
        region=${zone_name::-2}
        cpuQuota=$(gcloud compute regions describe ${region} --project windows-workers --format json | jq '.quotas[] | select(.metric == "CPUS").limit')
        cpuUsage=$(gcloud compute regions describe ${region} --project windows-workers --format json | jq '.quotas[] | select(.metric == "CPUS").usage')
      done
      # generate a random instance name which does not pre-exist
      existing_instance_uri_list=(`gcloud compute instances list --uri`)
      existing_instance_name_list=("${existing_instance_uri_list[@]##*/}")
      instance_name=${names_first[$[$RANDOM % ${#names_first[@]}]]}-${names_middle[$[$RANDOM % ${#names_middle[@]}]]}-${names_last[$[$RANDOM % ${#names_last[@]}]]}
      while [[ " ${existing_instance_name_list[@]} " =~ " ${instance_name} " ]]; do
        instance_name=${names_first[$[$RANDOM % ${#names_first[@]}]]}-${names_middle[$[$RANDOM % ${#names_middle[@]}]]}-${names_last[$[$RANDOM % ${#names_last[@]}]]}
      done
      _echo "instance name: _bold_${instance_name}_reset_"
      _echo "zone name: _bold_${zone_name}_reset_"
      _echo "region: _bold_${region}_reset_"
      _echo "instance type: _bold_${instanceType}_reset_"
      _echo "worker group: _bold_${region}_reset_"
      gcloud compute instances create ${instance_name} \
        --image-project windows-cloud \
        --image-family windows-2012-r2 \
        --machine-type ${instanceType} \
        --boot-disk-size 50 \
        --boot-disk-type pd-ssd \
        --scopes storage-ro \
        --metadata "^;^windows-startup-script-url=gs://open-cloud-config/gcloud-startup.ps1;workerType=${workerType};sourceOrg=mozilla-releng;sourceRepo=OpenCloudConfig;sourceRevision=gamma;pgpKey=${pgpKey};livelogkey=${livelogkey};livelogcrt=${livelogcrt};relengapiToken=${relengapiToken};occInstallersToken=${occInstallersToken}" \
        --zone ${zone_name} \
        --preemptible
      publicIP=$(gcloud compute instances describe ${instance_name} --zone ${zone_name} --format json | jq -r '.networkInterfaces[0].accessConfigs[0].natIP')
      _echo "public ip: _bold_${publicIP}_reset_"
      privateIP=$(gcloud compute instances describe ${instance_name} --zone ${zone_name} --format json | jq -r '.networkInterfaces[0].networkIP')
      _echo "private ip: _bold_${privateIP}_reset_"
      instanceId=$(gcloud compute instances describe ${instance_name} --zone ${zone_name} --format json | jq -r '.id')
      _echo "instance id: _bold_${instanceId}_reset_"
      gwConfig="`curl -s https://raw.githubusercontent.com/mozilla-releng/OpenCloudConfig/gamma/userdata/Manifest/${workerType}.json | jq --arg accessToken ${accessToken} --arg livelogSecret ${livelogSecret} --arg publicIP ${publicIP} --arg privateIP ${privateIP} --arg workerId ${instance_name} --arg provisionerId ${provisionerId} --arg region ${region} --arg deploymentId ${deploymentId} --arg availabilityZone ${zone_name} --arg instanceId ${instanceId} --arg instanceType ${instanceType} -c '.ProvisionerConfiguration.userData.genericWorker.config | .accessToken = $accessToken | .livelogSecret = $livelogSecret | .publicIP = $publicIP | .privateIP = $privateIP | .workerId = $workerId | .instanceId = $instanceId | .instanceType = $instanceType | .availabilityZone = $availabilityZone | .region = $region | .provisionerId = $provisionerId | .workerGroup = $region | .deploymentId = $deploymentId' | sed 's/\"/\\\"/g'`"
      gcloud compute instances add-metadata ${instance_name} --zone ${zone_name} --metadata "^;^gwConfig=${gwConfig}"
      gcloud beta compute disks create ${instance_name}-disk-1 --size 120 --type pd-ssd --physical-block-size 4096 --zone ${zone_name}
      gcloud compute instances attach-disk ${instance_name} --disk ${instance_name}-disk-1 --zone ${zone_name}
      gcloud compute instances add-labels ${instance_name} --zone ${zone_name} --labels=worker-type=${workerType}
    done
  #else
    # delete instances that have never taken a task
    #for instance in $(curl -s "https://queue.taskcluster.net/v1/provisioners/${provisionerId}/worker-types/${workerType}/workers" | jq -r '.workers[] | select(.latestTask == null) | @base64'); do
    #  _jq_zombie_instance() {
    #    echo ${instance} | base64 --decode | jq -r ${1}
    #  }
    #  zoneUrl=$(gcloud compute instances list --filter="name:$(_jq_zombie_instance '.workerId') AND zone~$(_jq_zombie_instance '.workerGroup')" --format=json | jq -r '.[0].zone')
    #  zone=${zoneUrl##*/}
    #  if [ -n "${zoneUrl}" ] && [ -n "${zone}" ] && [[ "${zone}" != "null" ]] && gcloud compute instances delete $(_jq_zombie_instance '.workerId') --zone ${zone} --delete-disks all --quiet; then
    #    _echo "deleted: _bold_${zone}/$(_jq_zombie_instance '.workerId')_reset_"
    #  fi
    #done
  fi
  if [[ "$(jq -r '.ProvisionerConfiguration.releng_gcp_provisioner.idle_termination_threshold' ${manifest})" == "null" ]]; then
    _echo "idle threshold not configured for worker type ${workerType}_reset_"
  else
    # delete instances that have not taken a task within the idle threshold. note that the tc queue may return instances that have long since terminated
    idlePeriod=$(jq -r '.ProvisionerConfiguration.releng_gcp_provisioner.idle_termination_threshold.period' ${manifest})
    idleInterval=$(jq -r '.ProvisionerConfiguration.releng_gcp_provisioner.idle_termination_threshold.interval' ${manifest})
    idleThreshold=$(date --date "${idleInterval} ${idlePeriod} ago" +%s)
    for instance in $(curl -s "https://queue.taskcluster.net/v1/provisioners/${provisionerId}/worker-types/${workerType}/workers" | jq -r '.workers[] | select(.latestTask != null) | @base64'); do
      _jq_idle_instance() {
        echo ${instance} | base64 --decode | jq -r ${1}
      }
      zoneUrl=$(gcloud compute instances list --filter="name:$(_jq_idle_instance '.workerId') AND zone~$(_jq_idle_instance '.workerGroup')" --format=json | jq -r '.[0].zone')
      if [ -n "${zoneUrl}" ] && [[ "${zoneUrl}" != "null" ]]; then
        zone=${zoneUrl##*/}
        latestResolvedTaskTimeInUtc=$(curl -s "https://queue.taskcluster.net/v1/task/$(_jq_idle_instance '.latestTask.taskId')/status" | jq --arg runId $(_jq_idle_instance '.latestTask.runId') -r '.status.runs[] | select(.runId == ($runId | tonumber)) | .resolved')
        if [ -n "${latestResolvedTaskTimeInUtc}" ] && [[ "${latestResolvedTaskTimeInUtc}" != "null" ]]; then
          latestResolvedTaskTime=$(date --date "${latestResolvedTaskTimeInUtc}" +%s)
          _echo "${workerType}/${zone}/$(_jq_idle_instance '.workerId') last resolved task: _bold_${latestResolvedTaskTimeInUtc}_reset_ ($(( ($(date +%s) - $latestResolvedTaskTime) / 60)) minutes ago)"
          if [ ${latestResolvedTaskTime} -lt ${idleThreshold} ] && gcloud compute instances delete $(_jq_idle_instance '.workerId') --zone ${zone} --delete-disks all --quiet; then
            _echo "deleted: _bold_${zone}/$(_jq_idle_instance '.workerId')_reset_"
          fi
        fi
      fi
    done
  fi
done
# delete orphaned disks
for disk in $(gcloud compute disks list --filter=-users:* --format json | jq -r '.[] | @base64'); do
  _jq_orphaned_disk() {
    echo ${disk} | base64 --decode | jq -r ${1}
  }
  zoneUrl=$(_jq_orphaned_disk '.zone')
  zone=${zoneUrl##*/}
  gcloud compute disks delete $(_jq_orphaned_disk '.name') --zone ${zone} --quiet
  _echo "deleted orphaned disk: _bold_$(_jq_orphaned_disk '.name') (${zone})_reset_"
done
# open the firewall to livelog traffic
# gcloud compute firewall-rules create livelog-direct --allow tcp:60023 --description "allows connections to livelog GET interface, running on taskcluster worker instances"