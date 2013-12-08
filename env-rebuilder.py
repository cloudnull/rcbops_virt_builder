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

import ConfigParser
import json
import tempfile
import netifaces
import os
import sys


def _get_network(iface, override=False):
    """Get and set network interfaces."""

    if override is True:
        return '172.16.151.0/24'
    else:
        ips = netifaces.ifaddresses(iface)[netifaces.AF_INET]
        ip_list = [ip for ip in ips
                   if 'addr' in ip and not ip['addr'].startswith('172.16.0')]
        if ip_list:
            if 'addr' in ip_list[0]:
                ip = ip_list[0]['addr']
                return '%s/24' % '.'.join(ip.split('.')[:-1] + ['0'])
            else:
                return '172.16.151.0/24'
        else:
            return '172.16.151.0/24'


def _get_config(config_file='/opt/rebuilder.ini'):
    """Load the configuration file from the rebuilder."""

    if os.path.isfile(config_file):
        config = ConfigParser.SafeConfigParser()
        config.read([config_file])
        section = 'BaseNetwork'
        if section in config.sections():
            return dict(config.items(section))
        else:
            raise SystemExit('No Section found')
    else:
        raise SystemExit('Config file %s does not exist.' % config_file)


def _bridge_check(iface):
    interfaces = netifaces.interfaces()
    _iface = 'br%s' % iface[-1]
    if _iface in interfaces:
        return _iface
    else:
        return iface


if __name__ == '__main__':
    # Run the Munger
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
        if len(sys.argv) == 3:
            override = True
        else:
            override = False
    else:
        raise SystemExit('No Arguments Input file specified.')

    # Open passed JSON file
    with open(input_file, 'rb') as knife_env:
        chef_env = json.loads(knife_env.read())

    # Get Overrides
    overrides = chef_env.get('override_attributes')

    # Set Rabbit Bind Address and Cookie
    rabbit = overrides.get('rabbitmq')
    rabbit['address'] = ''
    if os.path.exists('/var/lib/rabbitmq/.erlang.cookie'):
        with open('/var/lib/rabbitmq/.erlang.cookie', 'r') as erlang_cookie:
            rabbit_cookie = erlang_cookie.read()
    else:
        rabbit_cookie = 'AnyStringWillDoJustFine'
    rabbit['erlang_cookie'] = rabbit_cookie

    # Set MySQL Bind Address
    mysql = overrides.get('mysql')
    mysql['bind_address'] = '0.0.0.0'

    # Grab the device from the config file.
    rebuild_data = _get_config()
    public_iface = _bridge_check(iface=rebuild_data.get('public_device'))
    user_iface = _bridge_check(iface=rebuild_data.get('user_device'))

    # Get and set Networks
    networks = overrides.get('osops_networks')
    networks['public'] = _get_network(iface=public_iface,
                                      override=override)

    networks['management'] = _get_network(iface=public_iface,
                                          override=override)

    networks['nova'] = _get_network(iface=user_iface,
                                    override=override)

    # Make sure Heat workers are set back to basics
    overrides['heat'] = {
        "services": {
            "cloudwatch_api": {
              "workers": 2,
            },
            "cfn_api": {
              "workers": 2,
            },
            "base_api": {
              "workers": 2,
            }
        }
    }

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

    # Print the location of the new json file.
    print('%s' % write_file)
