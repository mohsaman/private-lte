#!/bin/bash
# ================================================================
# start_lte.sh — Bring up the private LTE network after reboot
# Usage: sudo ./scripts/start_lte.sh
# ================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     📡 Private LTE Network Launcher      ║"
echo "  ║     Band 7 • 2680 MHz • PLMN 999/70     ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root: sudo $0${NC}"
  exit 1
fi

# -------------------------------------------------------
# 1. Start MongoDB
# -------------------------------------------------------
echo -e "${YELLOW}[1/6] Starting MongoDB...${NC}"
systemctl start mongod 2>/dev/null || true
sleep 1
if ss -tlnp | grep -q 27017; then
  echo -e "${GREEN}  ✓ MongoDB listening on port 27017${NC}"
else
  echo -e "${RED}  ✗ MongoDB failed to start${NC}"
  echo "    Try: sudo mkdir -p /var/log/mongodb /var/lib/mongodb"
  echo "         sudo chown mongodb:mongodb /var/log/mongodb /var/lib/mongodb"
  exit 1
fi

# -------------------------------------------------------
# 2. Verify Open5GS services
# -------------------------------------------------------
echo -e "${YELLOW}[2/6] Starting Open5GS services...${NC}"
CORE_SERVICES="open5gs-mmed open5gs-sgwcd open5gs-sgwud open5gs-hssd open5gs-pcrfd open5gs-smfd open5gs-upfd"
for svc in $CORE_SERVICES; do
  systemctl restart "$svc" 2>/dev/null || true
done
sleep 2

RUNNING=0
FAILED=0
for svc in $CORE_SERVICES; do
  if systemctl is-active --quiet "$svc"; then
    RUNNING=$((RUNNING + 1))
  else
    echo -e "${RED}  ✗ $svc is not running${NC}"
    FAILED=$((FAILED + 1))
  fi
done
echo -e "${GREEN}  ✓ $RUNNING core services running${NC}"
if [ $FAILED -gt 0 ]; then
  echo -e "${RED}  ✗ $FAILED services failed — check with: journalctl -u <service>${NC}"
fi

# -------------------------------------------------------
# 3. CPU performance governor
# -------------------------------------------------------
echo -e "${YELLOW}[3/6] Setting CPU governor to performance...${NC}"
cpupower frequency-set -g performance > /dev/null 2>&1 || {
  echo -e "${RED}  ✗ cpupower not found. Install: sudo apt install cpufrequtils${NC}"
}
echo -e "${GREEN}  ✓ CPU governor set to performance${NC}"

# -------------------------------------------------------
# 4. Enable IP forwarding
# -------------------------------------------------------
echo -e "${YELLOW}[4/6] Enabling IP forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1 > /dev/null
echo -e "${GREEN}  ✓ IP forwarding enabled${NC}"

# -------------------------------------------------------
# 5. Configure NAT
# -------------------------------------------------------
echo -e "${YELLOW}[5/6] Configuring NAT (MASQUERADE)...${NC}"

# Check if ogstun exists
if ! ip link show ogstun > /dev/null 2>&1; then
  echo "  Creating ogstun interface..."
  ip tuntap add name ogstun mode tun
  ip addr add 10.45.0.1/16 dev ogstun
  ip link set ogstun up
fi

# Flush any stale NAT rules and add fresh
iptables -t nat -D POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE

echo -e "${GREEN}  ✓ NAT configured for 10.45.0.0/16 → internet${NC}"

# -------------------------------------------------------
# 6. Launch eNodeB
# -------------------------------------------------------
echo -e "${YELLOW}[6/6] Launching srsENB...${NC}"
echo ""
echo -e "${CYAN}  TX Gain: 75 dB | RX Gain: 40 dB"
echo -e "  Band 7: DL 2680 MHz / UL 2560 MHz"
echo -e "  Bandwidth: 5 MHz (25 PRB)"
echo -e "  Inactivity Timer: 60s"
echo -e "${NC}"
echo -e "${GREEN}  Press 't' to view live UE metrics${NC}"
echo -e "${GREEN}  Press Ctrl+C to stop${NC}"
echo ""

exec chrt -f 50 srsenb /etc/srsran/enb.conf \
    --rf.device_name=UHD \
    --rf.device_args="type=b200,num_recv_frames=64,num_send_frames=64" \
    --rf.tx_gain=75 \
    --rf.rx_gain=40 \
    --expert.rrc_inactivity_timer=60000 \
    --expert.rlf_release_timer_ms=10000 \
    --log.all_level=info
