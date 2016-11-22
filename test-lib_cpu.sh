#!/bin/bash
#
# Programa de muestra.
#
#
#

PARALELO=8
DEBUG=true

source lib_cpu.sh

paralelo "sleep 5" "sleep 10" "sleep 1" "sleep 2" "sleep 2" "sleep 10" "sleep 1" "sleep 2"

exit 0 
