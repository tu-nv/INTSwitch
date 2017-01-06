#!/bin/bash

# Exit on errors
set -e

export JAVA_HOME=/usr/lib/jvm/java-8-oracle
export ONOS_ROOT=~/onos
source $ONOS_ROOT/tools/dev/bash_profile
export ONOS_IP=10.0.2.15
export ONOS_APPS=drivers,openflow,proxyarp,mobility,fwd
export BMV2_PATH=~/onos-p4-dev/onos-bmv2
export BMV2_EXE=~/onos-p4-dev/onos-bmv2/targets/simple_switch/simple_switch
export BMV2_JSON=~/onos-p4-dev/p4src/build/default.json
source ~/onos-p4-dev/tools/bash_profile