# 📡 Private LTE Network with USRP B210 & srsRAN

Build your own private 4G LTE cellular network using software-defined radio. This guide walks you through setting up a fully functional LTE base station (eNodeB) with a complete core network (EPC) that real phones can connect to and browse the internet.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2024.04-orange.svg)
![Band](https://img.shields.io/badge/LTE-Band%207%20(2600%20MHz)-green.svg)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Bill of Materials](#bill-of-materials)
- [Prerequisites](#prerequisites)
- [Step 1: Install Open5GS Core Network](#step-1-install-open5gs-core-network)
- [Step 2: Build srsRAN 4G eNodeB](#step-2-build-srsran-4g-enodeb)
- [Step 3: Configure the eNodeB](#step-3-configure-the-enodeb)
- [Step 4: Configure Open5GS EPC](#step-4-configure-open5gs-epc)
- [Step 5: Program SIM Cards](#step-5-program-sim-cards)
- [Step 6: Add Subscribers to HSS](#step-6-add-subscribers-to-hss)
- [Step 7: Launch the Network](#step-7-launch-the-network)
- [Step 8: Enable Internet Access](#step-8-enable-internet-access)
- [Step 9: Connect Your Phones](#step-9-connect-your-phones)
- [Troubleshooting](#troubleshooting)
- [Performance Tuning](#performance-tuning)
- [Antenna Guide](#antenna-guide)
- [Legal Notice](#legal-notice)

---

## Overview

This project creates a private LTE (4G) cellular network consisting of:

- **eNodeB (Base Station):** srsRAN 4G running on a USRP B210 SDR
- **EPC (Core Network):** Open5GS providing MME, HSS, SGW, PGW, and PCRF
- **UEs (User Equipment):** Any Band 7 capable Android phone with a programmable SIM

The network operates on **Band 7 (2600 MHz)** with **5 MHz bandwidth (25 PRBs)**, delivering approximately **16 Mbps downlink** and **7.6 Mbps uplink** throughput.

### What You'll Achieve

- ✅ Your own private LTE cell broadcasting a custom PLMN
- ✅ Phones displaying your custom network name
- ✅ Full LTE authentication (USIM with Ki/OPc)
- ✅ Internet connectivity through your LTE network
- ✅ Support for multiple simultaneous UEs

---

## Architecture

```
┌─────────────┐         LTE Air Interface (Band 7)         ┌──────────────┐
│   Phone 1   │ ◄──────────────────────────────────────────►│              │
│  (UE #1)    │           2680 MHz DL / 2560 MHz UL         │   USRP B210  │
└─────────────┘                                             │   (SDR)      │
                                                            │              │
┌─────────────┐         LTE Air Interface (Band 7)         │    ┌─────┐   │
│   Phone 2   │ ◄──────────────────────────────────────────►│    │ ANT │   │
│  (UE #2)    │           2680 MHz DL / 2560 MHz UL         │    └─────┘   │
└─────────────┘                                             └──────┬───────┘
                                                                   │ USB 3.0
                                                            ┌──────┴───────┐
                                                            │   Linux PC   │
                                                            │              │
                                                            │  ┌────────┐  │
                                                            │  │ srsENB │  │
                                                            │  └───┬────┘  │
                                                            │      │ S1AP  │
                                                            │  ┌───┴────────────────┐
                                                            │  │     Open5GS EPC    │
                                                            │  │                    │
                                                            │  │  MME ── HSS        │
                                                            │  │   │                │
                                                            │  │  SGW-C ── SGW-U    │
                                                            │  │   │                │
                                                            │  │  SMF ── UPF        │
                                                            │  │         │          │
                                                            │  └─────────┼──────────┘
                                                            │            │ ogstun
                                                            │       NAT/MASQUERADE
                                                            │            │
                                                            └────────────┼──────────┘
                                                                         │
                                                                    Internet
```

---

## Bill of Materials

### Required Hardware

| Item | Model / Spec | Approx. Cost | Notes |
|------|-------------|-------------|-------|
| Software Defined Radio | USRP B210 | ~$500 | Dual-channel, 70 MHz – 6 GHz, USB 3.0 |
| Antennas (x2) | VERT2450 (included with B210) | Included | 2.4–2.5 GHz vertical. Works on Band 7 (2600 MHz) |
| SIM Cards | [sysmoISIM-SJA5 10-pack](https://shop.sysmocom.de/sysmoISIM-SJA5/) | ~€40 | Programmable USIM/ISIM. Comes with Ki/OPc/ADM keys |
| SIM Card Reader | SCM SCR 3310 (or any PC/SC reader) | ~$15 | USB smart card reader for SIM programming |
| Linux PC / Laptop | Intel i5+ with USB 3.0 | — | AVX2 support strongly recommended |
| USB 3.0 Cable | Type-A to Micro-B | ~$5 | **Must** be USB 3.0 (blue connector) |
| Android Phones (x2) | Any with LTE Band 7 support | — | e.g., Samsung Galaxy A15, Google Pixel 6 |

### Recommended Extras

| Item | Purpose | Approx. Cost | Notes |
|------|---------|-------------|-------|
| GPS Antenna (puck) | GPSDO frequency/timing reference | ~$15-30 | SMA connector, magnetic mount. Required for accurate carrier frequency and frame timing |
| Copper heatsink (30×30mm) | B210 thermal management | ~$5 | Attach to AD9361 RF chip |
| 30mm fan | Active cooling | ~$5 | Essential for continuous TX |
| Pelican case | Field deployment | ~$50-100 | Drill ventilation holes in top |
| SMA attenuators (10-30 dB) | Close-range testing | ~$10 | Prevents phone receiver saturation |

> 📡 **GPS Puck:** The USRP B210 has a built-in GPSDO (GPS Disciplined Oscillator) input. Connecting a GPS antenna to the B210's GPS SMA port provides a highly accurate 10 MHz reference clock and PPS (Pulse Per Second) timing signal. This is **strongly recommended** for field deployments — without it, the B210's internal oscillator may drift, causing subtle timing and frequency errors that degrade performance over time.

### Better Antennas (Optional)

The included VERT2450 antennas work on Band 7 but are optimized for 2.4 GHz WiFi. For better performance or other bands:

| Antenna | Frequency Range | Gain | Best For |
|---------|----------------|------|----------|
| VERT900 | 824–960 MHz, 1710–1990 MHz | 3 dBi | Band 5 (850 MHz) |
| 700-2700 MHz Omni Whip | 700 MHz – 2.7 GHz | 3 dBi | Wideband LTE |
| Nooelec UWB Surveyor | 700 MHz – 10 GHz | 3 dBi | Ultra-wideband testing |

> ⚠️ **Antenna mismatch is the #1 reason phones can't see your network.** The VERT2450 will NOT work on Band 5 (850 MHz). See [Antenna Guide](#antenna-guide) for details.

---

## Prerequisites

### Operating System

Ubuntu 24.04 LTS (Noble Numbat) — tested and verified.

### Install Base Dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    build-essential cmake git \
    libfftw3-dev libmbedtls-dev libboost-program-options-dev \
    libconfig++-dev libsctp-dev libzmq3-dev \
    libuhd-dev uhd-host \
    pcscd pcsc-tools libpcsclite-dev \
    python3-pip python3-pyscard \
    cpufrequtils iptables net-tools tcpdump
```

### Install MongoDB

Follow the [MongoDB Community Edition installation guide](https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/) for Ubuntu, then:

```bash
sudo systemctl enable mongod
sudo systemctl start mongod
```

### Verify USRP B210

Connect your B210 via USB 3.0 and verify:

```bash
# Download firmware images (first time only)
sudo uhd_images_downloader

# Verify detection
uhd_find_devices
```

Expected output:

```
-- UHD Device 0
    serial: 3194001
    name: MyB210
    product: B210
    type: b200
```

> **Tip:** If the B210 is not detected, try a different USB 3.0 port or cable. USB 2.0 will NOT provide enough bandwidth.

### Set Up GPS Disciplined Oscillator (Optional but Recommended)

The B210 has a GPS antenna input (SMA port labeled **GPS** on the board). Connecting a GPS puck provides:

- **Accurate 10 MHz reference clock** — prevents carrier frequency drift
- **PPS timing** — precise frame synchronization
- **GPS location** — useful for cell broadcasting

#### Hardware Setup

1. Connect a GPS antenna (magnetic puck style, SMA connector) to the **GPS** SMA port on the B210
2. Place the GPS puck near a window or outdoors with clear sky view
3. Wait 1-2 minutes for GPS lock

#### Verify GPS Lock

```bash
uhd_usrp_probe --args="type=b200" | grep -i gps
```

Or query GPS sensors directly:

```bash
python3 -c "
import uhd
usrp = uhd.usrp.MultiUSRP('type=b200')
try:
    print('GPS locked:', usrp.get_mboard_sensor('gps_locked'))
    print('GPS time:', usrp.get_mboard_sensor('gps_time'))
except:
    print('No GPSDO detected — using internal oscillator')
"
```

#### Enable GPSDO in srsENB

To use the GPS clock reference, add to your `enb.conf` `[rf]` section or pass as device args:

```bash
# In device_args, add clock and time source:
device_args = type=b200,num_recv_frames=64,num_send_frames=64,clock_source=gpsdo,time_source=gpsdo
```

> **Note:** srsENB will fail to start if `clock_source=gpsdo` is set but no GPS puck is connected or GPS has no lock. Only add these args when you have a working GPS connection. For indoor/lab testing, the internal oscillator is sufficient.

---

## Step 1: Install Open5GS Core Network

Open5GS provides the complete LTE Evolved Packet Core (EPC).

### 1.1 Add Repository and Install

```bash
sudo add-apt-repository ppa:open5gs/latest
sudo apt update
sudo apt install -y open5gs
```

### 1.2 Fix MongoDB Directories (if needed)

If Open5GS services fail because MongoDB won't start:

```bash
sudo mkdir -p /var/log/mongodb /var/lib/mongodb
sudo chown mongodb:mongodb /var/log/mongodb /var/lib/mongodb
sudo systemctl restart mongod
```

### 1.3 Verify All Services

```bash
systemctl list-units --type=service | grep open5gs
```

You should see 17 Open5GS services all in `active (running)` state.

---

## Step 2: Build srsRAN 4G eNodeB

### 2.1 Clone and Build

```bash
cd ~
git clone https://github.com/srsRAN/srsRAN_4G.git
cd srsRAN_4G
mkdir build && cd build
cmake ../
make -j$(nproc)
sudo make install
sudo ldconfig
```

### 2.2 Install Default Configs

```bash
sudo srsran_install_configs.sh service
```

This places configuration files in `/etc/srsran/`.

---

## Step 3: Configure the eNodeB

Copy the provided configs or manually edit:

```bash
sudo cp configs/enb.conf /etc/srsran/enb.conf
sudo cp configs/rr.conf /etc/srsran/rr.conf
```

### Key Settings in `enb.conf`

```ini
[enb]
enb_id = 0x19B
mcc = 999
mnc = 70
mme_addr = 127.0.0.2
gtp_bind_addr = 127.0.1.1
s1c_bind_addr = 127.0.1.1
n_prb = 25

[rf]
dl_earfcn = 3350
tx_gain = 75
rx_gain = 40
```

### Key Settings in `rr.conf`

```
cell_list =
(
  {
    cell_id = 0x01;
    tac = 0x0001;        // MUST match MME config
    pci = 1;
    dl_earfcn = 3350;    // Band 7 (2680 MHz DL)
  }
);
```

> **EARFCN Reference:** 3350 = Band 7 (2680 MHz DL / 2560 MHz UL). For Band 5: use EARFCN 2525 (881.5 MHz DL) with appropriate antennas.

---

## Step 4: Configure Open5GS EPC

### 4.1 MME Configuration

```bash
sudo cp configs/mme.yaml /etc/open5gs/mme.yaml
sudo systemctl restart open5gs-mmed
```

Or manually edit `/etc/open5gs/mme.yaml` — the critical sections:

```yaml
mme:
  s1ap:
    server:
      - address: 127.0.0.2
  gtpc:
    server:
      - address: 127.0.0.2
  gummei:
    - plmn_id:
        mcc: 999
        mnc: 70
      mme_gid: 2
      mme_code: 1
  tai:
    - plmn_id:
        mcc: 999
        mnc: 70
      tac: 1
```

> ⚠️ **Critical:** `tac: 1` in mme.yaml **must** match `tac = 0x0001` in rr.conf. A mismatch causes silent S1 setup failures.

---

## Step 5: Program SIM Cards

We use **sysmoISIM-SJA5** cards from [sysmocom](https://shop.sysmocom.de). These come pre-programmed — each card ships with a spreadsheet containing its unique IMSI, Ki, OPc, and ADM key.

### 5.1 Install pySim

```bash
cd ~
git clone https://gitea.osmocom.org/sim-card/pysim.git
cd pysim
pip install -r requirements.txt --break-system-packages
```

### 5.2 Verify SIM Card

Insert a SIM into your USB reader and launch pySim-shell:

```bash
cd ~/pysim
./pySim-shell.py -p 0
```

Read the IMSI to identify which card you have:

```
pySIM-shell (00:MF)> select ADF.USIM
pySIM-shell (00:MF/ADF.USIM)> select EF.IMSI
pySIM-shell (00:MF/ADF.USIM/EF.IMSI)> read_binary
```

Match the decoded IMSI against your sysmocom spreadsheet to find the correct ADM key, Ki, and OPc.

### 5.3 Authenticate (Optional)

If you need to modify the SIM (usually not needed for sysmocom cards):

```
pySIM-shell (00:MF/ADF.USIM/EF.IMSI)> select MF
pySIM-shell (00:MF)> verify_adm <YOUR_ADM1_KEY>
```

> ⚠️ **WARNING:** You only get **3 attempts** before the ADM PIN blocks permanently. Triple-check the ADM key against the correct IMSI row in your spreadsheet. Each SIM has a unique key.

### 5.4 Key Fields from sysmocom Spreadsheet

| Field | Description | Example |
|-------|-------------|---------|
| IMSI | Subscriber identity | 999700000120071 |
| Ki | Authentication key (128-bit hex) | 806F98D01616EFFB4F8B2FF609F5FA26 |
| OPC | Operator variant key (128-bit hex) | C814A6420644BB7BEFF74DDDF92A19EA |
| ADM1 | Admin PIN for SIM modification | 33534107 |

---

## Step 6: Add Subscribers to HSS

Each SIM card must be registered in the Open5GS HSS database. Use the `add_subscriber.sh` script or run manually:

### Add UE #1

```bash
./scripts/add_subscriber.sh 999700000120071 \
    806F98D01616EFFB4F8B2FF609F5FA26 \
    C814A6420644BB7BEFF74DDDF92A19EA
```

### Add UE #2

```bash
./scripts/add_subscriber.sh 999700000120072 \
    272B7BFB8D65315F92C0106712FB7B78 \
    D16E05F4A27FB7C83425CC23EB70DA11
```

### Manual Method

```bash
mongosh open5gs --eval '
db.subscribers.insertOne({
  "imsi": "<IMSI>",
  "subscribed_rau_tau_timer": 12,
  "network_access_mode": 0,
  "subscriber_status": 0,
  "access_restriction_data": 32,
  "slice": [{"sst": 1, "default_indicator": true, "session": [{"name": "internet", "type": 3, "qos": {"index": 9, "arp": {"priority_level": 8, "pre_emption_capability": 1, "pre_emption_vulnerability": 1}}, "ambr": {"downlink": {"value": 1, "unit": 3}, "uplink": {"value": 1, "unit": 3}}, "pcc_rule": []}]}],
  "ambr": {"downlink": {"value": 1, "unit": 3}, "uplink": {"value": 1, "unit": 3}},
  "security": {
    "k": "<Ki>",
    "amf": "8000",
    "op": null,
    "opc": "<OPc>"
  },
  "schema_version": 1
})'
```

### Verify

```bash
mongosh open5gs --eval 'db.subscribers.find({}, {imsi: 1, _id: 0})'
```

---

## Step 7: Launch the Network

### 7.1 Quick Start (After Reboot)

```bash
sudo ./scripts/start_lte.sh
```

### 7.2 Manual Start

```bash
# 1. CPU performance mode (REQUIRED)
sudo cpupower frequency-set -g performance

# 2. Enable IP forwarding
sudo sysctl net.ipv4.ip_forward=1

# 3. NAT for internet access
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE

# 4. Launch eNodeB with real-time priority
sudo chrt -f 50 srsenb /etc/srsran/enb.conf \
    --rf.device_name=UHD \
    --rf.device_args="type=b200,num_recv_frames=64,num_send_frames=64" \
    --rf.tx_gain=75 \
    --rf.rx_gain=40 \
    --expert.rrc_inactivity_timer=60000 \
    --expert.rlf_release_timer_ms=10000 \
    --log.all_level=info
```

You should see:

```
==== eNodeB started ===
Setting frequency: DL=2680.0 Mhz, UL=2560.0 MHz for cc_idx=0 nof_prb=25
```

---

## Step 8: Enable Internet Access

### 8.1 Verify TUN Interface

```bash
ip addr show ogstun
```

If missing:

```bash
sudo ip tuntap add name ogstun mode tun
sudo ip addr add 10.45.0.1/16 dev ogstun
sudo ip link set ogstun up
```

### 8.2 NAT Configuration

```bash
sudo sysctl net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
```

### 8.3 VPN Warning

If you run a VPN on the host machine, it may intercept the NAT'd traffic and prevent the phones from reaching the internet. Disable any VPN before testing:

```bash
# Check for VPN processes
ps aux | grep -i vpn

# Kill if found
sudo killall -9 <vpn-daemon>
```

---

## Step 9: Connect Your Phones

### 9.1 Insert SIM Cards

Put the registered sysmocom SIM cards into each phone.

### 9.2 Configure APN

On each Android phone:

**Settings → Network & Internet → SIMs → [Your Network] → Access Point Names → Add**

| Field | Value |
|-------|-------|
| Name | Open5GS |
| APN | internet |
| MCC | 999 |
| MNC | 70 |

Save and select this APN as active.

### 9.3 Select Network

**Settings → Network & Internet → SIMs → Network operators → Search**

Select **999/70** or **Open5GS** from the list.

### 9.4 Verify on eNodeB

Watch the srsenb terminal for:

```
RACH:  tti=XXXX, cc=0, pci=1, preamble=XX, offset=1, temp_crnti=0xXX
User 0xXX connected
```

Press `t` for live metrics:

```
               -----------------DL----------------|-------------------------UL-------------------------
rat  pci rnti  cqi  ri  mcs  brate   ok  nok  (%) | pusch  pucch  phr  mcs  brate   ok  nok  (%)    bsr
lte    1   4c   14   0    5   9.4k   15    0   0% |  18.9   21.1   28   13    87k   18    0   0%    0.0
lte    1   4d   13   0    3   6.1k   12    0   0% |  15.2   18.7   26   10    52k   14    0   0%    0.0
```

Two rows = two phones connected!

### 9.5 Speed Test Results

| Metric | Expected Value |
|--------|---------------|
| Downlink | ~16 Mbps |
| Uplink | ~7.6 Mbps |
| Latency | ~20-40 ms |
| Bandwidth | 5 MHz (25 PRB) |

---

## Troubleshooting

### Phone Can't See Network

| Symptom | Cause | Fix |
|---------|-------|-----|
| No PLMN in scan | Antenna mismatch | Use Band 7 with VERT2450. Don't try Band 5 with these antennas |
| No PLMN in scan | S1 not connected | Check `journalctl -u open5gs-mmed -n 20` |
| No PLMN in scan | Late errors | Kill Chrome, set CPU to `performance` governor |
| PLMN visible, can't connect | SIM not in HSS | Add subscriber with correct IMSI/Ki/OPc |
| PLMN visible, can't connect | TAC mismatch | Ensure rr.conf `tac` matches mme.yaml `tai.tac` |

### Connected But No Internet

| Symptom | Cause | Fix |
|---------|-------|-----|
| Exclamation on signal bars | IP forwarding off | `sudo sysctl net.ipv4.ip_forward=1` |
| DNS queries on ogstun, none on eth | NAT rule missing | Add MASQUERADE rule |
| DNS queries not leaving host | VPN intercepting | Kill VPN daemon |
| ogstun doesn't exist | UPF not running | Restart `open5gs-upfd`, recreate TUN |

### Frequent Disconnects

| Symptom | Cause | Fix |
|---------|-------|-----|
| High DL `nok%` with CQI 15 | TX overdrive (too close) | Move phone to 2-3m or reduce `tx_gain` to 70 |
| `Late` errors in log | CPU too slow/busy | Kill browsers, set `performance` governor |
| Disconnect after ~30s idle | Inactivity timer | Use `--expert.rrc_inactivity_timer=60000` |
| PUSCH drops before disconnect | Brief RF glitch | Use `--expert.rlf_release_timer_ms=10000` |

### ADM PIN Blocked

The SIM admin PIN is permanently blocked after 3 wrong attempts. Use a different SIM from your 10-pack. The blocked SIM can still work as a regular (non-programmable) SIM.

---

## Performance Tuning

### CPU Governor (REQUIRED)

```bash
sudo cpupower frequency-set -g performance
```

The default `powersave` governor causes frequency scaling that disrupts real-time USB streaming, corrupting the LTE signal.

### Real-Time Scheduling

Always use `chrt -f 50` to give srsenb real-time FIFO priority.

### Kill Resource-Hungry Processes

```bash
pkill chrome; pkill firefox
```

Browsers are the #1 cause of Late errors.

### Increase Bandwidth

For ~2x throughput, use 10 MHz:

```ini
# In enb.conf
n_prb = 50
```

Requires more CPU. Monitor for Late errors.

---

## Antenna Guide

### Why Antenna Choice Matters

The quarter-wave antenna length must roughly match the operating frequency. Using the wrong antenna means the radio energy never leaves the antenna efficiently — your phone simply won't see the network.

| Frequency | Quarter-Wave Length | Matching Antenna |
|-----------|-------------------|-----------------|
| 850 MHz (Band 5) | ~8.8 cm | VERT900 (~17 cm) |
| 1800 MHz (Band 3) | ~4.2 cm | VERT1800 or wideband |
| 2500 MHz (Band 7) | ~3.0 cm | VERT2450 (~12 cm) ✓ |

### Current Setup: VERT2450 on Band 7

The VERT2450 is designed for 2.4–2.5 GHz WiFi. Band 7 at 2.6 GHz is close enough for acceptable performance indoors at short range (1-5 meters).

### For Band 5 (850 MHz)

You **must** use VERT900 or a wideband antenna. The VERT2450 is physically too short to resonate at 850 MHz and will have very poor radiation efficiency.

---

## Repository Structure

```
private-lte-network/
├── README.md                    # This file
├── LICENSE
├── configs/
│   ├── enb.conf                 # srsRAN eNodeB configuration
│   ├── rr.conf                  # Radio resource configuration
│   └── mme.yaml                 # Open5GS MME configuration
├── scripts/
│   ├── start_lte.sh             # Full startup script (post-reboot)
│   ├── add_subscriber.sh        # Add subscriber to HSS database
│   └── check_status.sh          # Verify all services running
└── docs/
    └── ANTENNA_GUIDE.md         # Detailed antenna info
```

---

## Legal Notice

⚠️ **READ BEFORE TRANSMITTING**

- This project uses **PLMN 999/70**, a 3GPP test network identifier
- **Band 7 (2600 MHz) is licensed spectrum** in most countries
- Unauthorized transmission may violate local radio regulations
- Keep transmit power low and operate in a **shielded environment** (Faraday cage, RF shielded room) to avoid interference
- This project is for **educational and research purposes only**
- The author assumes no responsibility for regulatory violations

**Licensing options by region:**

| Region | Authority | License Type |
|--------|-----------|-------------|
| USA | FCC | Part 5 Experimental License |
| EU | National regulators | Test/trial license |
| UK | Ofcom | Shared Access License |

---

## Acknowledgments

- [srsRAN](https://www.srsran.com/) — Open-source LTE/5G radio suite
- [Open5GS](https://open5gs.org/) — Open-source 5G core and EPC
- [sysmocom](https://sysmocom.de/) — Programmable SIM cards
- [pySim](https://gitea.osmocom.org/sim-card/pysim) — SIM card programming
- [Osmocom](https://osmocom.org/) — Open source mobile communications

---

## License

MIT License — see [LICENSE](LICENSE) for details.
