# 4PORT_SWITCH

A complete **Four-Port Packet Switch** implemented in **SystemVerilog RTL**, verified using a **custom object-oriented verification environment**, and synthesized using **Synopsys Fusion Compiler / ICC2-style flows** with and without **clock gating**.

This project was developed as part of the course  
**Design, Verification and Logical Synthesis for VLSI Circuits (5124711)**.

---

## Project Overview:

The `4PORT_SWITCH` accepts packets on any of four input ports and forwards them to one or more destination ports according to packet header fields.

The project was completed in **three full hardware development stages**:
- **Stage A – RTL Design**
- **Stage B – Verification**
- **Stage C – Synthesis & Analysis**

All stages strictly follow the official project specification :contentReference[oaicite:2]{index=2} and were fully implemented and analyzed in the final report :contentReference[oaicite:3]{index=3}.

---

## Packet Format:

Each packet contains:
- **source** (4-bit one-hot): originating port
- **target** (4-bit mask): destination port(s)
- **data** (8-bit payload)

Supported packet types:
- **Single-Destination**
- **Multicast (2 or 3 destinations)**
- **Broadcast (all ports)**

Illegal packets (e.g. source included in target) are prevented at the stimulus level.

---

## Architecture:

### RTL Design (Stage A)

- `switch_port`  
  Per-port module with:
  - FSM (`IDLE → WAIT_LAT → TRANSMIT`)
  - Configurable latency (`LATENCY_CYCLES`)
  - Local packet buffering

- `switch_4port`  
  Top-level module responsible for:
  - Central **Round-Robin arbitration**
  - Registered crossbar routing
  - Packet replication for multicast/broadcast
  - Clean clock/reset handling

All logic is fully synchronous with:
- Active-low asynchronous reset
- Synchronous de-assertion
- Non-blocking sequential logic

---

## Verification Environment (Stage B):

A **custom SystemVerilog OOP-based verification framework** (no UVM, per requirements):

Components:
- `packet` class with constrained-random generation
- `sequencer`, `driver`, `monitor`, `agent`
- `packet_vc` (one per port)
- Central **checker / scoreboard** using mailboxes

Verification features:
- Constrained-random stimulus
- Parallel multi-port operation
- Automated checking (no drops, no duplication)
- Functional coverage:
  - Packet types
  - Source/target fanout
  - FSM states
  - Cross combinations

All verification results passed successfully :contentReference[oaicite:4]{index=4}.

---

## Synthesis & Implementation (Stage C):

Synthesis performed using **Synopsys Fusion Compiler**, comparing:

### Without Clock Gating
- Max frequency: **153.6 MHz**
- Total power: **409 mW**
- Cell count: **1873**

### With Clock Gating
- Max frequency: **326.8 MHz**
- Total power: **204.3 mW**
- Cell count: **1296**
- **97.99% of registers gated**

### Key Improvements with Clock Gating:
- **50% total power reduction**
- **+112% max frequency**
- **15.3% area reduction**
- Minimal synthesis runtime impact

Full timing, area, power, and runtime analyses are documented in the final report :contentReference[oaicite:5]{index=5}.
