#include "include/defines.p4"
#include "include/headers.p4"
#include "include/parser.p4"
#include "include/actions.p4"
#include "include/port_counters.p4"

control ingress {
    apply(table0);
    process_port_counters();
}

// control egress {
//     if (standard_metadata.ingress_port != CPU_PORT) {
//         if (standard_metadata.egress_port != CPU_PORT) {
//             if (ethernet.etherType == ETHERTYPE_IPV4) {
//                 if (ipv4.protocol == IP_PROTOCOLS_UDP) {
//                     if(udp.dstPort == UDP_INT_PORT) {
//                          // INT processing 
//                         process_int_insertion();
//                          // update underlay header based on INT information inserted 
//                         process_int_outer_encap();
//                     }
//                 }
//             }
//         }  
//     } 
// }