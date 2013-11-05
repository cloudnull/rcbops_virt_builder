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


# Graceful Shutdown of ChefServer
function chef_kill() {
  chef-server-ctl graceful-kill
}


# Kill all the Openstack things
# ==============================================================================
function os_kill() {
  set +e
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
  set -e
}


# Kill RabbitMQ
# ==============================================================================
function rabbitmq_kill() {
  # Replace IP address for Rabbit
  echo "Stopping RabbitMQ"
  service rabbitmq-server stop
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


# Reset nova endpoints
# ==============================================================================
function reset_nova_endpoint() {
  echo "Resetting Nova Endpoints"
  # Load the Openstack Credentials
  MYSQLCRD="/root/.my.cnf"
  USERNAME="$(awk -F'=' '/user/ {print $2}' ${MYSQLCRD})"
  PASSWORD="$(awk -F'=' '/password/ {print $2}' ${MYSQLCRD})"
  NUKECMD="delete from endpoint where region=\"RegionOne\";"
  mysql -u "${USERNAME}" -p"${PASSWORD}" -o keystone -e "${NUKECMD}"
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
  sed "s/NODE_IP_ADDRESS=.*/NODE_IP_ADDRESS=\"\"/" /etc/rabbitmq/rabbitmq-env.conf > /tmp/rabbitmq-env.conf2
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
  # Munge the Base JSON Environment
  ORIG_JSON="${SCRIPT_DIR}/base.json"
  NEW_ENV=$(${SCRIPT_DIR}/env-rebuilder.py ${ORIG_JSON} ${SYS_IP})

  # Overwrite the OLD Environment with a  NEW environment
  knife environment from file ${NEW_ENV}
}


# Package For Distribution
# ==============================================================================
function package_prep() {
  echo "Performing package prep"
  ORIG_JSON="${SCRIPT_DIR}/base.json"
  NEW_ENV=$(${SCRIPT_DIR}/env-rebuilder.py ${ORIG_JSON} ${SYS_IP} "override")
  # Overwrite the OLD Environment with BASE environment
  if [ -f "/opt/last.ip.lock" ];then
    rm /opt/last.ip.lock
  fi
  knife environment from file ${NEW_ENV}
  echo '' | tee /root/.bash_history
  history -c
}


# Run Chef-Client
# ==============================================================================
function run_chef_client() {
  # Run Chef-client to rebuild all the things
  set -v
  chef-client
  set +v
}


# Clear all of the cache things we can find
# ==============================================================================
function clear_cache() {
  apt-get clean
}


# Start Everything
# ==============================================================================
function start_vm() {
  start_swap
  reset_nova_endpoint
  reset_rabbitmq
  reset_knife_rb
  reset_chef_server
  reset_chef_env
  run_chef_client
  reset_motd
}


# Disable Swap
# ==============================================================================
function start_swap() {
  # Enable swap from script
  if [ -f "/opt/swap.sh" ];then
    /opt/swap.sh
  fi
  
  # Enable all the swaps
  swapon -a
}


# Fill all remaining Disk with Zero's
# ==============================================================================
function zero_fill() {
  echo "Performing A Zero Fill"
  set +e
  pushd /tmp
  cat /dev/zero > zero.fill
  sync
  sleep 1
  rm -f zero.fill
  sync
  sleep 1
  popd
  set -e
  sync
  sleep 1
}


# Stop the VM services
# ==============================================================================
function stop_vm() {
  reset_rabbitmq
  echo "Last System IP address was: \"$SYS_IP\"" | tee /opt/last.ip.lock
}


# Stop Swap
# ==============================================================================
function stop_swap() {
  SWAPFILE="/tmp/SwapFile"
  echo "Stopping Swap"
  swapoff -a
  sleep 2

  if [ -f "${SWAPFILE}" ];then
    echo "Removing Swap File."
    rm ${SWAPFILE}
  fi
}


# System Stop
# ==============================================================================
function hard_stop() {
  echo "Shutting Down The System"
  echo 1 > /proc/sys/kernel/sysrq 
  echo o > /proc/sysrq-trigger
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
    stop_swap
  ;;
  restart)
    echo $PROGRAM is Restarting...
    stop_vm
    rebuild_check
    start_vm
  ;;
  os-kill)
    os_kill
  ;;
  force-rebuild)
    set +e
    start_vm
  ;;
  nuke-endpoints)
    set +e
    reset_nova_endpoint
  ;;
  package-instance)
    reset_nova_endpoint
    package_prep
    run_chef_client
    clear_cache
    os_kill
    reset_rabbitmq
    rabbitmq_kill
    chef_kill
    stop_swap
    zero_fill
    hard_stop
  ;;
  *)
    echo "Usage: $0 {start|stop|restart|os-kill|force-rebuild|nuke-endpoints|package-instance}" >&2
    exit 1
  ;;
esac 
