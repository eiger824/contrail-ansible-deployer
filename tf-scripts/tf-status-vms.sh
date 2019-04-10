#!/bin/bash

if [ $UID -ne 0 ]; then
    echo "Run this script as the superuser" >&2
    exit 1
fi

for vm in contrail-controller-01 \
    contrail-compute-01 \
    contrail-compute-02; do
    vm_status=$(virsh domstate ${vm} | head -1)    
    echo "\"${vm}\" ==> ${vm_status}"
done

