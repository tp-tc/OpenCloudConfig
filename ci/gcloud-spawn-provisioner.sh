#!/bin/bash -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
script_name=$(basename ${0##*/} .sh)

gsutil cp ${script_dir}/gcloud-init-provisioner.sh gs://open-cloud-config/

provisioner_instance_name=releng-gcp-provisioner
provisioner_instance_zone=us-east1-b

gcloud compute instances create ${provisioner_instance_name} \
  --zone ${provisioner_instance_zone} \
  --machine-type f1-micro \
  --scopes storage-ro \
  --metadata "^;^startup-script-url=gs://open-cloud-config/gcloud-init-provisioner.sh;"

livelogSecret=`pass Mozilla/TaskCluster/livelogSecret`
livelogcrt=`pass Mozilla/TaskCluster/livelogCert`
livelogkey=`pass Mozilla/TaskCluster/livelogKey`
pgpKey=`pass Mozilla/OpenCloudConfig/rootGpgKey`
relengapiToken=`pass Mozilla/OpenCloudConfig/tooltool-relengapi-tok`
occInstallersToken=`pass Mozilla/OpenCloudConfig/tooltool-occ-installers-tok`
gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^livelogSecret=${livelogSecret}"
gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^livelogcrt=${livelogcrt}"
gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^livelogkey=${livelogkey}"
gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^pgpKey=${pgpKey}"
gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^relengapiToken=${relengapiToken}"
gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^occInstallersToken=${occInstallersToken}"
for manifest in $(ls $HOME/git/mozilla-releng/OpenCloudConfig/userdata/Manifest/*-gamma.json); do
  workerType=$(basename ${manifest##*/} .json)
  accessToken=`pass Mozilla/TaskCluster/project/releng/generic-worker/${workerType}/production`
  gcloud compute instances add-metadata ${provisioner_instance_name} --zone ${provisioner_instance_zone} --metadata "^;^access-token-${workerType}=${accessToken}"
done
