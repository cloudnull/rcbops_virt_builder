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

# chkconfig: 2345 15 15
# Description: Build and Rebuild a virtual environment

### BEGIN INIT INFO
# Provides: 
# Required-Start: $remote_fs $network $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Rackspace Appliance init script
# Description: Build and Rebuild a virtual environment
### END INIT INFO

# Set the Path 
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"

# What is the Name of this Script, and what are we starting
PROGRAM="VM_REBUILDER"

# Set the location of the script
SCRIPT_DIR='/opt/vm-rebuilder'

# Set the systems IP ADDRESS
SYS_IP=$(ohai ipaddress | awk '/^ / {gsub(/ *\"/, ""); print; exit}')

# User, This should be root or root-ish
USER="root"

# ==============================================================================
#           DO NOT EDIT THIS AREA UNLESS YOU KNOW WHAT YOU ARE DOING    
# ==============================================================================
set -e 

# Reset nova endpoints
# ==============================================================================
function nova_endpoint_reset() {
  # Load the Openstack Credentials
  source /root/openrc

  KEYSTONE="False"

  # Get all of the endpoints
  ENDPOINTS=$(keystone endpoint-list | awk -v q='|' '/RegionOne/ {print $2q$6}')

  # Destroy our Endpoints
  for endpoint in ${ENDPOINTS};do
    if [[ "$(echo \"${endpoint}\" | grep 5000)" ]];then
      KEYSTONE="$(echo -e "${endpoint}" | awk -F'|' '{print $1}')"
    else
      keystone endpoint-delete "$(echo -e "${endpoint}" | awk -F'|' '{print $1}')"
    fi
  done

  # Finally delete the keystone endpoint
  if [ ! "${KEYSTONE}" == "False" ];then
    keystone endpoint-delete ${KEYSTONE}
  fi
}

# Kill all the nova things
# ==============================================================================
function nova_kill() {
  # General Services
  SERVICES="chef-server-webui erchef bookshelf chef apache mysql httpd libvirt "
  SERVICES+="rabbitmq nginx cinder glance nova keystone ceilometer heat horizon"

  # Stop Service
  for service in ${SERVICES}; do
    for pid in $(ps auxf | grep -i ${service} | grep -v grep | awk '{print $2}'); do
      if [ "${pid}" ];then
        if [ "$(ps auxf | grep ${pid} | grep -v grep | awk '{print $2}')" ];then
          kill ${pid}
        fi
      fi
    done
  done
}

# Rebuild Chef Environment
# ==============================================================================
function reset_chef_env() {
  # Get the OLD Environment
  knife environment show allinoneinone -fj | tee /tmp/old-knife-env.json

  # Munge the OLD JSON Environment
  NEW_ENV=$(${SCRIPT_DIR}/env-rebuilder.py /tmp/old-knife-env.json)

  # Overwrite the OLD Environment with a  NEW environment
  knife environment from file ${NEW_ENV}

  # Run Chef-client to rebuild all the things
  set -v
  chef-client
}

# Rebuild Knife
# ==============================================================================
function reset_knife_rb() {
  # Create Chef Dir if not found
  if [ ! -d "/root/.chef" ];then
    mkdir -p /root/.chef
  fi

  # Set knife.rb
  cat > /root/.chef/knife.rb <<EOF
log_level                :info
log_location             STDOUT
node_name                'admin'
client_key               '/etc/chef-server/admin.pem'
validation_client_name   'chef-validator'
validation_key           '/etc/chef-server/chef-validator.pem'
chef_server_url          "https://${SYS_IP}:4000"
cache_options( :path => '/root/.chef/checksums' )
cookbook_path            [ '/opt/allinoneinone/chef-cookbooks/cookbooks' ]
EOF
}

# Set MOTD with new information
# ==============================================================================
function reset_motd() {
  # Change the Horizon URL in the MOTD
  sed "s/Horizon URL is.*/Horizon URL is\t\t       : https:\/\/${SYS_IP}:443/" /etc/motd > /etc/motd2
  mv /etc/motd2 /etc/motd

  # Change the Chef URL in the MOTD
  sed "s/Chef Server URL is.*/Chef Server URL is\t       : https:\/\/${SYS_IP}:4000/" /etc/motd > /etc/motd2
  mv /etc/motd2 /etc/motd
}

# Reconfigure Chef Server and Rabbit
# ==============================================================================
function reset_chef_server() {
  # Replace IP address for Rabbit
  sed "s/NODE_IP_ADDRESS=.*/NODE_IP_ADDRESS=${SYS_IP}/" /etc/rabbitmq/rabbitmq-env.conf > /tmp/rabbitmq-env.conf2
  mv /tmp/rabbitmq-env.conf2 /etc/rabbitmq/rabbitmq-env.conf
  
  # Restart Rabbit
  service rabbitmq-server start
  
  # Reset client.rb
  cat > /etc/chef/client.rb <<EOF
log_level        :auto
log_location     STDOUT
chef_server_url  "https://${SYS_IP}:4000"
validation_client_name "chef-validator"
EOF
  
  # Reconfigure Chef-server
  chef-server-ctl reconfigure
}

# Reconfigure Chef Server and Rabbit
# ==============================================================================
function start_vm() {
  reset_chef_server
  reset_knife_rb
  reset_chef_env
  reset_motd
}

# Stop the VM services
# ==============================================================================
function stop_vm() {
  nova_endpoint_reset
}

case "$1" in
  start)
    echo $PROGRAM is Initializing... 
    start_vm
  ;;
  stop)
    set +e
    echo $PROGRAM is Shutting Down...
    stop_vm
    nova_kill
  ;;
  restart)
    echo $PROGRAM is Restarting...
    set +e
    stop_vm

    set -e
    start_vm
  ;;
  *)
    echo "Usage: $0 {start|stop|restart}" >&2
    exit 1
  ;;
esac 
