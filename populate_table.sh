#!/bin/bash

# Exit on errors
set -e

export P4_PATH=~/onos-p4-dev
export BMV2_PATH=$P4_PATH/onos-bmv2
export BMV2_EXE=$BMV2_PATH/targets/simple_switch/simple_switch
export BMV2_JSON=$P4_PATH/p4src/build/default.json
export BMV2_PY=$P4_PATH/mininet/bmv2.py
export P4C_BM_PATH=$P4_PATH/p4c-bmv2
export P4SRC_PATH=$P4_PATH/p4src

p4cli () {
    if [ -z "$1" ]; then
        echo "No argument supplied. Usage: p4cli THRIFT_PORT"
        return
    fi
    tport=$(head -n 1 /tmp/bmv2-$1-thrift-port)
    sudo $BMV2_PATH/tools/runtime_CLI.py --thrift-port $tport
}

sscli () {
    if [ -z "$1" ]; then
        echo "No argument supplied. Usage: sscli THRIFT_PORT"
        return
    fi
    tport=$(head -n 1 /tmp/bmv2-$1-thrift-port)
    sudo $BMV2_PATH/targets/simple_switch/sswitch_CLI --thrift-port $tport
}

echo "table_set_default int_bos int_set_header_7_bos" | p4cli 1
echo "table_set_default int_inst_0003 int_set_header_0003_i15" | p4cli 1
echo "table_set_default int_inst_0407 int_set_header_0407_i15" | p4cli 1
echo "table_set_default int_meta_header_update int_update_total_hop_cnt" | p4cli 1
echo "table_set_default int_outer_encap int_update_udp" | p4cli 1
echo "table_set_default int_insert int_transit 1" | p4cli 1
echo "table_set_default int_bos int_set_header_7_bos" | p4cli 2
echo "table_set_default int_inst_0003 int_set_header_0003_i15" | p4cli 2
echo "table_set_default int_inst_0407 int_set_header_0407_i15" | p4cli 2
echo "table_set_default int_meta_header_update int_update_total_hop_cnt" | p4cli 2
echo "table_set_default int_outer_encap int_update_udp" | p4cli 2
echo "table_set_default int_insert int_transit 2" | p4cli 2
echo "table_set_default int_bos int_set_header_7_bos" | p4cli 3
echo "table_set_default int_inst_0003 int_set_header_0003_i15" | p4cli 3
echo "table_set_default int_inst_0407 int_set_header_0407_i15" | p4cli 3
echo "table_set_default int_meta_header_update int_update_total_hop_cnt" | p4cli 3
echo "table_set_defaulttable_set_default int_outer_encap int_update_udp" | p4cli 3
echo "table_set_default int_insert int_transit 3" | p4cli 3
echo "table_add copy_to_cpu_tb do_copy_to_cpu 0 =>" | p4cli 3
echo "mirroring_add 250 255" | sscli 3
