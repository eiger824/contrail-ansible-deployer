#!/bin/bash

source common.src

test_if_root

echo "$(pad_str 25 "Name")Status"
echo "$(pad_str 25 "====")======"
for vm in contrail-controller-01 \
    contrail-compute-01 \
    contrail-compute-02; do
    vm_status=$(virsh domstate ${vm} | head -1)    
    echo "$(pad_str 25 ${vm})${vm_status}"
done

