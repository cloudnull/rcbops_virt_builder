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

"""Return the IPv4 Address for eth0 from ohai."""

import ConfigParser
import subprocess
import json
import os
import sys


def getip(device):
    """Get the IPv4 Address for the Device."""

    # Open Ohai and get some data
    ohai_popen = subprocess.Popen(
        ['ohai', '-l', 'fatal'], stdout=subprocess.PIPE
    )
    ohai = ohai_popen.communicate()

    # Load the aata as JSON
    data = json.loads(ohai[0])

    # Grab eth0 from the data
    eths = data['network']['interfaces']
    eth = eths.get(device, eths.get('eth1'))
    if eth is None:
        raise SystemExit('No Device found for "%s"' % device)
    else:
        addresses = eth.get('addresses')
        if addresses is None:
            raise SystemExit('No addresses found for "%s"' % device)
    # parse the data and print the value
    for key, value in addresses.items():
        if 'prefixlen' in value and value['prefixlen'] == '24':
            # Key found, print the value
            print(key)
            break
    else:
        # No key found print error
        raise SystemExit('No IPv4 address found')


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
        getip(device=sys.argv[1])
    else:
        getip(device=_get_config().get('device'))
