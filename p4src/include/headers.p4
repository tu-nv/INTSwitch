// header_type intrinsic_metadata_t {
//     fields {
//         ingress_global_timestamp : 48;
//         lf_field_list : 8;
//         mcast_grp : 16;
//         egress_rid : 16;
//         resubmit_flag : 8;
//         recirculate_flag : 8;
//     }
// }

header_type queueing_metadata_t {
    fields {
        enq_timestamp : 48;
        enq_qdepth : 16;
        deq_timedelta : 32;
        deq_qdepth : 16;
    }
}

header_type ethernet_t {
    fields {
        dstAddr : 48;
        srcAddr : 48;
        etherType : 16;
    }
}

header_type ipv4_t {
    fields {
        version : 4;
        ihl : 4;
        diffserv : 8;
        ipv4Len : 16;
        identification : 16;
        flags : 3;
        fragOffset : 13;
        ttl : 8;
        protocol : 8;
        hdrChecksum : 16;
        srcAddr : 32;
        dstAddr: 32;
    }
}

header_type tcp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        seqNo : 32;
        ackNo : 32;
        dataOffset : 4;
        res : 3;
        ecn : 3;
        ctrl : 6;
        window : 16;
        checksum : 16;
        urgentPtr : 16;
    }
}

header_type udp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        udpLen : 16;
        checksum : 16;
    }
}

/*INT header*/
header_type int_header_t {
    fields {
        ver                     : 2;
        rep                     : 2;
        c                       : 1;
        e                       : 1;
        o                       : 1; // sent to onos
        rsvd1                   : 4; // rsvd1 reduced from 5 to 4 bits
        ins_cnt                 : 5;
        max_hop_cnt             : 8;
        total_hop_cnt           : 8;
        instruction_mask_0003   : 4; // split the bits for lookup
        instruction_mask_0407   : 4;
        instruction_mask_0811   : 4;
        instruction_mask_1215   : 4;
        rsvd2                   : 16;
        int_len                 : 16;
        original_port           : 16; // use rsvd2 to store original src/des port of udp/tcp
        // rsvd2                   : 16;
    }
}

header_type int_metadata_t {
    fields {
        switch_id           : 32;
        // insert_cnt          : 8;
        insert_byte_cnt     : 16;
        // instruction_cnt     : 16;
    }
}

// INT meta-value headers - different header for each value type
header_type int_switch_id_header_t {
    fields {
        bos                 : 1;
        switch_id           : 31;
    }
}
header_type int_ingress_port_id_header_t {
    fields {
        bos                 : 1;
        ingress_port_id_1   : 15;
        ingress_port_id_0   : 16;
    }
}
header_type int_hop_latency_header_t {
    fields {
        bos                 : 1;
        hop_latency         : 31;
    }
}
header_type int_q_occupancy_header_t {
    fields {
        bos                 : 1;
        q_occupancy1        : 7;
        q_occupancy0        : 24;
    }
}
header_type int_ingress_tstamp_header_t {
    fields {
        bos                 : 1;
        ingress_tstamp      : 31;
    }
}
header_type int_egress_port_id_header_t {
    fields {
        bos                 : 1;
        egress_port_id      : 31;
    }
}
header_type int_q_congestion_header_t {
    fields {
        bos                 : 1;
        q_congestion        : 31;
    }
}
header_type int_egress_port_tx_utilization_header_t {
    fields {
        bos                         : 1;
        egress_port_tx_utilization  : 31;
    }
}
// generic int value (info) header for extraction
header_type int_value_t {
    fields {
        bos         : 1;
        val         : 31;
    }
}

header_type int_metadata_i2e_t {
    fields {
        source: 1;
        sink: 1;
        origin_port: 16;
        mirror_id: 8;
    }
}

