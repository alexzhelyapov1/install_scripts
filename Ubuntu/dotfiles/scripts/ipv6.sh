#!/bin/bash
# Disables IPv6 until reboot.

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
