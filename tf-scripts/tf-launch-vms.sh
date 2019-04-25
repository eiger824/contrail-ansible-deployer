#!/bin/bash

source common.src

test_if_root

for vm in ${VMS}; do
    if virsh domstate ${vm} | grep -i "running" &> /dev/null; then
        echo "Skipping \"${vm}\", already running!"
    else
        echo "Starting \"${vm}\"..."
        virsh start ${vm}
        wait_for_vm_start
    fi
done

