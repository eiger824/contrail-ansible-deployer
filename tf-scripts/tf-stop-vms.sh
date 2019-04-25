#!/bin/bash

source common.src

test_if_root

for vm in ${VMS}; do
    if virsh domstate ${vm} | grep -i "shut off" &> /dev/null; then
        echo "Skipping \"${vm}\", already stopped!"
    else
        echo "Stopping \"${vm}\"..."
        virsh shutdown ${vm}
        wait_for_vm_stop ${vm}
    fi
done

