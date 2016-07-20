#!/bin/bash -e

# get some secrets from tc
updateworkertype_secrets_url="taskcluster/secrets/v1/secret/repo:github.com/mozilla-releng/OpenCloudConfig:updateworkertype"
read TASKCLUSTER_AWS_ACCESS_KEY TASKCLUSTER_AWS_SECRET_KEY aws_tc_account_id userdata<<EOF
$(curl -s -N ${updateworkertype_secrets_url} | python -c 'import json, sys; a = json.load(sys.stdin)["secret"]; print a["TASKCLUSTER_AWS_ACCESS_KEY"], a["TASKCLUSTER_AWS_SECRET_KEY"], a["aws_tc_account_id"], ("%s" % a["userdata"].replace("\n", "\\\\n"));' 2> /dev/null)
EOF

: ${TASKCLUSTER_AWS_ACCESS_KEY:?"TASKCLUSTER_AWS_ACCESS_KEY is not set"}
: ${TASKCLUSTER_AWS_SECRET_KEY:?"TASKCLUSTER_AWS_SECRET_KEY is not set"}
export AWS_ACCESS_KEY_ID=${TASKCLUSTER_AWS_ACCESS_KEY}
export AWS_SECRET_ACCESS_KEY=${TASKCLUSTER_AWS_SECRET_KEY}

: ${aws_tc_account_id:?"aws_tc_account_id is not set"}

aws_region=${aws_region:='us-west-2'}
aws_copy_regions[0]='us-east-1'
aws_copy_regions[1]='us-west-1'
aws_regions[0]=${aws_region}
aws_regions[1]=${aws_copy_regions[0]}
aws_regions[2]=${aws_copy_regions[1]}

if [ "${#}" -lt 1 ]; then
  echo "workertype argument missing; usage: ./update-workertype.sh workertype" >&2
  exit 64
fi
tc_worker_type="${1}"

aws_key_name="mozilla-taskcluster-worker-${tc_worker_type}"
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] aws_key_name: ${aws_key_name}"

aws_client_token=${GITHUB_HEAD_SHA:0:12}
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] git sha: ${aws_client_token} used for aws client token"

case "${tc_worker_type}" in
  *-win7-32)
    aws_base_ami_search_term=${aws_base_ami_search_term:='win7-base'}
    aws_instance_type=${aws_instance_type:='c3.2xlarge'}
    aws_instance_hdd_size=${aws_instance_hdd_size:=120}
    aws_base_ami_id="$(aws ec2 describe-images --region ${aws_region} --owners self --filters "Name=state,Values=available" "Name=name,Values=${aws_base_ami_search_term}" --query 'Images[*].{A:CreationDate,B:ImageId}' --output text | sort -u | tail -1 | cut -f2)"
    ami_description="Gecko try tester for Windows 7 32 bit; TaskCluster worker: ${tc_worker_type}, version ${aws_client_token}, https://github.com/mozilla-releng/OpenCloudConfig/tree/${GITHUB_HEAD_SHA}"}
    ;;
  *-win2012)
    aws_base_ami_search_term=${aws_base_ami_search_term:='Windows_Server-2012-R2_RTM-English-64Bit-Base*'}
    aws_instance_type=${aws_instance_type:='c3.2xlarge'}
    aws_instance_hdd_size=${aws_instance_hdd_size:=60}
    aws_base_ami_id="$(aws ec2 describe-images --region ${aws_region} --owners amazon --filters "Name=platform,Values=windows" "Name=state,Values=available" "Name=name,Values=${aws_base_ami_search_term}" --query 'Images[*].{A:CreationDate,B:ImageId}' --output text | sort -u | tail -1 | cut -f2)"
    ami_description="Gecko try builder for Windows; TaskCluster worker: ${tc_worker_type}, version ${aws_client_token}, https://github.com/mozilla-releng/OpenCloudConfig/tree/${GITHUB_HEAD_SHA}"}
    ;;
  *)
    echo "ERROR: unknown worker type: '${tc_worker_type}'"
    exit 67
    ;;
esac
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] latest base ami for: ${aws_base_ami_search_term}, in region: ${aws_region}, is: ${aws_base_ami_id}"

# create instance, apply user-data, filter output, get instance id, tag instance, wait for shutdown
aws_instance_id="$(aws ec2 run-instances --region ${aws_region} --image-id "${aws_base_ami_id}" --key-name ${aws_key_name} --security-groups "ssh-only" "rdp-only" --user-data "$(echo -e ${userdata})" --instance-type ${aws_instance_type} --block-device-mappings DeviceName=/dev/sda1,Ebs="{VolumeSize=$aws_instance_hdd_size,DeleteOnTermination=true,VolumeType=gp2}" --instance-initiated-shutdown-behavior stop --client-token "${tc_worker_type}-${aws_client_token}" | sed -n 's/^ *"InstanceId": "\(.*\)", */\1/p')"
aws ec2 create-tags --region ${aws_region} --resources "${aws_instance_id}" --tags "Key=WorkerType,Value=${tc_worker_type}"
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] instance: ${aws_instance_id} instantiated and tagged: WorkerType=${tc_worker_type} (https://${aws_region}.console.aws.amazon.com/ec2/v2/home?region=${aws_region}#Instances:instanceId=${aws_instance_id})"
sleep 30 # give aws 30 seconds to start the instance
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] userdata logging to: https://papertrailapp.com/systems/${aws_instance_id}/events"
aws_instance_public_ip="$(aws ec2 describe-instances --region ${aws_region} --instance-id "${aws_instance_id}" --query 'Reservations[*].Instances[*].NetworkInterfaces[*].Association.PublicIp' --output text)"
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] instance public ip: ${aws_instance_public_ip}"

# poll for a stopped state
until `aws ec2 wait instance-stopped --region ${aws_region} --instance-ids "${aws_instance_id}" >/dev/null 2>&1`;
do
  echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] waiting for instance to shut down"
done

# create ami, get ami id, tag ami, wait for ami availability
aws_ami_id=`aws ec2 create-image --region ${aws_region} --instance-id ${aws_instance_id} --name "${tc_worker_type} version ${aws_client_token}" --description "${ami_description}" | sed -n 's/^ *"ImageId": *"\(.*\)" *$/\1/p'`
echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] ami: ${aws_ami_id} creation in progress: https://${aws_region}.console.aws.amazon.com/ec2/v2/home?region=${aws_region}#Images:visibility=owned-by-me;search=${aws_ami_id}"
aws ec2 create-tags --region ${aws_region} --resources "${aws_ami_id}" --tags "Key=WorkerType,Value=${tc_worker_type}"
sleep 30
until `aws ec2 wait image-available --region ${aws_region} --image-ids "${aws_ami_id}" >/dev/null 2>&1`;
do
  echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] waiting for ami availability (${aws_region} ${aws_ami_id})"
done
touch ${aws_region}.${aws_ami_id}.latest-ami
curl http://taskcluster/aws-provisioner/v1/worker-type/${tc_worker_type} | jq -c 'del(.workerType, .lastModified) | (.regions[] | select(.region == "${aws_region}") | .launchSpec.ImageId) = "${aws_ami_id}"' | curl --silent --header 'Content-Type: application/json' --request POST --data @- http://taskcluster/aws-provisioner/v1/worker-type/${tc_worker_type}/update > /dev/null 2>&1

# copy ami to each configured region, get copied ami id, tag copied ami, wait for copied ami availability
for region in "${aws_copy_regions[@]}"; do
  aws_copied_ami_id=`aws ec2 copy-image --region ${region} --source-region ${aws_region} --source-image-id ${aws_ami_id} --name "${tc_worker_type} version ${aws_client_token}" --description "${ami_description}" | sed -n 's/^ *"ImageId": *"\(.*\)" *$/\1/p'`
  echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] ami: ${aws_region} ${aws_ami_id} copy to ${region} ${aws_copied_ami_id} in progress: https://${region}.console.aws.amazon.com/ec2/v2/home?region=${region}#Images:visibility=owned-by-me;search=${aws_copied_ami_id}"
  aws ec2 create-tags --region ${region} --resources "${aws_copied_ami_id}" --tags "Key=WorkerType,Value=${tc_worker_type}"
  sleep 30
  until `aws ec2 wait image-available --region ${region} --image-ids "${aws_copied_ami_id}" >/dev/null 2>&1`;
  do
    echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] waiting for ami availability (${region} ${aws_copied_ami_id})"
  done
  touch ${region}.${aws_copied_ami_id}.latest-ami
  curl http://taskcluster/aws-provisioner/v1/worker-type/${tc_worker_type} | jq -c 'del(.workerType, .lastModified) | (.regions[] | select(.region == "${region}") | .launchSpec.ImageId) = "${aws_copied_ami_id}"' | curl --silent --header 'Content-Type: application/json' --request POST --data @- http://taskcluster/aws-provisioner/v1/worker-type/${tc_worker_type}/update > /dev/null 2>&1
done

echo "[opencloudconfig $(date --utc +"%F %T.%3NZ")] worker type updated: https://tools.taskcluster.net/aws-provisioner/#${tc_worker_type}/view"
