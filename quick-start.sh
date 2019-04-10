#!/bin/bash

# Custom quick guide for the impatient

if [ $UID -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

# Provision instances first - create KVMs
ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/provision_instances.yml

# Configure these machines
ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/configure_instances.yml

# Install Openstack Kolla
ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/install_openstack.yml

# Deploy Contrail
ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/install_contrail.yml
