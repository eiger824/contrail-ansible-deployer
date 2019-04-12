#!/bin/bash

# Custom quick guide for the impatient

check_err()
{
    if [ $1 -ne 0 ]; then
        echo "Previous command exited with non-zero retcode. Aborting" >&2
        exit 1
    fi
}

if [ $UID -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

# Provision instances first - create KVMs
# ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/provision_instances.yml
# check_err $?

# Configure these machines
ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/configure_instances.yml
check_err $?

# Install Openstack Kolla
ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/install_openstack.yml
check_err $?

# Deploy Contrail
ansible-playbook -e orchestrator=openstack -i inventory/ playbooks/install_contrail.yml
check_err $?
