#!/bin/bash

cmd_exec()
{
    if [ $INTERACTIVE -eq 1 ]; then
        echo -n "=> $@"
        read foo
    fi
    eval "$@"
    if [ $? -ne 0 ]; then
        echo -e "Command '\e[92m$@\e[39m' failed. Aborting." >&2
        echo "Flushing existing tables" >&2
        flush_tables
        exit 1
    fi
}

flush_tables()
{
    iptables -F
    iptables -t nat -F PREROUTING
    iptables -t nat -F POSTROUTING
    iptables -t mangle -F
}

usage()
{
    cat << EOF
Usage: $(basename $0) [ARGS]
ARGS:
-c  Prompt for confirmation before every command
-d  Toggle debug flag (equivalent as running bash with the \`-x' switch)
-e  Exit on error (equivalent as running bash with the \`-e' switch)
-h  Print this help and exit
EOF
}

# Put the relevant hostname in the regex
check_right_host()
{
    if [[ ! $(hostname) =~ ^santi$ ]] &> /dev/null; then
        return 1
    fi
    return 0
}

#Setting up some Variables #####################################################
INTERACTIVE=0

EXTIP="150.132.88.189"                        # Example 1.2.3.4
EXTIF="ens4"                                  # Example eth0

INTNET100="192.168.100.0/24"                  # Example 192.168.1.0/24
INTIF100="ens3"                               # Example eth1

INTNET101="192.168.101.0/24"                  # Example 192.168.1.0/24
INTIF101="ens9"                               # Example eth1
TF_CONT_INTNET101="192.168.101.50"
OS_CONT_INTNET101="192.168.101.100"

# Parse cmdline options
options=$(getopt -o cdeh -- "$@")
[ $? -eq 0 ] || {
    echo "Error setting options" >&2
    exit 1
}
eval set -- "$options"

while true; do
    case "$1" in
        -c)
            INTERACTIVE=1
            ;;
        -d)
            set -x
            ;;
        -e)
            set -e
            ;;
        -h)
            usage; exit 0
            ;;
        --)
            shift
            break
            ;;
    esac
    shift
done

if [ $UID -ne 0 ]; then
    echo "Run this script as ROOT" >&2
    exit 1
fi

if ! check_right_host; then
    echo "Are you running this script from the right host?" >&2
    exit 1
fi

#Disabling ipforwarding aka routing ############################################
cmd_exec 'echo 0 > /proc/sys/net/ipv4/ip_forward'

#Flushing tables and setting policys ###########################################
flush_tables

cmd_exec iptables -P FORWARD DROP
cmd_exec iptables -P INPUT DROP
cmd_exec iptables -P OUTPUT ACCEPT
cmd_exec iptables -A OUTPUT -o lo -j ACCEPT
cmd_exec iptables -A INPUT  -i lo -j ACCEPT

# INPUT from local network #####################################################
cmd_exec iptables -A INPUT -i $INTIF100 -s $INTNET100 -j ACCEPT
cmd_exec iptables -A INPUT -i $INTIF100 -p udp --dport 67 --sport 68 -j ACCEPT
cmd_exec iptables -A INPUT -i $INTIF101 -s $INTNET101 -j ACCEPT
cmd_exec iptables -A INPUT -i $INTIF101 -p udp --dport 67 --sport 68 -j ACCEPT

# Dropping private addresses on the external interface ########################
# iptables -A INPUT -i $EXTIF -s 10.0.0.0/8 -j DROP
# iptables -A INPUT -i $EXTIF -s 172.16.0.0/12 -j DROP
# iptables -A INPUT -i $EXTIF -s 192.168.0.0/16 -j DROP
# iptables -A INPUT -i $EXTIF -s 169.254.0.0/16 -j DROP
# iptables -A INPUT -i ! lo -s 127.0.0.0/8 -j DROP

# INPUT from external networks #################################################
# The example below allows traffic to a webserver that runs on your NAT box
# iptables -A INPUT -d $EXTIP -p tcp --dport 80 --sport 1024:65535 -j ACCEPT

# ICMP from external networks ##################################################
cmd_exec iptables -A INPUT -i $EXTIF -d $EXTIP -p icmp --icmp-type destination-unreachable -j ACCEPT
cmd_exec iptables -A INPUT -i $EXTIF -d $EXTIP -p icmp --icmp-type source-quench -j ACCEPT
cmd_exec iptables -A INPUT -i $EXTIF -d $EXTIP -p icmp --icmp-type time-exceeded -j ACCEPT
cmd_exec iptables -A INPUT -i $EXTIF -d $EXTIP -p icmp --icmp-type parameter-problem -j ACCEPT
cmd_exec iptables -A INPUT -i $EXTIF -d $EXTIP -p icmp --icmp-type \
    echo-request -m limit --limit 2/second --limit-burst 5 -j ACCEPT

# Allowing all traffic that is related to our traffic :) aka STATEFUL ##########
cmd_exec iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# FORWARD between internal and external network ################################
cmd_exec iptables -A FORWARD -i $INTIF100 -o $EXTIF -s $INTNET100 ! -d $INTNET100 -j ACCEPT
cmd_exec iptables -A FORWARD -i $EXTIF ! -s $INTNET100 -d $INTNET100 -m state --state RELATED,ESTABLISHED -j ACCEPT

cmd_exec iptables -A FORWARD -i $INTIF101 -o $EXTIF -s $INTNET101 ! -d $INTNET101 -j ACCEPT
cmd_exec iptables -A FORWARD -i $EXTIF ! -s $INTNET101 -d $INTNET101 -m state --state RELATED,ESTABLISHED -j ACCEPT

# MASQUERADING aka NAT #########################################################
cmd_exec iptables -t nat -A POSTROUTING -o $EXTIF -s $INTNET100 ! -d $INTNET100 -j MASQUERADE
cmd_exec iptables -t nat -A POSTROUTING -o $EXTIF -s $INTNET101 ! -d $INTNET101 -j MASQUERADE

# Allowing port forwarding to access the TF and OS controller Web UIs ##########
# TF
cmd_exec iptables -t nat  -A PREROUTING -p tcp -i $EXTIF --dport 5050 -j DNAT --to-destination $TF_CONT_INTNET101:8143
cmd_exec iptables -A FORWARD -p tcp -d $TF_CONT_INTNET101 --dport 8143 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
# OS
cmd_exec iptables -t nat  -A PREROUTING -p tcp -i $EXTIF --dport 8080 -j DNAT --to-destination $OS_CONT_INTNET101:80
cmd_exec iptables -A FORWARD -p tcp -d $OS_CONT_INTNET101 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Allow for remote VNC connections to port 6080
cmd_exec iptables -t nat  -A PREROUTING -p tcp -i $EXTIF --dport 6080 -j DNAT --to-destination $OS_CONT_INTNET101:6080
cmd_exec iptables -A FORWARD -p tcp -d $OS_CONT_INTNET101 --dport 6080 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Enabling stuff in /proc ######################################################
cmd_exec "echo 1 > /proc/sys/net/ipv4/tcp_syncookies"
cmd_exec "echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts"
cmd_exec "echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses"
cmd_exec "echo 1 > /proc/sys/net/ipv4/conf/$EXTIF/log_martians"
cmd_exec "echo 0 > /proc/sys/net/ipv4/conf/$EXTIF/accept_redirects"
cmd_exec "echo 0 > /proc/sys/net/ipv4/conf/$EXTIF/accept_source_route"

# Enabling anti Spoofing #######################################################
if [ -e /proc/sys/net/ipv4/conf/all/rp_filter ]; then
  for f in /proc/sys/net/ipv4/conf/*/rp_filter; do
      cmd_exec "echo 1 > $f"
  done
else
  echo
  echo "PROBLEMS SETTING UP IP SPOOFING PROTECTION.  BE WORRIED."
  echo
fi

# Enabling ipforwarding aka routing ############################################
cmd_exec 'echo 1 > /proc/sys/net/ipv4/ip_forward'

# Allow SSH to this machine
cmd_exec iptables -I INPUT -p tcp --dport 22 -j ACCEPT

# Linsing rules ################################################################
cmd_exec iptables -L -n -v
cmd_exec iptables -t nat -L -n -v

exit $?
