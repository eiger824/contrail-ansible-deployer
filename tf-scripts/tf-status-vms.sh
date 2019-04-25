#!/bin/bash

source common.src

test_if_root

echo "$(pad_str 25 "Name")Status"
echo "$(pad_str 25 "====")======"
for vm in ${VMS}; do
    vm_status=$(virsh domstate ${vm} | head -1)    
    echo "$(pad_str 25 ${vm})${vm_status}"
done

