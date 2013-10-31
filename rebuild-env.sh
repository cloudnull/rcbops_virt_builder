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

# chkconfig: 2345 20 20
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

# Set HOME
export HOME="/root"

# Set the Path 
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"

# Set the location of the script
SCRIPT_DIR='/opt/vm-rebuilder'

# Set the systems IP ADDRESS
SYS_IP=$(ohai ipaddress | awk '/^ / {gsub(/ *\"/, ""); print; exit}')

# What is the Name of this Script, and what are we starting
PROGRAM="VM_REBUILDER At: ${SYS_IP}"

# ==============================================================================
#           DO NOT EDIT THIS AREA UNLESS YOU KNOW WHAT YOU ARE DOING    
# ==============================================================================
set -e 

# Reset nova endpoints
# ==============================================================================
function nova_endpoint_reset() {
  echo "Resetting Nova Endpoints"
  # Load the Openstack Credentials
  MYSQLCRD="/root/.my.cnf"
  USERNAME="$(awk -F'=' '/user/ {print $2}' ${MYSQLCRD})"
  PASSWORD="$(awk -F'=' '/password/ {print $2}' ${MYSQLCRD})"
  NUKECMD="delete from endpoint where region=\"RegionOne\";"
  mysql -u "${USERNAME}" -p"${PASSWORD}" -o keystone -e "${NUKECMD}"
}

# Kill all the nova things
# ==============================================================================
function nova_kill() {
  # General Services
  SERVICES="cinder glance nova keystone ceilometer heat horizon"

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

# Rebuild Knife
# ==============================================================================
function reset_knife_rb() {
  echo "Resetting Knife"
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

# Reconfigure Chef Server and Rabbit
# ==============================================================================
function reset_chef_server() {
  echo "Resetting Chef Server"
  # Reset client.rb
  cat > /etc/chef/client.rb <<EOF
log_level        :auto
log_location     STDOUT
chef_server_url  "https://${SYS_IP}:4000"
validation_client_name "chef-validator"
EOF
  
  # Reconfigure Chef-server
  chef-server-ctl reconfigure
  chef-server-ctl restart
  echo "Resting Post Chef Restart"
  sleep 2
}


# Reconfigure RabbitMQ
# ==============================================================================
function reset_rabbitmq() {
  echo "Resetting RabbitMQ"
  # Replace IP address for Rabbit
  sed "s/NODE_IP_ADDRESS=.*/NODE_IP_ADDRESS=${SYS_IP}/" /etc/rabbitmq/rabbitmq-env.conf > /tmp/rabbitmq-env.conf2
  mv /tmp/rabbitmq-env.conf2 /etc/rabbitmq/rabbitmq-env.conf
  service rabbitmq-server restart
}


# Set MOTD with new information
# ==============================================================================
function reset_motd() {
  echo "Resetting MOTD"
  # Change the Horizon URL in the MOTD
  sed "s/Horizon URL is.*/Horizon URL is\t\t       : https:\/\/${SYS_IP}:443/" /etc/motd > /etc/motd2
  mv /etc/motd2 /etc/motd

  # Change the Chef URL in the MOTD
  sed "s/Chef Server URL is.*/Chef Server URL is\t       : https:\/\/${SYS_IP}:4000/" /etc/motd > /etc/motd2
  mv /etc/motd2 /etc/motd
}


# Rebuild Chef Environment
# ==============================================================================
function reset_chef_env() {
  echo "Resetting Chef Environment"
  # Munge the OLD JSON Environment
  COOKBOOK_DIR="/opt/allinoneinone/chef-cookbooks"
  ORIG_JSON="${SCRIPT_DIR}/base.json"
  NEW_ENV=$(${SCRIPT_DIR}/env-rebuilder.py ${ORIG_JSON} ${SYS_IP})

  # Overwrite the OLD Environment with a  NEW environment
  knife environment from file ${NEW_ENV}

  # Run Chef-client to rebuild all the things
  set -v
  chef-client
}


# Reconfigure All the things or Nothing
# ==============================================================================
function start_vm() {
  nova_endpoint_reset
  reset_rabbitmq
  reset_knife_rb
  reset_chef_server
  reset_chef_env
  reset_motd
}


# Stop the VM services
# ==============================================================================
function stop_vm() {
  echo "Last System IP address was: \"$SYS_IP\"" | tee /opt/last.ip.lock
}


# Check before Rebuilding
# ==============================================================================
function rebuild_check() {
  if [ -f "/opt/last.ip.lock" ];then
    if [ "$(grep -w \"${SYS_IP}\" /opt/last.ip.lock)" ];then
      echo "No System Changes Detected, Continuing with Regular Boot..."
      exit 0
    fi
  else
    echo "Lock File not found..."
  fi
}

case "$1" in
  start)
    clear
    echo $PROGRAM is Initializing... 
    rebuild_check
    start_vm
  ;;
  stop)
    echo $PROGRAM is Shutting Down...
    stop_vm
  ;;
  restart)
    echo $PROGRAM is Restarting...
    stop_vm
    rebuild_check
    start_vm
  ;;
  os-kill)
    set -v
    set +e
    nova_kill
  ;;
  force-rebuild)
    set +e
    reset_rabbitmq
    reset_knife_rb
    reset_chef_server
    reset_chef_env
    reset_motd
  ;;
  nuke-endpoints)
    set +e
    nova_endpoint_reset
  ;;
  *)
    echo "Usage: $0 {start|stop|restart|os-kill|force-rebuild}" >&2
    exit 1
  ;;
esac 
