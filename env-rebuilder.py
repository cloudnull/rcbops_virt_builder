#!/usr/bin/env python

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

"""Perform a Network Reset on a chef environment."""

import json
import tempfile
import os
import subprocess
import sys


def _get_network(json_data, interface, override=False):
    """Get and set network interfaces."""

    device = json_data['network']['interfaces'].get(interface)
    if device is not None:
        if device.get('routes'):
            routes = device['routes']
            for net in routes:
                if 'scope' in net:
                    if override is True:
                        return '127.0.0.0/24'
                    else:
                        cidr = net.get('destination', '127.0.0.0/24')
                        if cidr is None:
                            return '127.0.0.0/24'
                        else:
                            return cidr
                    break
            else:
                return '127.0.0.0/24'
        else:
            return '127.0.0.0/24'
    else:
        return '127.0.0.0/24'


if __name__ == '__main__':
    # Run the Munger
    if len(sys.argv) > 2:
        input_file = sys.argv[1]
        ip_address = sys.argv[2]
        if len(sys.argv) == 4:
            override = True
        else:
            override = False
    else:
        raise SystemExit('No Arguments Input file specified.')

    # Open Ohai and get some data
    ohai_popen = subprocess.Popen(
        ['ohai', '-l', 'fatal'], stdout=subprocess.PIPE
    )
    ohai = ohai_popen.communicate()

    # Load Ohai data as a Dict
    data = json.loads(ohai[0])

    # Set Management Network Interfaces
    management_network = _get_network(
        json_data=data, interface="eth0", override=override
    )

    # Set Nova Network Interfaces
    nova_network = _get_network(
        json_data=data, interface="eth0", override=override
    )

    # Set Public Network Interfaces
    public_network = _get_network(
        json_data=data, interface="eth0", override=override
    )

    # Open passed JSON file
    with open(input_file, 'rb') as knife_env:
        chef_env = json.loads(knife_env.read())

    # Get Overrides
    overrides = chef_env.get('override_attributes')

    # Set Rabbit Bind Address and Cookie
    rabbit = overrides.get('rabbitmq')
    rabbit['address'] = ip_address
    if os.path.exists('/var/lib/rabbitmq/.erlang.cookie'):
        with open('/var/lib/rabbitmq/.erlang.cookie', 'r') as erlang_cookie:
            rabbit_cookie = erlang_cookie.read()        
    else:
        rabbit_cookie = 'AnyStringWillDoJustFine'
    rabbit['erlang_cookie'] = rabbit_cookie

    # Set MySQL Bind Address
    mysql = overrides.get('mysql')
    mysql['bind_address'] = '0.0.0.0'

    # Get Networks
    networks = overrides.get('osops_networks')
    networks['management'] = management_network
    networks['nova'] = nova_network
    networks['public'] = public_network

    # Set temp file
    tempdir = tempfile.gettempdir()

    # Set write file
    write_file = '%s%s%s' % (tempdir, os.sep, 'new-knife-env.json')

    # Remove write file if exists
    if os.path.exists(write_file):
        os.remove(write_file)

    # Write out the new file
    with open(write_file, 'wb') as knife_env:
        knife_env.write(json.dumps(chef_env, indent=2))
    
    print('%s' % write_file)
