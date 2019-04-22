#!/bin/bash -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp/}$(basename ${0##*/} .sh).XXXXXXXXXXXX")

# create a logging function that outputs easily readable console messages but strips formatting when logging to papertrail
_echo() {
  if [ -z "$TERM" ] || [[ "${HOSTNAME}" == "releng-gcp-provisioner-"* ]]; then
    message=${1//_bold_/}
    message=${message//_dim_/}
    message=${message//_reset_/}
    echo ${message}
  else
    script_name=$(basename ${0##*/} .sh)
    message=${1//_bold_/$(tput bold)}
    message=${message//_dim_/$(tput dim)}
    message=${message//_reset_/$(tput sgr0)}
    echo "$(tput dim)[${script_name} $(date --utc +"%F %T.%3NZ")]$(tput sgr0) ${message}"
  fi
}

_echo "temp_dir: _bold_${temp_dir}_reset_"
subl ${temp_dir}

# iterate through each worker type in the occ manifest directory
for manifest in $(ls ${script_dir}/../userdata/Manifest/*.json | grep -v 'a64-beta\|hw\|ux\|gamma\|secrets\|schema.json$' | shuf); do
  workerType=$(basename ${manifest##*/} .json)
  if [[ "${workerType}" == *"linux"* ]]; then
    workerImplementation=docker-worker
  else
    workerImplementation=generic-worker
  fi
  provisionerId=aws-provisioner-v1
  _echo "worker type: _bold_${workerType}_reset_"

  # determine the number of instances already running and what state they are in
  running_instance_count=0

  # count of instances currently processing a task
  working_instance_count=0

  # count of instances currently waiting for a task to process
  waiting_instance_count=0

  # count of instances currently initialising or booting up for the first time
  pending_instance_count=0

  # count of instances which have not registered a first claim with the taskcluster queue but have been running long enough to have done so
  zombied_instance_count=0

  # count of instances in an unknown state
  goofing_instance_count=0

  # count of instances that have already been deleted (probably by another provisioner instance) by the time we attempt state discovery
  deleted_instance_count=0

  idle_termination_interval=120
  _echo "${workerType} idle termination after: _bold_${idle_termination_interval} minutes_reset_"
  # iterate all instances of the current worker type which are in a running state
  ec2_regions=(us-east-1 us-west-1 us-west-2 eu-central-1)
  for running_instance_region in $(shuf -e ${ec2_regions[@]}); do
    _echo "region: _bold_${running_instance_region}_reset_"
    for running_instance_name in $(aws ec2 describe-instances --region ${running_instance_region} --query 'Reservations[*].Instances[*].[InstanceId]' --filters Name=instance-state-name,Values=running Name=instance-lifecycle,Values=spot Name=tag:Name,Values=${workerType} --output text 2> /dev/null | shuf); do
      worker_id=${running_instance_name}
      if aws ec2 describe-instances --region ${running_instance_region} --instance-ids ${running_instance_name} | jq '.Reservations[0].Instances[0]' > ${temp_dir}/${running_instance_region}-${running_instance_name}.json 2> /dev/null; then
        running_instance_creation_timestamp=$(date --utc -d $(cat ${temp_dir}/${running_instance_region}-${running_instance_name}.json | jq -r '.LaunchTime') +%FT%T.%3NZ)
        # calculate uptime based on gcloud creation timestamp
        running_instance_uptime_minutes=$(( ($(date +%s) - $(date -d ${running_instance_creation_timestamp} +%s)) / 60))
        if [ "${running_instance_uptime_minutes}" -gt "60" ]; then
          running_instance_uptime="$((${running_instance_uptime_minutes} / 60)) hours, $((${running_instance_uptime_minutes} % 60)) minutes"
        else
          running_instance_uptime="${running_instance_uptime_minutes} minutes"
        fi
        if curl -s -o ${temp_dir}/queue-${worker_id}.json "https://queue.taskcluster.net/v1/provisioners/${provisionerId}/worker-types/${workerType}/workers/${running_instance_region}/${worker_id}" && [[ "$(jq -r '.code // empty' ${temp_dir}/queue-${worker_id}.json)" != "ResourceNotFound" ]]; then
          first_claim=$(jq -r '.firstClaim' ${temp_dir}/queue-${worker_id}.json)
          last_task_id=$(jq -r '.recentTasks[-1].taskId // empty' ${temp_dir}/queue-${worker_id}.json)
          last_task_run_id=$(jq -r '.recentTasks[-1].runId // empty' ${temp_dir}/queue-${worker_id}.json)
          if [ -n "${last_task_id}" ] && [ -n "${last_task_run_id}" ] && curl -s -o ${temp_dir}/${last_task_id}.json "https://queue.taskcluster.net/v1/task/${last_task_id}/status" && [ -s ${temp_dir}/${last_task_id}.json ]; then
            last_task_run_state=$(jq --arg runId ${last_task_run_id} -r '.status.runs[]? | select(.runId == ($runId | tonumber)) | .state' ${temp_dir}/${last_task_id}.json)
            last_task_run_started_time=$(jq --arg runId ${last_task_run_id} -r '.status.runs[]? | select(.runId == ($runId | tonumber)) | .started' ${temp_dir}/${last_task_id}.json)
            last_task_run_created_reason=$(jq --arg runId ${last_task_run_id} -r '.status.runs[]? | select(.runId == ($runId | tonumber)) | .reasonCreated' ${temp_dir}/${last_task_id}.json)
          fi
          
          if [ -n "${last_task_id}" ] && [ -n "${last_task_run_id}" ] && [ -n "${last_task_run_state}" ] && [[ "${last_task_run_state}" != "running" ]]; then
            last_task_run_resolved_time=$(cat ${temp_dir}/${last_task_id}.json | jq --arg runId ${last_task_run_id} -r '.status.runs[]? | select(.runId == ($runId | tonumber)) | .resolved')
            last_task_run_resolved_reason=$(cat ${temp_dir}/${last_task_id}.json | jq --arg runId ${last_task_run_id} -r '.status.runs[]? | select(.runId == ($runId | tonumber)) | .reasonResolved')
            wait_time_minutes=$(( ($(date +%s) - $(date -d ${last_task_run_resolved_time} +%s)) / 60))
            if [ "${wait_time_minutes}" -gt "60" ]; then
              wait_time="$((${wait_time_minutes} / 60)) hours, $((${wait_time_minutes} % 60)) minutes"
            else
              wait_time="${wait_time_minutes} minutes"
            fi
            #if [ "$(date -d ${last_task_run_started_time} +%s)" -lt "$(date -d ${last_task_run_resolved_time} +%s)" ] && [ "${wait_time_minutes}" -gt "${idle_termination_interval}" ] && gcloud compute instances delete ${running_instance_name} --zone ${running_instance_zone} --delete-disks all --quiet 2> /dev/null; then
            if [ "$(date -d ${last_task_run_started_time} +%s)" -lt "$(date -d ${last_task_run_resolved_time} +%s)" ] && [ "${wait_time_minutes}" -gt "${idle_termination_interval}" ]; then
              # reaching here indicates the instance has been waiting for work to do for more than ${idle_termination_interval} minutes, so we've killed it
              _echo "${workerType} waiting instance deleted: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp}). resolved ${last_task_run_created_reason} task: _bold_${last_task_id}/${last_task_run_id}_reset_ with status: ${last_task_run_resolved_reason}, ${wait_time} ago (at ${last_task_run_resolved_time})"
            #elif [ "$(date -d ${last_task_run_started_time} +%s)" -lt "$(date -d ${last_task_run_resolved_time} +%s)" ] && [[ "${running_instance_deployment_id}" != "${deploymentId}" ]] && gcloud compute instances delete ${running_instance_name} --zone ${running_instance_zone} --delete-disks all --quiet 2> /dev/null; then
            elif [ "$(date -d ${last_task_run_started_time} +%s)" -lt "$(date -d ${last_task_run_resolved_time} +%s)" ] && [[ "${running_instance_deployment_id}" != "${deploymentId}" ]]; then
              # reaching here indicates the instance has been waiting for work to do however the occ repo has changed since this instance was deployed, so we've killed it
              _echo "${workerType} expired instance deleted: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp} from expired sha: ${running_instance_deployment_id}). resolved ${last_task_run_created_reason} task: _bold_${last_task_id}/${last_task_run_id}_reset_ with status: ${last_task_run_resolved_reason}, ${wait_time} ago (at ${last_task_run_resolved_time})"
            else
              # reaching here indicates another provisioner has beaten us to killing this instance or the instance has been waiting for work for less than ${idle_termination_interval} minutes and can be left to continue waiting for work
              _echo "${workerType} waiting instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp}). resolved ${last_task_run_created_reason} task: _bold_${last_task_id}/${last_task_run_id}_reset_ with status: ${last_task_run_resolved_reason}, ${wait_time} ago (at ${last_task_run_resolved_time})"
            fi
            (( waiting_instance_count = waiting_instance_count + 1 ))
          elif [[ "${last_task_run_state}" == "running" ]]; then
            work_time_minutes=$(( ($(date +%s) - $(date -d ${last_task_run_started_time} +%s)) / 60))
            if [ "${work_time_minutes}" -gt "60" ]; then
              work_time="$((${work_time_minutes} / 60)) hours, $((${work_time_minutes} % 60)) minutes"
            else
              work_time="${work_time_minutes} minutes"
            fi
            _echo "${workerType} working instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp}). running ${last_task_run_created_reason} task: _bold_${last_task_id}/${last_task_run_id}_reset_, for ${work_time} (since ${last_task_run_started_time})"
            (( working_instance_count = working_instance_count + 1 ))
          elif [ -n "${first_claim}" ] && date -d ${first_claim} +%s &> /dev/null; then
            wait_time_minutes=$(( ($(date +%s) - $(date -d ${first_claim} +%s)) / 60))
            if [ "${wait_time_minutes}" -gt "60" ]; then
              wait_time="$((${wait_time_minutes} / 60)) hours, $((${wait_time_minutes} % 60)) minutes"
            else
              wait_time="${wait_time_minutes} minutes"
            fi
            #if [ "${wait_time_minutes}" -gt "${idle_termination_interval}" ] && gcloud compute instances delete ${running_instance_name} --zone ${running_instance_zone} --delete-disks all --quiet 2> /dev/null; then
            if [ "${wait_time_minutes}" -gt "${idle_termination_interval}" ]; then
              # reaching here indicates the instance has been waiting for work to do for more than ${idle_termination_interval} minutes, without ever taking a task, so we've killed it
              _echo "${workerType} waiting instance deleted: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp}). first claim ${wait_time} ago (at ${first_claim})"
            else
              _echo "${workerType} waiting instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp}). first claim ${wait_time} ago (at ${first_claim})"
              (( waiting_instance_count = waiting_instance_count + 1 ))
            fi
          elif [[ "$(jq -r '.code' ${temp_dir}/queue-${worker_id}.json)" == "ResourceNotFound" ]]; then
            _echo "${workerType} goofing instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp}). worker: not registered with queue."
            (( goofing_instance_count = goofing_instance_count + 1 ))
          else
            _echo "${workerType} goofing instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp}). worker: $(jq -c '.' ${temp_dir}/queue-${worker_id}.json); task run: $(jq -c --arg runId ${last_task_run_id} -r '.status.runs[]? | select(.runId == ($runId | tonumber))' ${temp_dir}/${last_task_id}.json)"
            (( goofing_instance_count = goofing_instance_count + 1 ))
          fi
        elif [ "${running_instance_uptime_minutes}" -lt "30" ]; then
          # reaching here indicates the instance is not known to the queue (no first claim registered), however the instance has been running for less than 30 minutes
          _echo "${workerType} pending instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp})"
          (( pending_instance_count = pending_instance_count + 1 ))
        elif [[ "${workerImplementation}" == "generic-worker" ]]; then
          # reaching here indicates the instance is not known to the queue (no first claim registered), however the instance has been running for more than 30 minutes and can be considered defective. our delete attempt failed probably due to another provisioner making a successful delete earlier
          _echo "${workerType} zombied instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp})"
          (( zombied_instance_count = zombied_instance_count + 1 ))
        elif [[ "${workerImplementation}" == "docker-worker" ]]; then
          # reaching here indicates the instance is a docker-worker and we haven't mapped it's worker id to its hostname
          _echo "${workerType} docker instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp})"
        else
          # reaching here indicates the instance is not known to the queue (no first claim registered), however the instance has been running for more than 30 minutes and can be considered defective. our delete attempt failed probably due to another provisioner making a successful delete earlier
          _echo "${workerType} zombied instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: _bold_${running_instance_uptime}_reset_ (created: ${running_instance_creation_timestamp})"
          (( zombied_instance_count = zombied_instance_count + 1 ))
        fi
      else
        # reaching here indicates the instance has already been deleted (probably by another provisioner) because the describe instance query has failed
        _echo "${workerType} deleted instance observed: _bold_${running_instance_name}_reset_ (${worker_id}) in _bold_${running_instance_region}_reset_ with uptime: unknown"
        (( deleted_instance_count = deleted_instance_count + 1 ))
      fi
    done
    _echo "${workerType} ${running_instance_region} observation complete"
  done

  if [ "${waiting_instance_count}" -gt "0" ]; then
    (( running_instance_count = running_instance_count + waiting_instance_count ))
    _echo "${workerType} waiting instances: _bold_${waiting_instance_count}_reset_"
  fi
  if [ "${working_instance_count}" -gt "0" ]; then
    (( running_instance_count = running_instance_count + working_instance_count ))
    _echo "${workerType} working instances: _bold_${working_instance_count}_reset_"
  fi
  if [ "${pending_instance_count}" -gt "0" ]; then
    (( running_instance_count = running_instance_count + pending_instance_count ))
    _echo "${workerType} pending instances: _bold_${pending_instance_count}_reset_"
  fi
  if [ "${zombied_instance_count}" -gt "0" ]; then
    (( running_instance_count = running_instance_count + zombied_instance_count ))
    _echo "${workerType} zombied instances: _bold_${zombied_instance_count}_reset_"
  fi
  if [ "${goofing_instance_count}" -gt "0" ]; then
    (( running_instance_count = running_instance_count + goofing_instance_count ))
    _echo "${workerType} goofing instances: _bold_${goofing_instance_count}_reset_"
  fi
  if [ "${deleted_instance_count}" -gt "0" ]; then
    (( running_instance_count = running_instance_count + deleted_instance_count ))
    _echo "${workerType} deleted instances: _bold_${deleted_instance_count}_reset_"
  fi
  _echo "${workerType} observation complete"

  _echo "${workerType} running instances: _bold_${running_instance_count}_reset_"

  # determine the pending task count specific to the worker type
  pending_task_count=$(curl -s "https://queue.taskcluster.net/v1/pending/${provisionerId}/${workerType}" | jq '.pendingTasks')
  _echo "${workerType} pending tasks: _bold_${pending_task_count}_reset_"

  # spawn enough instances to deal with the pending task count, taking into account:
  # - the number of instances already spawned and in the pending state
  # - the configured minimum capacity for the worker type
  # - the configured maximum capacity for the worker type
  required_instance_count=0
  if [ "${pending_instance_count}" -lt "${pending_task_count}" ]; then
    (( required_instance_count = pending_task_count - pending_instance_count ))
  fi
  _echo "${workerType} required instances: _bold_${required_instance_count}_reset_"

done

rm -rf ${temp_dir}