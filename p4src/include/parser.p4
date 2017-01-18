// two metadata types supported by BMv2 simple switch
// metadata intrinsic_metadata_t intrinsic_metadata;
metadata queueing_metadata_t queueing_metadata;

parser start {
    return parse_ethernet;
}

#define ETHERTYPE_IPV4 0x0800

header ethernet_t ethernet;

parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
        ETHERTYPE_IPV4 : parse_ipv4;
        default : ingress;
    }
}

header ipv4_t ipv4;

#define IP_PROTOCOLS_TCP  6
#define IP_PROTOCOLS_UDP  17

parser parse_ipv4 {
    extract(ipv4);
    return select(latest.fragOffset, latest.protocol) {
        IP_PROTOCOLS_TCP : parse_tcp;
        IP_PROTOCOLS_UDP : parse_udp;
        default: ingress;
    }
}

header tcp_t tcp;

parser parse_tcp {
    extract(tcp);
    return ingress;
}

// #define UDP_INT_PORT 54321

header udp_t udp;

parser parse_udp {
    extract(udp);
    // return select(udp.udpLen) {
    return select(latest.dstPort) {
        UDP_INT_PORT: parse_int_header;
        
        default: ingress;
    }
}

header int_header_t                             int_header;
header int_switch_id_header_t                   int_switch_id_header;
header int_ingress_port_id_header_t             int_ingress_port_id_header;
header int_hop_latency_header_t                 int_hop_latency_header;
header int_q_occupancy_header_t                 int_q_occupancy_header;
header int_ingress_tstamp_header_t              int_ingress_tstamp_header;
header int_egress_port_id_header_t              int_egress_port_id_header;
header int_q_congestion_header_t                int_q_congestion_header;
header int_egress_port_tx_utilization_header_t  int_egress_port_tx_utilization_header;

metadata int_metadata_t int_metadata;

parser parse_int_header {
    extract (int_header);
    // set_metadata(int_metadata.instruction_cnt, latest.ins_cnt);
    // set_metadata(i2e.int_len, latest.int_len);
    return select (latest.rsvd1, latest.total_hop_cnt) {
        // reserved bits = 0 and total_hop_cnt == 0
        // no int_values are added by upstream
        0x000: ingress;
        // parse INT val headers added by upstream devices (total_hop_cnt != 0)
        // reserved bits must be 0
        //// new header is put on top of other by default (see add_header
        // in specification)
        0x000 mask 0xf00: parse_int_val;
        //// 0 mask 0: always true
        0 mask 0: ingress;
        // never transition to the following state (1 mask 0 always false)
        1 mask 0: parse_all_int_meta_value_headers;
    }
}

#define MAX_INT_INFO 24
header int_value_t int_val[MAX_INT_INFO];

parser parse_int_val {
    extract(int_val[next]);
    return select(latest.bos) {
        0 : parse_int_val;
        1 : ingress;
    }
}

parser parse_all_int_meta_value_headers {
    // bogus state.. just extract all possible int headers in the
    // correct order to build
    // the correct parse graph for deparser (while adding headers)
    extract(int_switch_id_header);
    extract(int_ingress_port_id_header);
    extract(int_hop_latency_header);
    extract(int_q_occupancy_header);
    extract(int_ingress_tstamp_header);
    extract(int_egress_port_id_header);
    extract(int_q_congestion_header);
    extract(int_egress_port_tx_utilization_header);
    return ingress;
}

