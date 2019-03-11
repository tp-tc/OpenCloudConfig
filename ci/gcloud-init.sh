#!/bin/bash -e

uuid=$(uuidgen)
# gecko-1-b-win2012-gamma
gcloud compute instances create i-${uuid} --image-project windows-cloud --image-family windows-2012-r2-core --machine-type n1-standard-8 --boot-disk-size 120 --boot-disk-type pd-ssd
gcloud beta compute disks create d-${uuid} --size 120 --type pd-ssd --physical-block-size 4096
gcloud compute instances attach-disk i-${uuid} --disk d-${uuid}
gcloud compute instances add-metadata i-${uuid} --metadata workerType=gecko-1-b-win2012-gamma,sourceOrg=mozilla-releng,sourceRepo=OpenCloudConfig,sourceRevision=gamma

#gcloud compute reset-windows-password i-${uuid} --user Administrator
#gcloud compute instances add-metadata gecko-1-b-win2012-gamma --metadata workerType=gecko-1-b-win2012-gamma,sourceOrg=mozilla-releng,sourceRepo=OpenCloudConfig,sourceRevision=gamma
