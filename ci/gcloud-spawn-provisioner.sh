#!/bin/bash -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
script_name=$(basename ${0##*/} .sh)

# script config
project_name=windows-workers
provisioner_instance_name_prefix=releng-gcp-provisioner
provisioner_instance_zone=us-east1-b
provisioner_instance_machine_type=f1-micro

# create a service account for the provisioners if it doesn't exist
service_account_name=releng-gcp-provisioner
if [[ "$(gcloud iam service-accounts list --filter name:${service_account_name} --format json)" == "[]" ]]; then
  gcloud iam service-accounts create ${service_account_name} --display-name "releng gcp provisioner"
  _echo "created service account: _bold_${service_account_name}_reset_"
  # grant role allowing assignment of service accounts to provisioned instances
  gcloud projects add-iam-policy-binding ${project_name} --member serviceAccount:${service_account_name}@${project_name}.iam.gserviceaccount.com --role roles/iam.serviceAccountUser
fi

# generate a new provisioner instance name which does not pre-exist
existing_provisioner_instance_uri_list=(`gcloud compute instances list --uri`)
existing_provisioner_instance_name_list=("${existing_provisioner_instance_uri_list[@]##*/}")
provisioner_instance_number=0
provisioner_instance_name=${provisioner_instance_name_prefix}-${provisioner_instance_number}
while [[ " ${existing_provisioner_instance_name_list[@]} " =~ " ${provisioner_instance_name} " ]]; do
  (( provisioner_instance_number = provisioner_instance_number + 1 ))
  provisioner_instance_name=${provisioner_instance_name_prefix}-${provisioner_instance_number}
done

# provisioning secrets
livelogSecret=`pass Mozilla/TaskCluster/livelogSecret`
livelogcrt=`pass Mozilla/TaskCluster/livelogCert`
livelogkey=`pass Mozilla/TaskCluster/livelogKey`
pgpKey=`pass Mozilla/OpenCloudConfig/rootGpgKey`
relengapiToken=`pass Mozilla/OpenCloudConfig/tooltool-relengapi-tok`
occInstallersToken=`pass Mozilla/OpenCloudConfig/tooltool-occ-installers-tok`

# update the provisioner startup script (copy from repo to gs bucket)
gsutil cp ${script_dir}/gcloud-init-provisioner.sh gs://open-cloud-config/
echo "$(tput dim)[${script_name} $(date --utc +"%F %T.%3NZ")]$(tput sgr0) provisioner startup script updated in bucket$(tput sgr0)"

# spawn a provisioner with startup script and secrets in metadata
gcloud compute instances create ${provisioner_instance_name} \
  --zone ${provisioner_instance_zone} \
  --machine-type ${provisioner_instance_machine_type} \
  --scopes compute-rw,service-management,storage-rw \
  --service-account ${service_account_name} \
  --metadata "^;^startup-script-url=gs://open-cloud-config/gcloud-init-provisioner.sh;livelogSecret=${livelogSecret};livelogcrt=${livelogcrt};livelogkey=${livelogkey};pgpKey=${pgpKey};relengapiToken=${relengapiToken};occInstallersToken=${occInstallersToken}"
echo "$(tput dim)[${script_name} $(date --utc +"%F %T.%3NZ")]$(tput sgr0) provisioner: ${provisioner_instance_name} created as ${provisioner_instance_machine_type} in ${provisioner_instance_zone}$(tput sgr0)"

# add worker-type specific access tokens to secrets metadata
for manifest in $(ls $HOME/git/mozilla-releng/OpenCloudConfig/userdata/Manifest/*-gamma.json); do
  workerType=$(basename ${manifest##*/} .json)
  accessToken=`pass Mozilla/TaskCluster/project/releng/generic-worker/${workerType}/production`
  gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^access-token-${workerType}=${accessToken}"
  echo "$(tput dim)[${script_name} $(date --utc +"%F %T.%3NZ")]$(tput sgr0) access-token-${workerType} added to metadata$(tput sgr0)"
done
