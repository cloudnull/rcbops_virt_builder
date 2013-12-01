Nova Compute
------------

edit file ``/opt/allinoneinone/chef-cookbooks/cookbooks/nova/recipes/compute.rb``

create an entry for LXC support in the VM, Line 30-37::

    if platform?(%w(ubuntu))
      case node["nova"]["libvirt"]["virt_type"]
      when "kvm"
        nova_compute_packages.push("nova-compute-kvm")
      when "qemu"
        nova_compute_packages.push("nova-compute-qemu")
      when "lxc"
        nova_compute_packages.push("nova-compute-lxc")
      end
    end


Horizon
-------

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


re-Upload all cookbooks::

    knife cookbook upload -a -o /opt/allinoneinone/chef-cookbooks/cookbooks/


Chef Environment
----------------

edit the file ``/opt/vm-rebuilder/base.json``
change line 43 to: ``"virt_type": "lxc"``

Now edit the chef environment::

    knife environment edit allinoneinone


In the chef environment editor also change the virt type to "lxc"


Apply Changes to the System
---------------------------

create the first boot file::

    touch /opt/first.boot


Now reboot the system::

    shutdown -r now



Glance Image Create
-------------------

Download your base image file, uncompress the archive::

    curl -O http://cloud-images.ubuntu.com/raring/current/raring-server-cloudimg-amd64.tar.gz
    tar xzf raring-server-cloudimg-amd64.tar.gz


Create your Image for Ubuntu::

    glance image-create --file raring-server-cloudimg-amd64.img \
                        --is-public true \
                        --disk-format raw \
                        --container-format bare \
                        --name "precise" \
                        --property hypervisor_type=lxc
