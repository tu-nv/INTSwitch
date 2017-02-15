#include "include/defines.p4"
#include "include/headers.p4"
#include "include/parser.p4"
#include "include/actions.p4"
#include "include/port_counters.p4"

control ingress {
    apply(table0);
    process_port_counters();

    // process_mirror_to_cpu();
    // process_set_first_sw();
    // process_set_source_sink();
}

// control egress {
//     // apply(mirror_execute); // test

//     if (standard_metadata.ingress_port != CPU_PORT) {
//         // if (ethernet.etherType == ETHERTYPE_IPV4) {
//         //     if (ipv4.protocol == IP_PROTOCOLS_UDP) {
//         if (valid(udp)){
//                 // 1: ingress cloned
//                 if ((standard_metadata.egress_port != CPU_PORT) or (standard_metadata.instance_type == 1)) {
//                     // int source
//                     process_int_source();

//                     if(udp.dstPort == UDP_INT_PORT) {
//                     // if(valid(int_header)) {
//                         // INT processing 
//                         process_int_transit();
//                         // update underlay header based on INT information inserted 
//                         process_int_outer_encap();
//                         // int sink
//                         process_int_sink();

//                     }

//                     process_restore_port();
                    
//                 }
//             }
//         // }  
//     } 
//                 process_int_to_onos();
// }