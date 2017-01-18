metadata int_metadata_i2e_t i2e;


action set_egress_port(port) {
    modify_field(standard_metadata.egress_spec, port);
    // modify_field(standard_metadata.egress_spec, CPU_PORT);
}

action _drop() {
    modify_field(standard_metadata.egress_spec, DROP_PORT);
}

action send_to_cpu() {
    modify_field(standard_metadata.egress_spec, CPU_PORT);
}

action nop() {
}

table table0 {
    reads {
        standard_metadata.ingress_port : ternary;
        ethernet.dstAddr : ternary;
        ethernet.srcAddr : ternary;
        ethernet.etherType : ternary;
    }
    actions {
        set_egress_port;
        send_to_cpu;
        _drop;
    }
    support_timeout: true;
}

counter table0_counter {
    type: packets;
    direct: table0;
    min_width : 32;
}

/* Instr Bit 0 */
action int_set_header_0() { //switch_id
    add_header(int_switch_id_header);
    modify_field(int_switch_id_header.switch_id, int_metadata.switch_id);
}
action int_set_header_1() { //ingress_port_id
    add_header(int_ingress_port_id_header);
    modify_field(int_ingress_port_id_header.ingress_port_id_1, 0);
    modify_field(int_ingress_port_id_header.ingress_port_id_0,
                    standard_metadata.ingress_port);
}
action int_set_header_2() { //hop_latency
    add_header(int_hop_latency_header);
    modify_field(int_hop_latency_header.hop_latency, queueing_metadata.deq_timedelta);
}
action int_set_header_3() { //q_occupancy
    add_header(int_q_occupancy_header);
    modify_field(int_q_occupancy_header.q_occupancy1, 0);
    modify_field(int_q_occupancy_header.q_occupancy0, queueing_metadata.enq_qdepth);
}
action int_set_header_4() { //ingress_tstamp
    add_header(int_ingress_tstamp_header);
    shift_right(int_ingress_tstamp_header.ingress_tstamp, queueing_metadata.enq_timestamp, 16);
}
action int_set_header_5() { //egress_port_id
    add_header(int_egress_port_id_header);
    modify_field(int_egress_port_id_header.egress_port_id,
                    standard_metadata.egress_port);
                    // standard_metadata.egress_spec);
}

action int_set_header_6() { //q_congestion
    add_header(int_q_congestion_header);
    modify_field(int_q_congestion_header.q_congestion, 0x7FFFFFFF);
}
action int_set_header_7() { //egress_port_tx_utilization
    add_header(int_egress_port_tx_utilization_header);
    modify_field(int_egress_port_tx_utilization_header.egress_port_tx_utilization, 0x7FFFFFFF);
}

/* action function for bits 0-3 combinations, 0 is msb, 3 is lsb */
/* Each bit set indicates that corresponding INT header should be added */
action int_set_header_0003_i0() {
}
action int_set_header_0003_i1() {
    int_set_header_3();
}
action int_set_header_0003_i2() {
    int_set_header_2();
}
action int_set_header_0003_i3() {
    int_set_header_3();
    int_set_header_2();
}
action int_set_header_0003_i4() {
    int_set_header_1();
}
action int_set_header_0003_i5() {
    int_set_header_3();
    int_set_header_1();
}
action int_set_header_0003_i6() {
    int_set_header_2();
    int_set_header_1();
}
action int_set_header_0003_i7() {
    int_set_header_3();
    int_set_header_2();
    int_set_header_1();
}
action int_set_header_0003_i8() {
    int_set_header_0();
}
action int_set_header_0003_i9() {
    int_set_header_3();
    int_set_header_0();
}
action int_set_header_0003_i10() {
    int_set_header_2();
    int_set_header_0();
}
action int_set_header_0003_i11() {
    int_set_header_3();
    int_set_header_2();
    int_set_header_0();
}
action int_set_header_0003_i12() {
    int_set_header_1();
    int_set_header_0();
}
action int_set_header_0003_i13() {
    int_set_header_3();
    int_set_header_1();
    int_set_header_0();
}
action int_set_header_0003_i14() {
    int_set_header_2();
    int_set_header_1();
    int_set_header_0();
}
action int_set_header_0003_i15() {
    int_set_header_3();
    int_set_header_2();
    int_set_header_1();
    int_set_header_0();
}

/* Table to process instruction bits 0-3 */
table tb_int_inst_0003 {
    reads {
        int_header.instruction_mask_0003 : exact;
    }
    actions {
        int_set_header_0003_i0;
        int_set_header_0003_i1;
        int_set_header_0003_i2;
        int_set_header_0003_i3;
        int_set_header_0003_i4;
        int_set_header_0003_i5;
        int_set_header_0003_i6;
        int_set_header_0003_i7;
        int_set_header_0003_i8;
        int_set_header_0003_i9;
        int_set_header_0003_i10;
        int_set_header_0003_i11;
        int_set_header_0003_i12;
        int_set_header_0003_i13;
        int_set_header_0003_i14;
        int_set_header_0003_i15;
    }

    // size: 17;
}

/* action function for bits 4-7 combinations, 4 is msb, 7 is lsb */
action int_set_header_0407_i0() {
}
action int_set_header_0407_i1() {
    int_set_header_7();
}
action int_set_header_0407_i2() {
    int_set_header_6();
}
action int_set_header_0407_i3() {
    int_set_header_7();
    int_set_header_6();
}
action int_set_header_0407_i4() {
    int_set_header_5();
}
action int_set_header_0407_i5() {
    int_set_header_7();
    int_set_header_5();
}
action int_set_header_0407_i6() {
    int_set_header_6();
    int_set_header_5();
}
action int_set_header_0407_i7() {
    int_set_header_7();
    int_set_header_6();
    int_set_header_5();
}
action int_set_header_0407_i8() {
    int_set_header_4();
}
action int_set_header_0407_i9() {
    int_set_header_7();
    int_set_header_4();
}
action int_set_header_0407_i10() {
    int_set_header_6();
    int_set_header_4();
}
action int_set_header_0407_i11() {
    int_set_header_7();
    int_set_header_6();
    int_set_header_4();
}
action int_set_header_0407_i12() {
    int_set_header_5();
    int_set_header_4();
}
action int_set_header_0407_i13() {
    int_set_header_7();
    int_set_header_5();
    int_set_header_4();
}
action int_set_header_0407_i14() {
    int_set_header_6();
    int_set_header_5();
    int_set_header_4();
}
action int_set_header_0407_i15() {
    int_set_header_7();
    int_set_header_6();
    int_set_header_5();
    int_set_header_4();
}

/* Table to process instruction bits 4-7 */
table tb_int_inst_0407 {
    reads {
        int_header.instruction_mask_0407 : exact;
    }
    actions {
        int_set_header_0407_i0;
        int_set_header_0407_i1;
        int_set_header_0407_i2;
        int_set_header_0407_i3;
        int_set_header_0407_i4;
        int_set_header_0407_i5;
        int_set_header_0407_i6;
        int_set_header_0407_i7;
        int_set_header_0407_i8;
        int_set_header_0407_i9;
        int_set_header_0407_i10;
        int_set_header_0407_i11;
        int_set_header_0407_i12;
        int_set_header_0407_i13;
        int_set_header_0407_i14;
        int_set_header_0407_i15;
    }

    // size: 17;
}

/* BOS bit - set for the bottom most header added by INT src device */
action int_set_header_0_bos() { //switch_id
    modify_field(int_switch_id_header.bos, 1);
}
action int_set_header_1_bos() { //ingress_port_id
    modify_field(int_ingress_port_id_header.bos, 1);
}
action int_set_header_2_bos() { //hop_latency
    modify_field(int_hop_latency_header.bos, 1);
}
action int_set_header_3_bos() { //q_occupancy
    modify_field(int_q_occupancy_header.bos, 1);
}
action int_set_header_4_bos() { //ingress_tstamp
    modify_field(int_ingress_tstamp_header.bos, 1);
}
action int_set_header_5_bos() { //egress_port_id
    modify_field(int_egress_port_id_header.bos, 1);
}
action int_set_header_6_bos() { //q_congestion
    modify_field(int_q_congestion_header.bos, 1);
}
action int_set_header_7_bos() {
    modify_field(int_egress_port_tx_utilization_header.bos, 1);
}

table tb_int_bos {
    reads {
        // use table apply condition at source instead
        // int_header.total_hop_cnt            : ternary;
        int_header.instruction_mask_0003    : ternary;
        int_header.instruction_mask_0407    : ternary;
        // two below are reserved for now
        // int_header.instruction_mask_0811    : ternary;
        // int_header.instruction_mask_1215    : ternary;
    }
    actions {
        int_set_header_0_bos;
        int_set_header_1_bos;
        int_set_header_2_bos;
        int_set_header_3_bos;
        int_set_header_4_bos;
        int_set_header_5_bos;
        int_set_header_6_bos;
        int_set_header_7_bos;
        nop;
    }
    // size : 17;
}


action int_update_total_hop_cnt() {
    add_to_field(int_header.total_hop_cnt, 1);
    add_to_field(int_header.int_len, int_metadata.insert_byte_cnt);
}

table tb_int_meta_header_update {
    actions {
        int_update_total_hop_cnt;
    }
    // size: 1;
}

action int_transit(switch_id) {
    // subtract(int_metadata.insert_cnt, int_header.max_hop_cnt,
    //                                         int_header.total_hop_cnt);
    modify_field(int_metadata.switch_id, switch_id);
    shift_left(int_metadata.insert_byte_cnt, int_header.ins_cnt, 2);
    // shift_left(int_metadata.insert_byte_cnt, 8, 2); // temporary
}

table tb_int_insert {
    actions {
        int_transit;
    }
    // size: 1;
}

control process_int_transit {
    // if (udp.dstPort == UDP_INT_PORT) {
        // if (standard_metadata.instance_type != 2) {
            if (i2e.sink == 0) {
                apply(tb_int_insert);
                apply(tb_int_inst_0003);
                apply(tb_int_inst_0407);
                if (i2e.source == 1) {
                    // only apply at source
                    apply(tb_int_bos);
                }
                apply(tb_int_meta_header_update);
            }
        // }    
    // }
}

action int_update_udp() {
    add_to_field(ipv4.ipv4Len, int_metadata.insert_byte_cnt);
    add_to_field(udp.udpLen, int_metadata.insert_byte_cnt);
}
table tb_int_outer_encap {
    // should read field, not header ?
    // reads {
    //     ipv4 : valid;
    //     udp : valid;
    // }
    actions {
        int_update_udp;
    }
    // size: 1;
}

control process_int_outer_encap {
    // if (udp.dstPort == UDP_INT_PORT) {
        // if (standard_metadata.instance_type != 2) {
            apply(tb_int_outer_encap);
        // }
    // }
}
//-----------------------------------Mirror------------------------------------

action int_to_onos() {
    // truncate(trunc_length);
    // truncate(0xFFFF);
    modify_field(int_header.o, 1);
}

// action set_o_bit() {
// }
table tb_int_to_onos {
    reads {
        standard_metadata.instance_type: exact;
        // i2e.mirror_id: exact;
        // use int_len to decide how much to truncated
        // int_header.int_len: exact;
    }
    actions {
        int_to_onos; // id=CPU_MIRROR_SESSION_ID & instance_type=1 
        // set_o_bit;
    }
    // size: 1;
}
control process_int_to_onos {
    // cloned pkt
    // if (standard_metadata.instance_type == 1) {
    if (valid(int_header)) {
        apply(tb_int_to_onos);
    }
    // }
}

#define CPU_MIRROR_SESSION_ID 250
field_list copy_to_cpu_fields {
    i2e.mirror_id;
    // i2e.source;
}

action mirror_int_to_cpu() {
    // modify_field(i2e.mirror_id, CPU_MIRROR_SESSION_ID);
    clone_ingress_pkt_to_egress(CPU_MIRROR_SESSION_ID, copy_to_cpu_fields);
}

table tb_mirror_int_to_cpu {
    actions {
        mirror_int_to_cpu;
    }
    // size: 1;
}

control process_mirror_to_cpu {
    if (standard_metadata.ingress_port != CPU_PORT) {
        if (ethernet.etherType == ETHERTYPE_IPV4) {
            if (ipv4.protocol == IP_PROTOCOLS_UDP) {
                if(udp.dstPort == UDP_INT_PORT) {
                    // if (valid (int_header)) { // error also?
                        apply(tb_mirror_int_to_cpu);
                    // }
                }
            }
        }
    }
}
//---------------------------Set INT source or Sink----------------------------

action int_set_source () {
    modify_field(i2e.source, 1);
}

// action int_clear_source () {
//     modify_field(i2e.source, 0);
// }

action int_set_sink () {
    // set sink
    modify_field(i2e.sink, 1);
    
}

// action int_clear_sink () {
//     modify_field(i2e.sink, 0);
// }

table tb_set_source_sink {
    actions {
        int_set_source;
        int_set_sink;
        nop;
    }
}
control process_set_source_sink {
    apply(tb_set_source_sink);
}

//-----------------------------Process int source------------------------------
control process_int_source {
    // if (not valid(int_header)) {
        // if (i2e.sink == 0) {
        //     if (i2e.source == 1) {
                apply(tb_int_source);
        //     }
        // }
    // } 
}

table tb_int_source {
    reads {
        i2e.sink: exact;
        i2e.source: exact;
    }
    actions {
        int_source; // sink = 0 & source = 1
    }
    // size: 1;
}
action int_source(max_hop, ins_cnt, ins_mask0003, ins_mask0407) {
    // modify_field(int_metadata.insert_cnt, max_hop);
    // modify_field(int_metadata.switch_id, switch_id); // do it in int_transit
    // modify_field(int_metadata.insert_byte_cnt, ins_byte_cnt);

    // add the header len (8 bytes) to total len
    add_to_field(ipv4.ipv4Len, 12);
    add_to_field(udp.udpLen, 12);

    add_header(int_header);

    modify_field(int_header.ver, 0);
    modify_field(int_header.rep, 0);
    modify_field(int_header.c, 0);
    modify_field(int_header.e, 0);
    modify_field(int_header.o, 0);
    modify_field(int_header.ins_cnt, ins_cnt);
    modify_field(int_header.max_hop_cnt, max_hop);
    modify_field(int_header.total_hop_cnt, 0);
    modify_field(int_header.instruction_mask_0003, ins_mask0003);
    modify_field(int_header.instruction_mask_0407, ins_mask0407);
    modify_field(int_header.instruction_mask_0811, 0); // not supported
    modify_field(int_header.instruction_mask_1215, 0); // not supported
    modify_field(int_header.rsvd1, 0);
    modify_field(int_header.rsvd2, 0);

    modify_field(int_header.int_len, 12); //starting value as int header len //3
    modify_field(int_header.original_port, udp.dstPort);
    modify_field(udp.dstPort, UDP_INT_PORT);
}

//------------------------------Process int sink-------------------------------
action int_sink() {
    // restore original dst port
    modify_field(i2e.origin_port, int_header.original_port);
    // remove all the INT information from the packet
    // max 24 headers are supported
    remove_header(int_header);
    remove_header(int_val[0]);
    remove_header(int_val[1]);
    remove_header(int_val[2]);
    remove_header(int_val[3]);
    remove_header(int_val[4]);
    remove_header(int_val[5]);
    remove_header(int_val[6]);
    remove_header(int_val[7]);
    remove_header(int_val[8]);
    remove_header(int_val[9]);
    remove_header(int_val[10]);
    remove_header(int_val[11]);
    remove_header(int_val[12]);
    remove_header(int_val[13]);
    remove_header(int_val[14]);
    remove_header(int_val[15]);
    remove_header(int_val[16]);
    remove_header(int_val[17]);
    remove_header(int_val[18]);
    remove_header(int_val[19]);
    remove_header(int_val[20]);
    remove_header(int_val[21]);
    remove_header(int_val[22]);
    remove_header(int_val[23]);
    // remove int header
    subtract_from_field(ipv4.ipv4Len, int_header.int_len); 
    subtract_from_field(udp.udpLen, int_header.int_len);
}

table tb_int_sink {
    reads {
        i2e.sink: exact;
    }
    actions {
        int_sink;
    }
    // size: 1;
}

control process_int_sink {
    apply (tb_int_sink);
}
//----------------------------restore original port----------------------------
action restore_port () {
    modify_field(udp.dstPort, i2e.origin_port);
}

table tb_restore_port {
    actions {
        restore_port;
    }
}

control process_restore_port {
    if (i2e.sink == 1) {
        apply (tb_restore_port);
    }
}