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
action int_set_header_0003_i15() {
    int_set_header_3();
    int_set_header_2();
    int_set_header_1();
    int_set_header_0();
}

/* Table to process instruction bits 0-3 */
table int_inst_0003 {
    // reads {
    //     int_header.instruction_mask_0003 : exact;
    // }
    actions {
        int_set_header_0003_i15;
    }
}

/* action function for bits 4-7 combinations, 4 is msb, 7 is lsb */
action int_set_header_0407_i15() {
    int_set_header_7();
    int_set_header_6();
    int_set_header_5();
    int_set_header_4();
}

/* Table to process instruction bits 4-7 */
table int_inst_0407 {
    // reads {
    //     int_header.instruction_mask_0407 : exact;
    // }
    actions {
        int_set_header_0407_i15;
    }
}

/* BOS bit - set for the bottom most header added by INT src device */
action int_set_header_7_bos() {
    modify_field(int_egress_port_tx_utilization_header.bos, 1);
}

table int_bos {
    // reads {
        // int_header.total_hop_cnt            : ternary;
        // int_header.instruction_mask_0003    : ternary;
        // int_header.instruction_mask_0407    : ternary;
        // int_header.instruction_mask_0811    : ternary;
        // int_header.instruction_mask_1215    : ternary;
    // }
    actions {
        int_set_header_7_bos;
    }
}

action int_update_total_hop_cnt() {
    add_to_field(int_header.total_hop_cnt, 1);
}

table int_meta_header_update {
    actions {
        int_update_total_hop_cnt;
    }
}

action int_transit(switch_id) {
    subtract(int_metadata.insert_cnt, int_header.max_hop_cnt,
                                            int_header.total_hop_cnt);
    modify_field(int_metadata.switch_id, switch_id);
    // shift_left(int_metadata.insert_byte_cnt, int_metadata.instruction_cnt, 2);
    // shift_left(int_metadata.insert_byte_cnt, 8, 2); // temporary
}

table int_insert {
    actions {
        int_transit;
    }
}

#define UDP_INT_PORT 54321

control process_int_insertion {
	if (udp.dstPort == UDP_INT_PORT) {
		if (standard_metadata.instance_type != 2) {
	    	apply(int_insert);
            apply(int_inst_0003);
            apply(int_inst_0407);
            apply(int_bos);
            apply(int_meta_header_update);
	    }	
    }
}

action int_update_udp() {
    add_to_field(ipv4.ipv4Len, int_metadata.insert_byte_cnt);
    add_to_field(udp.udpLen, int_metadata.insert_byte_cnt);
}
table int_outer_encap {
    // should read field, not header ?
    // reads {
    //     ipv4 : valid;
    //     udp : valid;
    // }
    actions {
        int_update_udp;
    }
}

#define CPU_MIRROR_SESSION_ID 250

field_list copy_to_cpu_fields {
    standard_metadata;
    // e2e_metadata.session_id;
}

action do_copy_to_cpu() {
    clone_egress_pkt_to_egress(CPU_MIRROR_SESSION_ID, copy_to_cpu_fields);
}

table mirror_int_to_cpu {
	reads {
		standard_metadata.instance_type : exact;
	}
    actions {
        do_copy_to_cpu;
    }
}

control process_int_outer_encap {
	if (udp.dstPort == UDP_INT_PORT) {
		apply(mirror_int_to_cpu);
		if (standard_metadata.instance_type != 2) {
        	apply(int_outer_encap);
        }
    }
}