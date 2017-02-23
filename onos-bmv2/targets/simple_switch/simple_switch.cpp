/* Copyright 2013-present Barefoot Networks, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Antonin Bas (antonin@barefootnetworks.com)
 *
 */

#include <bm/bm_sim/parser.h>
#include <bm/bm_sim/tables.h>
#include <bm/bm_sim/logger.h>

#include <unistd.h>

#include <iostream>
#include <fstream>
#include <string>
#include <boost/thread/lock_types.hpp>

#include "simple_switch.h"

namespace {

struct hash_ex {
  uint32_t operator()(const char *buf, size_t s) const {
    const int p = 16777619;
    int hash = 2166136261;

    for (size_t i = 0; i < s; i++)
      hash = (hash ^ buf[i]) * p;

    hash += hash << 13;
    hash ^= hash >> 7;
    hash += hash << 3;
    hash ^= hash >> 17;
    hash += hash << 5;
    return static_cast<uint32_t>(hash);
  }
};

struct bmv2_hash {
  uint64_t operator()(const char *buf, size_t s) const {
    return bm::hash::xxh64(buf, s);
  }
};

}  // namespace

// if REGISTER_HASH calls placed in the anonymous namespace, some compiler can
// give an unused variable warning
REGISTER_HASH(hash_ex);
REGISTER_HASH(bmv2_hash);

extern int import_primitives();

SimpleSwitch::SimpleSwitch(int max_port, bool enable_swap)
  : Switch(enable_swap),
    max_port(max_port),
    input_buffer(1024),
#ifdef SSWITCH_PRIORITY_QUEUEING_ON
    egress_buffers(max_port, nb_egress_threads,
                   64, EgressThreadMapper(nb_egress_threads),
                   SSWITCH_PRIORITY_QUEUEING_NB_QUEUES),
#else
    egress_buffers(max_port, nb_egress_threads,
                   64, EgressThreadMapper(nb_egress_threads)),
#endif
    output_buffer(128),
    pre(new McSimplePreLAG()),
    start(clock::now())
    {
  add_component<McSimplePreLAG>(pre);

  add_required_field("standard_metadata", "ingress_port");
  add_required_field("standard_metadata", "packet_length");
  add_required_field("standard_metadata", "instance_type");
  add_required_field("standard_metadata", "egress_spec");
  add_required_field("standard_metadata", "clone_spec");

  force_arith_field("standard_metadata", "ingress_port");
  force_arith_field("standard_metadata", "packet_length");
  force_arith_field("standard_metadata", "instance_type");
  force_arith_field("standard_metadata", "egress_spec");
  force_arith_field("standard_metadata", "clone_spec");

  force_arith_field("queueing_metadata", "enq_timestamp");
  force_arith_field("queueing_metadata", "enq_qdepth");
  force_arith_field("queueing_metadata", "deq_timedelta");
  force_arith_field("queueing_metadata", "deq_qdepth");
  // Tunv
  force_arith_field("queueing_metadata", "deq_qcongestion");
  force_arith_field("queueing_metadata", "tx_utilization");

  force_arith_field("intrinsic_metadata", "ingress_global_timestamp");
  force_arith_field("intrinsic_metadata", "lf_field_list");
  force_arith_field("intrinsic_metadata", "mcast_grp");
  force_arith_field("intrinsic_metadata", "resubmit_flag");
  force_arith_field("intrinsic_metadata", "egress_rid");
  force_arith_field("intrinsic_metadata", "recirculate_flag");

  import_primitives();
}

void
SimpleSwitch::init_cp_client(std::string controller_ip, uint32_t controller_port) {
  BMLOG_DEBUG("Initializing control plane service Thrift client: addr={}, port={}...", controller_ip, controller_port);
  cp_addr = controller_ip;
  cp_port = controller_port;
  auto cp_socket = boost::shared_ptr<TTransport>(new TSocket(cp_addr, cp_port));
  cp_transport = boost::shared_ptr<TTransport>(new TFramedTransport(cp_socket));
  auto cp_protocol = boost::shared_ptr<TProtocol>(new TBinaryProtocol(cp_transport));
  cp_client = boost::shared_ptr<ControlPlaneServiceClient>(new ControlPlaneServiceClient(cp_protocol));
}

int
SimpleSwitch::receive(int port_num, const char *buffer, int len) {
  static int pkt_id = 0;

  // this is a good place to call this, because blocking this thread will not
  // block the processing of existing packet instances, which is a requirement
  if (do_swap() == 0) {
    do_hello();
    check_queueing_metadata();
  }

  // we limit the packet buffer to original size + 512 bytes, which means we
  // cannot add more than 512 bytes of header data to the packet, which should
  // be more than enough
  auto packet = new_packet_ptr(port_num, pkt_id++, len,
                               bm::PacketBuffer(len + 512, buffer, len));

  BMELOG(packet_in, *packet);

  PHV *phv = packet->get_phv();
  // many current P4 programs assume this
  // it is also part of the original P4 spec
  phv->reset_metadata();

  // setting standard metadata
  phv->get_field("standard_metadata.ingress_port").set(port_num);
  phv->get_field("standard_metadata.packet_length").set(len);
  Field &f_instance_type = phv->get_field("standard_metadata.instance_type");
  f_instance_type.set(PKT_INSTANCE_TYPE_NORMAL);

  if (phv->has_field("intrinsic_metadata.ingress_global_timestamp")) {
    phv->get_field("intrinsic_metadata.ingress_global_timestamp")
        .set(get_ts().count());
  }

  input_buffer.push_front(std::move(packet));
  return 0;
}

void
SimpleSwitch::packet_out(const int32_t port, const std::string& data) {
  BMLOG_DEBUG("Received packet-out from control plane, transmitting packet of size {} out of port {}",
              data.size(), port);
  boost::unique_lock<boost::mutex> lock(tx_mutex);
  transmit_fn(port, data.c_str(), data.size());
  lock.unlock();
}

void
SimpleSwitch::force_swap() {
  BMLOG_DEBUG("Forcing configuration swap...");
  if (do_swap() == 0) {
    do_hello();
    check_queueing_metadata();
  }
}

// TU
// void SimpleSwitch::reset_num_enq_pkts_map() {
//   for (int i = 0; i < max_port; i++) {
//     num_enq_pkts_map[i] = 0;
//   }
// }
// TU
void SimpleSwitch::timer_thread(){
  // std::thread([this, interval, reset_num_enq_pkts_map]()
  // {
  //   while (true) {
  //     reset_num_enq_pkts_map();                   
  //     std::this_thread::sleep_for(
  //     std::chrono::milliseconds(interval));
  //   }
  // }).detach();
  while (true) {
    boost::unique_lock<boost::mutex> lock(tx_mutex);
    for (int i = 0; i < max_port; i++) {
      tx_utilization[i] = (tx_bytes_in_period[i] >> 7) & 0x7FFFFFFF; // (10 - 3 + 2) byte to Kbit, 4s;
      tx_bytes_in_period[i] = 0;
    }                  
    lock.unlock();

    std::this_thread::sleep_for(
    std::chrono::milliseconds(1000));
  }
}

void
SimpleSwitch::start_and_return() {

  // TU: init map
  for (int i = 0; i < max_port; i++) {
    // last_time_map.insert(std::pair<int, clock::time_point>(i, clock::now()));
    // num_enq_pkts_map.insert(std::pair<int, int>(i, 0));
    tx_utilization.insert(std::pair<int, int>(i, 0));
    tx_bytes_in_period.insert(std::pair<int, long>(i, 0));
  }
  
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  process_instance_id = tv.tv_sec * 1000 + tv.tv_usec / 1000;

  check_queueing_metadata();

  std::thread t1(&SimpleSwitch::ingress_thread, this);
  t1.detach();
  for (size_t i = 0; i < nb_egress_threads; i++) {
    std::thread t2(&SimpleSwitch::egress_thread, this, i);
    t2.detach();
  }
  std::thread t3(&SimpleSwitch::transmit_thread, this);
  t3.detach();
  std::thread t4(&SimpleSwitch::hello_thread, this);
  t4.detach();
  //TU
  std::thread t5(&SimpleSwitch::timer_thread, this);
  t5.detach();
}

void
SimpleSwitch::reset_target_state() {
  bm::Logger::get()->debug("Resetting simple_switch target-specific state");
  get_component<McSimplePreLAG>()->reset_state();
}

int
SimpleSwitch::set_egress_queue_depth(int port, const size_t depth_pkts) {
  egress_buffers.set_capacity(port, depth_pkts);
  return 0;
}

int
SimpleSwitch::set_all_egress_queue_depths(const size_t depth_pkts) {
  for (int i = 0; i < max_port; i++) {
    set_egress_queue_depth(i, depth_pkts);
  }
  // capacity_all = depth_pkts;
  // capacity_log2 = (uint32_t) log2(capacity_all);
  return 0;
}

int
SimpleSwitch::set_egress_queue_rate(int port, const uint64_t rate_pps) {
  egress_buffers.set_rate(port, rate_pps);
  return 0;
}

int
SimpleSwitch::set_all_egress_queue_rates(const uint64_t rate_pps) {
  for (int i = 0; i < max_port; i++) {
    set_egress_queue_rate(i, rate_pps);
  }
  return 0;
}

void
SimpleSwitch::transmit_thread() {

  while (1) {
    std::unique_ptr<Packet> packet;
    output_buffer.pop_back(&packet);
    BMELOG(packet_out, *packet);

    if (packet->get_egress_port() == 255) {
      BMLOG_DEBUG("Egress port is 255, sending packet-in to control plane");
      try {
        if (!cp_transport->isOpen()) {
          cp_transport->open();
        }
        std::string body(packet->data(), packet->get_data_size());
        cp_client->packet_in(packet->get_ingress_port(), std::move(body), body.size());
      } catch (TException &tx) {
        BMLOG_DEBUG("Exception while sending packet to control plane: {}", tx.what());
      }

    } else {
      BMLOG_DEBUG_PKT(*packet, "Transmitting packet of size {} out of port {}",
                      packet->get_data_size(), packet->get_egress_port());
      boost::unique_lock<boost::mutex> lock(tx_mutex);
      transmit_fn(packet->get_egress_port(),
                  packet->data(), packet->get_data_size());
      lock.unlock();
    }
  }
}

void
SimpleSwitch::do_hello() {
  try {
    if (!cp_transport->isOpen()) {
      cp_transport->open();
    }
    BMLOG_DEBUG("Sending hello to {}:{}: runtimePort={}, deviceId={}, instanceId={}, configMd5={}...",
                cp_addr, cp_port, this->get_runtime_port(), this->get_device_id(), this->get_process_instance_id(),
                this->get_config_md5());
    cp_client->hello(this->get_runtime_port(), this->get_device_id(),
                    this->get_process_instance_id(), this->get_config_md5());
  } catch (TException &tx) {
    BMLOG_DEBUG("Exception while sending hello: {}", tx.what());
  }
}

void
SimpleSwitch::hello_thread() {
  while (1) {
    do_hello();
    sleep(5);
  }
}

ts_res
SimpleSwitch::get_ts() const {
  return duration_cast<ts_res>(clock::now() - start);
}

void
SimpleSwitch::enqueue(int egress_port, std::unique_ptr<Packet> &&packet) {
    packet->set_egress_port(egress_port);

    PHV *phv = packet->get_phv();

    // // TU
    // clock::time_point time_now = clock::now();
    // // unit: microseconds
    // if (duration_cast<ts_res>(time_now - last_time_map[egress_port]).count() > 1000000) {
    //     tx_utilization[egress_port] = num_enq_pkts_map[egress_port];
    //     num_enq_pkts_map[egress_port] = 0;
    //     last_time_map[egress_port] = time_now;
    // } else {
    //   // num_enq_pkts_map[egress_port]++;
    //   num_enq_pkts_map[egress_port] += packet->get_data_size();
    // }

    if (with_queueing_metadata) {
      phv->get_field("queueing_metadata.enq_timestamp").set(get_ts().count());
      phv->get_field("queueing_metadata.enq_qdepth")
          .set(egress_buffers.size(egress_port));
      // // TU
      // phv->get_field("queueing_metadata.deq_qcongestion").set(
      //     egress_buffers.size(egress_port)*1000/capacity_all);
      // phv->get_field("queueing_metadata.tx_utilization").set(
      //     (tx_utilization[egress_port] >> (10 - 3)) & 0x7FFFFFFF); // byte to Kbit
    }

#ifdef SSWITCH_PRIORITY_QUEUEING_ON
    size_t priority =
        phv->get_field(SSWITCH_PRIORITY_QUEUEING_SRC).get<size_t>();
    if (priority >= SSWITCH_PRIORITY_QUEUEING_NB_QUEUES) {
      bm::Logger::get()->error("Priority out of range, dropping packet");
      return;
    }
    egress_buffers.push_front(
        egress_port, SSWITCH_PRIORITY_QUEUEING_NB_QUEUES - 1 - priority,
        std::move(packet));
#else
    egress_buffers.push_front(egress_port, std::move(packet));
#endif
}

// used for ingress cloning, resubmit
std::unique_ptr<Packet>
SimpleSwitch::copy_ingress_pkt(
    const std::unique_ptr<Packet> &packet,
    PktInstanceType copy_type, p4object_id_t field_list_id) {
  std::unique_ptr<Packet> packet_copy = packet->clone_no_phv_ptr();
  PHV *phv_copy = packet_copy->get_phv();
  phv_copy->reset_metadata();
  FieldList *field_list = this->get_field_list(field_list_id);
  const PHV *phv = packet->get_phv();
  for (const auto &p : *field_list) {
    phv_copy->get_field(p.header, p.offset)
        .set(phv->get_field(p.header, p.offset));
  }
  phv_copy->get_field("standard_metadata.instance_type").set(copy_type);
  return packet_copy;
}

void
SimpleSwitch::check_queueing_metadata() {
  bool enq_timestamp_e = field_exists("queueing_metadata", "enq_timestamp");
  bool enq_qdepth_e = field_exists("queueing_metadata", "enq_qdepth");
  bool deq_timedelta_e = field_exists("queueing_metadata", "deq_timedelta");
  bool deq_qdepth_e = field_exists("queueing_metadata", "deq_qdepth");
  bool deq_qcongestion_e = field_exists("queueing_metadata", "deq_qcongestion");
  bool tx_utilization_e = field_exists("queueing_metadata", "tx_utilization");

  if (enq_timestamp_e || enq_qdepth_e || deq_timedelta_e || deq_qdepth_e) {
    if (enq_timestamp_e && enq_qdepth_e && deq_timedelta_e && deq_qdepth_e
        && deq_qcongestion_e && tx_utilization_e)
      with_queueing_metadata = true;
    else
      bm::Logger::get()->warn(
          "Your JSON input defines some but not all queueing metadata fields");
  }
}

void
SimpleSwitch::ingress_thread() {
  PHV *phv;

  while (1) {
    std::unique_ptr<Packet> packet;
    input_buffer.pop_back(&packet);

    // TODO(antonin): only update these if swapping actually happened?
    Parser *parser = this->get_parser("parser");
    Pipeline *ingress_mau = this->get_pipeline("ingress");

    phv = packet->get_phv();

    int ingress_port = packet->get_ingress_port();
    (void) ingress_port;
    BMLOG_DEBUG_PKT(*packet, "Processing packet received on port {}",
                    ingress_port);

    /* This looks like it comes out of the blue. However this is needed for
       ingress cloning. The parser updates the buffer state (pops the parsed
       headers) to make the deparser's job easier (the same buffer is
       re-used). But for ingress cloning, the original packet is needed. This
       kind of looks hacky though. Maybe a better solution would be to have the
       parser leave the buffer unchanged, and move the pop logic to the
       deparser. TODO? */
    const Packet::buffer_state_t packet_in_state = packet->save_buffer_state();
    parser->parse(packet.get());

    ingress_mau->apply(packet.get());

    packet->reset_exit();

    Field &f_egress_spec = phv->get_field("standard_metadata.egress_spec");
    int egress_spec = f_egress_spec.get_int();

    Field &f_clone_spec = phv->get_field("standard_metadata.clone_spec");
    unsigned int clone_spec = f_clone_spec.get_uint();

    int learn_id = 0;
    unsigned int mgid = 0u;

    if (phv->has_field("intrinsic_metadata.lf_field_list")) {
      Field &f_learn_id = phv->get_field("intrinsic_metadata.lf_field_list");
      learn_id = f_learn_id.get_int();
    }

    // detect mcast support, if this is true we assume that other fields needed
    // for mcast are also defined
    if (phv->has_field("intrinsic_metadata.mcast_grp")) {
      Field &f_mgid = phv->get_field("intrinsic_metadata.mcast_grp");
      mgid = f_mgid.get_uint();
    }

    int egress_port;

    // INGRESS CLONING
    if (clone_spec) {
      BMLOG_DEBUG_PKT(*packet, "Cloning packet at ingress");
      egress_port = get_mirroring_mapping(clone_spec & 0xFFFF);
      f_clone_spec.set(0);
      if (egress_port >= 0) {
        const Packet::buffer_state_t packet_out_state =
            packet->save_buffer_state();
        packet->restore_buffer_state(packet_in_state);
        p4object_id_t field_list_id = clone_spec >> 16;
        auto packet_copy = copy_ingress_pkt(
            packet, PKT_INSTANCE_TYPE_INGRESS_CLONE, field_list_id);
        // we need to parse again
        // the alternative would be to pay the (huge) price of PHV copy for
        // every ingress packet
        parser->parse(packet_copy.get());
        enqueue(egress_port, std::move(packet_copy));
        packet->restore_buffer_state(packet_out_state);
      }
    }

    // LEARNING
    if (learn_id > 0) {
      get_learn_engine()->learn(learn_id, *packet.get());
    }

    // RESUBMIT
    if (phv->has_field("intrinsic_metadata.resubmit_flag")) {
      Field &f_resubmit = phv->get_field("intrinsic_metadata.resubmit_flag");
      if (f_resubmit.get_int()) {
        BMLOG_DEBUG_PKT(*packet, "Resubmitting packet");
        // get the packet ready for being parsed again at the beginning of
        // ingress
        packet->restore_buffer_state(packet_in_state);
        p4object_id_t field_list_id = f_resubmit.get_int();
        f_resubmit.set(0);
        // TODO(antonin): a copy is not needed here, but I don't yet have an
        // optimized way of doing this
        auto packet_copy = copy_ingress_pkt(
            packet, PKT_INSTANCE_TYPE_RESUBMIT, field_list_id);
        input_buffer.push_front(std::move(packet_copy));
        continue;
      }
    }

    Field &f_instance_type = phv->get_field("standard_metadata.instance_type");

    // MULTICAST
    int instance_type = f_instance_type.get_int();
    if (mgid != 0) {
      BMLOG_DEBUG_PKT(*packet, "Multicast requested for packet");
      Field &f_rid = phv->get_field("intrinsic_metadata.egress_rid");
      const auto pre_out = pre->replicate({mgid});
      for (const auto &out : pre_out) {
        egress_port = out.egress_port;
        // if (ingress_port == egress_port) continue; // pruning
        BMLOG_DEBUG_PKT(*packet, "Replicating packet on port {}", egress_port);
        f_rid.set(out.rid);
        f_instance_type.set(PKT_INSTANCE_TYPE_REPLICATION);
        std::unique_ptr<Packet> packet_copy = packet->clone_with_phv_ptr();
        enqueue(egress_port, std::move(packet_copy));
      }
      f_instance_type.set(instance_type);

      // when doing multicast, we discard the original packet
      continue;
    }

    egress_port = egress_spec;
    BMLOG_DEBUG_PKT(*packet, "Egress port is {}", egress_port);

    if (egress_port == 511) {  // drop packet
      BMLOG_DEBUG_PKT(*packet, "Dropping packet at the end of ingress");
      continue;
    }

    enqueue(egress_port, std::move(packet));
  }
}

void
SimpleSwitch::egress_thread(size_t worker_id) {
  PHV *phv;

  while (1) {
    std::unique_ptr<Packet> packet;
    size_t port;
    egress_buffers.pop_back(worker_id, &port, &packet);

    Deparser *deparser = this->get_deparser("deparser");
    Pipeline *egress_mau = this->get_pipeline("egress");

    phv = packet->get_phv();


    // //  // TU
    // // clock::time_point time_now = clock::now();
    // // // unit: microseconds
    // // if (duration_cast<ts_res>(time_now - last_time_map[port]).count() > 1000000) {
    // //     num_enq_pkts_map[port] = 0;
    // //     last_time_map[port] = time_now;
    // // } else {
    // //   // num_enq_pkts_map[port]++;
    // boost::unique_lock<boost::mutex> lock(tx_mutex);
    // // tx_bytes_in_period[port] += packet->get_data_size();
    // tx_bytes_in_period[port] += packet->get_ingress_length();
    // lock.unlock();


    if (with_queueing_metadata) {
      auto enq_timestamp =
          phv->get_field("queueing_metadata.enq_timestamp").get<ts_res::rep>();
      phv->get_field("queueing_metadata.deq_timedelta").set(
          get_ts().count() - enq_timestamp);
      phv->get_field("queueing_metadata.deq_qdepth").set(
          egress_buffers.size(port));
      // TU
      phv->get_field("queueing_metadata.deq_qcongestion").set(
          (egress_buffers.size(port) << 4)); // 10 - log2 (64)
      phv->get_field("queueing_metadata.tx_utilization").set(
          tx_utilization[port]); // (10 - 3 + 2) byte to Kbit, 4s
    }

    phv->get_field("standard_metadata.egress_port").set(port);

    Field &f_egress_spec = phv->get_field("standard_metadata.egress_spec");
    f_egress_spec.set(0);

    egress_mau->apply(packet.get());

    Field &f_clone_spec = phv->get_field("standard_metadata.clone_spec");
    unsigned int clone_spec = f_clone_spec.get_uint();

    // EGRESS CLONING
    if (clone_spec) {
      BMLOG_DEBUG_PKT(*packet, "Cloning packet at egress");
      int egress_port = get_mirroring_mapping(clone_spec & 0xFFFF);
      if (egress_port >= 0) {
        f_clone_spec.set(0);
        p4object_id_t field_list_id = clone_spec >> 16;
        std::unique_ptr<Packet> packet_copy =
            packet->clone_with_phv_reset_metadata_ptr();
        PHV *phv_copy = packet_copy->get_phv();
        FieldList *field_list = this->get_field_list(field_list_id);
        for (const auto &p : *field_list) {
          phv_copy->get_field(p.header, p.offset)
            .set(phv->get_field(p.header, p.offset));
        }
        phv_copy->get_field("standard_metadata.instance_type")
            .set(PKT_INSTANCE_TYPE_EGRESS_CLONE);
        enqueue(egress_port, std::move(packet_copy));
      }
    }

    // TODO(antonin): should not be done like this in egress pipeline
    int egress_spec = f_egress_spec.get_int();
    if (egress_spec == 511) {  // drop packet
      BMLOG_DEBUG_PKT(*packet, "Dropping packet at the end of egress");
      continue;
    }

    deparser->deparse(packet.get());

    // TU
    // it should be put here, see get_dat_size doc for reason
    boost::unique_lock<boost::mutex> lock(tx_mutex);
    tx_bytes_in_period[port] += packet->get_data_size();
    // tx_bytes_in_period[port] += packet->get_ingress_length();
    lock.unlock();

    // RECIRCULATE
    if (phv->has_field("intrinsic_metadata.recirculate_flag")) {
      Field &f_recirc = phv->get_field("intrinsic_metadata.recirculate_flag");
      if (f_recirc.get_int()) {
        BMLOG_DEBUG_PKT(*packet, "Recirculating packet");
        p4object_id_t field_list_id = f_recirc.get_int();
        f_recirc.set(0);
        FieldList *field_list = this->get_field_list(field_list_id);
        // TODO(antonin): just like for resubmit, there is no need for a copy
        // here, but it is more convenient for this first prototype
        std::unique_ptr<Packet> packet_copy = packet->clone_no_phv_ptr();
        PHV *phv_copy = packet_copy->get_phv();
        phv_copy->reset_metadata();
        for (const auto &p : *field_list) {
          phv_copy->get_field(p.header, p.offset)
              .set(phv->get_field(p.header, p.offset));
        }
        phv_copy->get_field("standard_metadata.instance_type")
            .set(PKT_INSTANCE_TYPE_RECIRC);
        input_buffer.push_front(std::move(packet_copy));
        continue;
      }
    }

    output_buffer.push_front(std::move(packet));
  }
}
