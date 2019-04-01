#!/bin/bash

apt-get install -y git jq
git clone https://github.com/mozilla-releng/OpenCloudConfig.git
cd OpenCloudConfig
git checkout gamma
while true; do
  git pull > /dev/null
  ci/gcloud-init.sh
  sleep 60
done