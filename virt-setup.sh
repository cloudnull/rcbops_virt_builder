#!/usr/bin/env bash

# Copyright 2013, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author Kevin.Carter@Rackspace.com 

# Set Exit on error
set -e

# make sure variables are set
set -u

# Make things verbose
set -v

# Setup the box for AIO use
# ==========================================================================
function run_aio_script() {
  # Make the scripts directory
  if [ ! -d "/opt/aio-script" ];then
    mkdir -p /opt/aio-script
  fi

  # Get and Run the Install Script
  git clone ${GITHUB_URL}/rcbops_allinone_inone /opt/aio-script

  # Enter the Directory
  pushd /opt/aio-script

  # Source our Options
  source master_dev.rc
  chmod +x rcbops_allinone_inone.sh && ./rcbops_allinone_inone.sh

  # Leave the Directory
  popd
}

# Get and setup the virt tools
# ==========================================================================
function virt_tools_setup() {
# Make the scripts directory
if [ ! -d "/opt/vm-rebuilder" ];then
  mkdir -p /opt/vm-rebuilder
fi

# Get the VM-Rebuilder Tools
git clone $GITHUB_URL/rcbops_virt_builder /opt/vm-rebuilder

# Enter the Directory
pushd /opt/vm-rebuilder

chmod +x rebuild-env.sh
chmod +x env-rebuilder.py

# Leave the Directory
popd


# Make the symlink
ln -f -s /opt/vm-rebuilder/rebuild-env.sh /etc/init.d/rebuild-env
  
# Setup the init script
if [ "${SYSTEM}" == "RHEL" ];then
  chkconfig rebuild-env on
elif [ "${SYSTEM}" == "DEB" ];then
  update-rc.d rebuild-env defaults 10
fi
}

# OS Check
# ==========================================================================
if [ "$(grep -i -e redhat -e centos /etc/redhat-release)"  ]; then
  yum -y install curl git
  SYSTEM="RHEL"
elif [ "$(grep -i ubuntu /etc/lsb-release)" ];then
  apt-get update && apt-get install -y curl git
  SYSTEM="DEB"
else
  echo "OS Check has Failed."
  exit 1
fi

# Set git URL
GITHUB_URL="https://github.com/cloudnull"

# Get and Run the AIO Script
run_aio_script

# Get and Setup the Virt Tools
virt_tools_setup

exit 0
