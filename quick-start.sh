#!/bin/bash

# Custom quick guide for the impatient

banner()
{
    local cols
    local msg 
    local diff
    cols=$(tput cols)
    msg="$@"
    echo -n "+"
    for i in $(seq 1 $(( $cols - 2 ))); do
        echo -n "-"
    done
    echo -ne "+\n|"
    diff=$(( $cols - ${#msg} - 2 ))
    start=$(( $diff / 2 ))
    for i in $(seq 1 $start); do
        echo -n " "
    done
    echo -n "${msg}"
    rend=$start
    if [ $(( $cols % 2 )) -ne 0 ]; then
        ((rend++))
    fi
    for i in $(seq 1 $rend); do
        echo -n " "
    done
    echo -ne "|\n+"
    for i in $(seq 1 $(( $cols - 2 ))); do
        echo -n "-"
    done
    echo "+"
}

check_err()
{
    if [ $1 -ne 0 ]; then
        echo "Previous command exited with non-zero retcode. Aborting" >&2
        exit 1
    fi
}

# if [ $UID -ne 0 ]; then
#     echo "Run this script as root." >&2
#     exit 1
# fi

# ssh_port="-e ansible_ssh_port=9898"
verbose=""

# Provision instances first - create KVMs
banner "Provisioning instances!"
ansible-playbook ${verbose} -e orchestrator=openstack ${ssh_port} -i inventory/ playbooks/provision_instances.yml
check_err $?

# Configure these machines
banner "Configuring instances!"
ansible-playbook ${verbose} -e orchestrator=openstack ${ssh_port} -i inventory/ playbooks/configure_instances.yml
check_err $?

# Install Openstack Kolla
banner "Installing Openstack!"
ansible-playbook ${verbose} -e orchestrator=openstack ${ssh_port} -i inventory/ playbooks/install_openstack.yml
check_err $?

# Deploy Contrail
banner "Installing Tungsten Fabric!"
ansible-playbook ${verbose} -e orchestrator=openstack ${ssh_port} -i inventory/ playbooks/install_contrail.yml
check_err $?
