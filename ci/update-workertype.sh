#!/bin/bash -e

# get some secrets from tc
updateworkertype_secrets_url="taskcluster/secrets/v1/secret/repo:github.com/mozilla-releng/OpenCloudConfig:updateworkertype"
read TASKCLUSTER_AWS_ACCESS_KEY TASKCLUSTER_AWS_SECRET_KEY TASKCLUSTER_CLIENT_ID TASKCLUSTER_ACCESS_TOKEN aws_tc_account_id userdata<<EOF
$(curl -s -N ${updateworkertype_secrets_url} | python -c 'import json, sys; a = json.load(sys.stdin)["secret"]; print a["TASKCLUSTER_AWS_ACCESS_KEY"], a["TASKCLUSTER_AWS_SECRET_KEY"], a["TASKCLUSTER_CLIENT_ID"], a["TASKCLUSTER_ACCESS_TOKEN"], a["aws_tc_account_id"], ("%s" % a["userdata"].replace("\n", "\\\\n"));' 2> /dev/null)
EOF

: ${TASKCLUSTER_AWS_ACCESS_KEY:?"TASKCLUSTER_AWS_ACCESS_KEY is not set"}
: ${TASKCLUSTER_AWS_SECRET_KEY:?"TASKCLUSTER_AWS_SECRET_KEY is not set"}
export AWS_ACCESS_KEY_ID=${TASKCLUSTER_AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${TASKCLUSTER_AWS_SECRET_KEY}

: ${TASKCLUSTER_CLIENT_ID:?"TASKCLUSTER_CLIENT_ID is not set"}
: ${TASKCLUSTER_ACCESS_TOKEN:?"TASKCLUSTER_ACCESS_TOKEN is not set"}
: ${aws_tc_account_id:?"aws_tc_account_id is not set"}

aws_region=${aws_region:='us-west-2'}
aws_copy_regions[0]='us-east-1'
aws_copy_regions[1]='us-west-1'
aws_regions[0]=${aws_region}
aws_regions[1]=${aws_copy_regions[0]}
aws_regions[2]=${aws_copy_regions[1]}

aws_instance_type=${aws_instance_type:='c3.2xlarge'}
aws_base_ami_search_term_win2012=${aws_base_ami_search_term_win2012:='Windows_Server-2012-R2_RTM-English-64Bit-Base*'}

if [ "${#}" -lt 1 ]; then
  echo "workertype argument missing; usage: ./update-workertype.sh workertype" >&2
  exit 64
fi
tc_worker_type="${1}"

aws_key_name="mozilla-taskcluster-worker-${tc_worker_type}"
echo "$(date -Iseconds): aws_key_name: ${aws_key_name}"

aws_client_token=${GITHUB_HEAD_SHA:0:12}
echo "$(date -Iseconds): git sha: ${aws_client_token} used for aws client token"

case "${tc_worker_type}" in
  win2012*)
    aws_instance_hdd_size=${aws_instance_hdd_size:=60}
    aws_base_ami_id="$(aws ec2 describe-images --region ${aws_region} --owners amazon --filters "Name=platform,Values=windows" "Name=state,Values=available" "Name=name,Values=${aws_base_ami_search_term_win2012}" --query 'Images[*].{A:CreationDate,B:ImageId}' --output text | sort -u | tail -1 | cut -f2)"
    echo "$(date -Iseconds): latest base ami for: ${aws_base_ami_search_term_win2012}, in: ${aws_region}, is: ${aws_base_ami_id}"
    ;;
  *)
    echo "ERROR: unknown worker type: '${tc_worker_type}'"
    exit 67
    ;;
esac

declare -A aws_previous_instance_ids
declare -A aws_previous_snapshot_id
declare -A aws_previous_ami_id

for region in "${aws_regions[@]}"; do

  # previous instances
  aws_previous_instance_ids[${region}]="$(aws ec2 describe-instances --region ${region} --filters Name=tag-key,Values=WorkerType "Name=tag-value,Values=${tc_worker_type}" --query 'Reservations[*].Instances[*].InstanceId' --output text)"
  if [ -n "${aws_previous_instance_ids[${region}]}" ]; then
    echo "$(date -Iseconds): previous instances of WorkerType: ${tc_worker_type}, in region: ${region}, include: ${aws_previous_instance_ids[${region}]}, in region: ${region}"
  else
    echo "$(date -Iseconds): no previous instances of WorkerType: ${tc_worker_type}, in region: ${region}"
  fi

  # previous snapshot
  aws_previous_snapshot_id[${region}]="$(aws ec2 describe-images --region ${region} --owners self --filters "Name=name,Values=${tc_worker_type} version*" --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId' --output text)"
  if [ -n "${aws_previous_snapshot_id[${region}]}" ]; then
    echo "$(date -Iseconds): previous snapshot: ${aws_previous_snapshot_id[${region}]}, in region: ${region}"
  else
    echo "$(date -Iseconds): no previous snapshot in region: ${region}"
  fi

  # previous ami
  aws_previous_ami_id[${region}]="$(aws ec2 describe-images --region ${region} --owners self --filters "Name=name,Values=${tc_worker_type} version*" --query 'Images[*].ImageId' --output text)"
  if [ -n "${aws_previous_ami_id[${region}]}" ]; then
    echo "$(date -Iseconds): previous ami: ${aws_previous_ami_id[${region}]}, in region: ${region}"
  else
    echo "$(date -Iseconds): no previous ami in region: ${region}"
  fi

done

# create instance, apply user-data, filter output, get instance id, tag instance, wait for shutdown
aws_instance_id="$(aws ec2 run-instances --region ${aws_region} --image-id "${aws_base_ami_id}" --key-name ${aws_key_name} --security-groups "ssh-only" "rdp-only" --user-data "$(echo -e ${userdata})" --instance-type ${aws_instance_type} --block-device-mappings DeviceName=/dev/sda1,Ebs="{VolumeSize=$aws_instance_hdd_size,DeleteOnTermination=true,VolumeType=gp2}" --instance-initiated-shutdown-behavior stop --client-token "${aws_client_token}" | sed -n 's/^ *"InstanceId": "\(.*\)", */\1/p')"
aws ec2 create-tags --region ${aws_region} --resources "${aws_instance_id}" --tags "Key=WorkerType,Value=${tc_worker_type}"
echo "$(date -Iseconds): instance: ${aws_instance_id} instantiated and tagged: WorkerType=${tc_worker_type}"
sleep 30 # give aws 30 seconds to start the instance
echo "$(date -Iseconds): userdata logging to: https://papertrailapp.com/systems/${aws_instance_id}/events"
aws_instance_public_ip="$(aws ec2 describe-instances --region ${aws_region} --instance-id "${aws_instance_id}" --query 'Reservations[*].Instances[*].NetworkInterfaces[*].Association.PublicIp' --output text)"
echo "$(date -Iseconds): instance public ip: ${aws_instance_public_ip}"

# poll for a stopped state
until `aws ec2 wait instance-stopped --region ${aws_region} --instance-ids "${aws_instance_id}" >/dev/null 2>&1`;
do
  echo "$(date -Iseconds): waiting for instance to shut down"
done

aws_ami_id=`aws ec2 create-image --region ${aws_region} --instance-id ${aws_instance_id} --name "${tc_worker_type} version ${aws_client_token}" --description "Firefox desktop builds for Windows - TaskCluster ${tc_worker_type} worker - version ${aws_client_token}" | sed -n 's/^ *"ImageId": *"\(.*\)" *$/\1/p'`
echo "$(date -Iseconds): ami: ${aws_ami_id} creation in progress: https://${aws_region}.console.aws.amazon.com/ec2/v2/home?region=${aws_region}#Images:visibility=owned-by-me;search=${aws_ami_id};sort=desc:creationDate"
aws ec2 create-tags --region ${aws_region} --resources "${aws_ami_id}" --tags "Key=WorkerType,Value=${tc_worker_type}"
sleep 30
until `aws ec2 wait image-available --region ${aws_region} --image-ids "${aws_ami_id}" >/dev/null 2>&1`;
do
  echo "$(date -Iseconds): waiting for ami availability (${aws_region} ${aws_ami_id})"
done
touch ${aws_region}.${aws_ami_id}.latest-ami

for region in "${aws_copy_regions[@]}"; do
  aws_copied_ami_id=`aws ec2 copy-image --region ${region} --source-region ${aws_region} --source-image-id ${aws_ami_id} --name "${tc_worker_type} version ${aws_client_token}" --description "Firefox desktop builds for Windows - TaskCluster ${tc_worker_type} worker - version ${aws_client_token}" | sed -n 's/^ *"ImageId": *"\(.*\)" *$/\1/p'`
  echo "$(date -Iseconds): ami: ${aws_region} ${aws_ami_id} copy to ${region} ${aws_copied_ami_id} in progress: https://${region}.console.aws.amazon.com/ec2/v2/home?region=${region}#Images:visibility=owned-by-me;search=${aws_copied_ami_id};sort=desc:creationDate"
  aws ec2 create-tags --region ${region} --resources "${aws_copied_ami_id}" --tags "Key=WorkerType,Value=${tc_worker_type}"
  sleep 30
  until `aws ec2 wait image-available --region ${region} --image-ids "${aws_copied_ami_id}" >/dev/null 2>&1`;
  do
    echo "$(date -Iseconds): waiting for ami availability (${region} ${aws_copied_ami_id})"
  done
  touch ${region}.${aws_copied_ami_id}.latest-ami
done

echo "$(date -Iseconds): worker type update required: https://tools.taskcluster.net/aws-provisioner/#${tc_worker_type}/edit"
