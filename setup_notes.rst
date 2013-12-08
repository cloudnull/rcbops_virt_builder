Prebuild Setup
--------------

Edit the file ``/etc/resolvconf/resolv.conf.d/base``

Create two entries for base DNS::

    nameserver 8.8.8.8
    nameserver 8.8.4.4


Edit the file ``/etc/network/interfaces``

You should have three network interfaces setup on your VM, two are setup now, one is doen by the installation script.

Make your default network interfaces file look like this::

    # The loopback network interface
    auto lo
    iface lo inet loopback

    # The primary network interface
    auto eth0
    iface eth0 inet dhcp

    auto eth1
    iface eth1 inet static
      address 10.50.51.50
      netmask 255.255.255.0

    auto eth2
    iface eth2 inet dhcp

    auto eth3
    iface eth3 inet static
      address 172.16.151.150
      netmask 255.255.255.0


Now go install your GUEST additions for the Desktop Hypervisor you are using.


Setup Script
~~~~~~~~~~~~

Get the setup scripts and then run the setup script::

    apt-get install python-netifaces
    git clone https://github.com/cloudnull/rcbops_virt_builder
    pushd rcbops_virt_builder
    bash ./virt-setup.sh
    popd


* When running the setup script you first have to export two variables to tell the script to use neutron, and what interface neutron will be assigned to.

Setup::

    export NEUTRON_ENABLED=True


Install Openstack
~~~~~~~~~~~~~~~~~

Get the installation script and run the setup.

Goto the script directory::

    pushd /opt/aio-script/


Run setup for Openstack exports::

    # Setup no roll back on failure
    export DISABLE_ROLL_BACK=true

    # Setup a master dev environment
    export COOKBOOK_VERSION="master"

    # Setup cidrs
    export NOVA_INTERFACE="eth2"
    export MANAGEMENT_INTERFACE="eth0"

    # Setup passwords
    export NOVA_PW="Passw0rd"
    export RMQ_PW="Passw0rd"
    export CHEF_PW="Passw0rd"

    # Set an override for my roles
    export RUN_LIST="role[allinone],role[heat-all],role[cinder-all]"

    # Add Some default Images
    export UBUNTU_IMAGE=False
    export FEDORA_IMAGE=False


If using Neutron add the following::

    # Set an override for my roles
    export RUN_LIST="role[allinone],role[single-network-node],role[heat-all],role[cinder-all]"

    # Setup for Neutron
    export NEUTRON_NAME="neutron"
    export NEUTRON_INTERFACE="eth1"
    export NEUTRON_ENABLED=True

    # Setup the network name
    export NEUTRON_NETWORK_NAME="raxaioionet"


Now run the installation script::

    bash ./rcbops_allinone_inone.sh
    # Save the new environment file upon completion.
    knife environment show allinoneinone -fj > /opt/vm-rebuilder/base.json
    # backup the new motd
    cp /etc/motd /etc/motd.old
    popd


Horizon
-------

* Get the SPOG module and install it.

edit file ``/opt/allinoneinone/chef-cookbooks/cookbooks/horizon/templates/default/local_settings.py.erb``

Create an entry for the rackspace tab in the horizon config::

    import sys
    import rackspace
    mod = sys.modules['openstack_dashboard.settings']
    mod.INSTALLED_APPS += ('rackspace',)
    if 'STATICFILES_DIRS' in dir(mod):
        mod.STATICFILES_DIRS += (
            os.path.join(rackspace.__path__[0], 'static')
        )
    else:
        mod.STATICFILES_DIRS = (
            os.path.join(rackspace.__path__[0], 'static')
        )


Also modify the default base config hash::

    HORIZON_CONFIG = {
        'dashboards': ('rackspace', 'project', 'admin', 'settings',),
        'default_dashboard': 'rackspace',
        'user_home': 'rackspace.views.get_user_home',
        'ajax_queue_limit': 10,
        'auto_fade_alerts': {
            'delay': 3000,
            'fade_duration': 1500,
            'types': ['alert-success', 'alert-info']
        },
        'help_url': "<%= @help_url %>",
        'exceptions': {'recoverable': exceptions.RECOVERABLE,
                       'not_found': exceptions.NOT_FOUND,
                       'unauthorized': exceptions.UNAUTHORIZED},
    }


re-Upload all cookbooks, run chef-cleint, and restart apache, gather static files::

    knife cookbook upload -a -o /opt/allinoneinone/chef-cookbooks/cookbooks/
    chef-client
    service apache2 restart && service memcached restart
    /usr/share/openstack-dashboard/manage.py collectstatic --noinput



Apply Changes to the System
---------------------------

create the first boot file::

    touch /opt/first.boot


Now reboot the system::

    shutdown -rF now



Glance Image Create
-------------------

Download your base image and load it into glance::

    wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img

    glance image-create --file cirros-0.3.0-x86_64-disk.img \
                        --is-public true \
                        --disk-format raw \
                        --container-format bare \
                        --name "cirros"
    rm cirros-0.3.0-x86_64-disk.img


Repeate for another image if you want.


Getting the System Ready for Export
-----------------------------------

The rebuild service has a function that will perform all of the needed tasks to get the virtual appliance ready for export.

Run the service function::

    [ -f "~/.bash_history" ] && rm ~/.bash_history; history -c && sync && service rebuild-env package-instance


Upon completion, the appliance will be offline and ready for export into OVA format.
