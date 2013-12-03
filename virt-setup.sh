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

# Setup Banner
function setup_banner() {
  ln -f -s /etc/motd /etc/issue
  cp /etc/motd /etc/motd.old
}

# Setup the box for AIO use
function setup_bootspash() {
  if [ -f "/lib/plymouth/themes/ubuntu-text/ubuntu-text.plymouth" ];then
    cat > /lib/plymouth/themes/ubuntu-text/ubuntu-text.plymouth <<EOF
[Plymouth Theme]
Name=Ubuntu Text
Description=Text mode theme based on ubuntu-logo theme
ModuleName=ubuntu-text

[ubuntu-text]
title=Rackspace Private Cloud, [ESC] for progress
black=0x000000
white=0xffffff
brown=0xff4012
blue=0x988592
EOF

    update-initramfs -u
  fi
}

# Setup the box for AIO use
function setup_grub() {
  if [ -f "/etc/default/grub" ];then
    cat > /etc/default/grub <<EOF
GRUB_DEFAULT=0
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_TIMEOUT=2
GRUB_DISTRIBUTOR="Rackspace Private Cloud"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_RECORDFAIL_TIMEOUT=1
EOF

    update-grub
  fi
}


# Special Device setup
function special_device() {
  TEMPINT="/tmp/interfaces"
  sed '/^#### SPECIAL/,/^#### SPECIAL/d' /etc/network/interfaces > ${TEMPINT}
  mv /tmp/interfaces /etc/network/interfaces

  cat >> /etc/network/interfaces <<EOF
#### SPECIAL
# This is a special interface / device, DO NOT REMOVE or MODIFY
auto eth2
iface eth2 inet static
    address 172.151.151.151
    netmask 255.255.255.0
#### SPECIAL
EOF
}


# Blacklist SMBus Controller for VM
function blacklist_modules() {
  # This is a VM blacklist
  echo 'blacklist i2c_piix4' | tee -a /etc/modprobe.d/blacklist.conf
  update-initramfs -u -k all
}

# Setup the box for AIO use
function run_aio_script() {
  # Make the scripts directory
  if [ -d "/opt/aio-script" ];then
    rm -rf /opt/aio-script
  fi

  # Make the AIO script directory
  mkdir -p /opt/aio-script

  # Get and Run the Install Script
  git clone ${GITHUB_URL}/rcbops_allinone_inone /opt/aio-script

  # Enter the Directory
  pushd /opt/aio-script

  # Source our Options
  if [ "${USE_NEUTRON}" == "True" ];then
    source /opt/vm-rebuilder/neutron.rc
  else
    source /opt/vm-rebuilder/nova_network.rc
  fi

  # Disable all images
  export CIRROS_IMAGE=False
  export UBUNTU_IMAGE=False
  export FEDORA_IMAGE=False

  chmod +x rcbops_allinone_inone.sh && ./rcbops_allinone_inone.sh

  # Leave the Directory
  popd
}

# Get and setup the virt tools
function virt_tools_setup() {
  REBUILDER_DIR="/opt/vm-rebuilder"

  # Make the scripts directory
  if [ ! -d "${REBUILDER_DIR}" ];then
    mkdir -p ${REBUILDER_DIR}

    # Get the VM-Rebuilder Tools
    git clone $GITHUB_URL/rcbops_virt_builder ${REBUILDER_DIR}
  else
    if [ ! -d "${REBUILDER_DIR}/.git" ];then
      rm -rf ${REBUILDER_DIR}
      git clone $GITHUB_URL/rcbops_virt_builder ${REBUILDER_DIR}
    fi
  fi

  # Enter the Directory
  pushd ${REBUILDER_DIR}

  git pull origin master
  chmod +x *.sh
  chmod +x *.py

  if [ -f "/opt/allinoneinone/chef-cookbooks/allinoneinone.json" ];then
    if [ -f "/opt/vm-rebuilder/base.json" ];then
      rm /opt/vm-rebuilder/base.json
    fi
    # Move the the aio JSON to the base
    BASE_LOCATION="/opt/allinoneinone/chef-cookbooks"
    cp ${BASE_LOCATION}/allinoneinone.json /opt/vm-rebuilder/base.json
  fi

  # Leave the Directory
  popd


  # Make the symlink
  ln -f -s /opt/vm-rebuilder/rebuild-env.sh /etc/init.d/rebuild-env

  # Setup the init script
  if [ "${SYSTEM}" == "RHEL" ];then
    chkconfig rebuild-env on
  elif [ "${SYSTEM}" == "DEB" ];then
    update-rc.d rebuild-env defaults 25
  fi
}

# OS Check
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
GITHUB_URL=${GITHUB_URL:-"https://github.com/cloudnull"}

# Set if you want to use Neutron; True||False. Default is False.
USE_NEUTRON=${USE_NEUTRON:-"False"}

# Setup our special device
special_device

# Get and Setup the Virt Tools
virt_tools_setup

# Get and Run the AIO Script
run_aio_script

# Set Boot Splash
setup_bootspash

# Set Grub2
setup_grub

# Set the Login Banner
setup_banner

# Blacklist Modules
blacklist_modules

exit 0
