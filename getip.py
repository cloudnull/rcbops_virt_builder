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

"""Return the IPv4 Address for a device as found on the system."""

import ConfigParser
import netifaces
import os
import sys


def getip(device):
    """Get the IPv4 Address for the Device."""

    ips = netifaces.ifaddresses(device)[netifaces.AF_INET]
    ip_list = [ip for ip in ips
               if 'addr' in ip and not ip['addr'].startswith('172.16.0')]
    if ip_list:
        if 'addr' in ip_list[0]:
            return ip_list[0]['addr']
        else:
            return '127.0.0.1'
    else:
        return '127.0.0.1'


def _bridge_check(iface):
    """Check to see if an interface exists and if a bridged devices exists."""

    interfaces = netifaces.interfaces()
    if iface in interfaces:
        _iface = 'br%s' % iface[-1]
        if _iface in interfaces:
            return _iface
        else:
            return iface
    else:
        raise SystemExit('Interface "%s" not found' % iface)


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


if __name__ == '__main__':
    if len(sys.argv) > 1:
        print(
            getip(
                device=_bridge_check(
                    iface=sys.argv[1]
                )
            )
        )
    else:
        ifaces = _get_config()
        print(
            getip(
                device=_bridge_check(
                    iface=ifaces.get('user_device')
                )
            )
        )
