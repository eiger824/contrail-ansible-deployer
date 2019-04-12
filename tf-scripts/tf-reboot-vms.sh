#!/bin/bash

if [[ ! -f "common.src" ]]; then
    echo "Run this script from the \`tf-scripts' directory" >& 2
    exit 1
fi

source common.src

test_if_root

for vm in contrail-controller-01 \
    contrail-compute-01 \
    contrail-compute-02; do
    if virsh domstate ${vm} | grep -i "shut off" &> /dev/null; then
        echo "Skipping \"${vm}\", not running!"
    else
        echo "Rebooting\"${vm}\"..."
        virsh reboot ${vm}
    fi
done

