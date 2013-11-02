Build a RCBOPS Virtual Appliance
################################
:date: 2013-09-05 09:51
:tags: rackspace, openstack,
:category: \*nix

Build an Rackspace Private Cloud Virtual Appliance
==================================================


General Overview
~~~~~~~~~~~~~~~~


Installs all of the tools needed for a virtual appliance.


This script works with Ubuntu 12.04 and CentOS6/RHEL6
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


MINIMUM SYSTEM REQUIREMENTS
---------------------------

* Linux Operating System (*CentOS/RHEL or Ubuntu*)
* Dual Core Processor
* 2GB or RAM
* 10GB of Storage



OVERVIEW
--------

This script will install and configure the following:

* Virtual Image Rebuild INIT script
* Openstack Controller
* Openstack Compute
* Horizon
* Cinder
* Nova-Network
* Cirros Image
* Fedora Image
* Ubuntu Image
* Qemu is used for the Virt Driver
* The Latest Stable Chef Server
* Chef Client
* Knife


NOTICE
------

This installation scrip has **ONLY** been tested on the following platforms:

* KVM
* Physical Server
* Rackspace Cloud Server
* Amazon AWS
* VMWare Fusion
* Virtual Box


Here is how you can get Started
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


1. Clone this repo locally on your VM.
2. Execute the script `virt-setup.sh`


If you would like to use Neutron set:
`export USE_NEUTRON=True`


NOTICE: I WOULD NOT RECOMMEND USING THIS IN PRODUCTION!
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
