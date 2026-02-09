#!/bin/bash
# ================================================================
# check_status.sh — Verify all LTE network components are running
# Usage: ./scripts/check_status.sh
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Private LTE Network — Status Check${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

PASS=0
FAIL=0

check() {
  local label="$1"
  local result="$2"
  if [ "$result" = "ok" ]; then
    echo -e "  ${GREEN}✓${NC} $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $label — ${RED}$result${NC}"
    FAIL=$((FAIL + 1))
  fi
}

# --- MongoDB ---
echo -e "${YELLOW}MongoDB${NC}"
if ss -tlnp 2>/dev/null | grep -q 27017; then
  check "MongoDB listening on port 27017" "ok"
else
  check "MongoDB" "not running"
fi

# --- Open5GS Core Services ---
echo ""
echo -e "${YELLOW}Open5GS Core Network${NC}"
for svc in open5gs-mmed open5gs-sgwcd open5gs-sgwud open5gs-hssd open5gs-pcrfd open5gs-smfd open5gs-upfd; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    check "$svc" "ok"
  else
    check "$svc" "not running"
  fi
done

# --- Subscribers ---
echo ""
echo -e "${YELLOW}HSS Subscribers${NC}"
SUB_COUNT=$(mongosh --quiet open5gs --eval 'db.subscribers.countDocuments({})' 2>/dev/null || echo "0")
if [ "$SUB_COUNT" -gt 0 ] 2>/dev/null; then
  check "$SUB_COUNT subscriber(s) registered" "ok"
  mongosh --quiet open5gs --eval 'db.subscribers.find({}, {imsi:1, _id:0}).forEach(s => print("       IMSI: " + s.imsi))' 2>/dev/null
else
  check "No subscribers in HSS" "add with scripts/add_subscriber.sh"
fi

# --- ogstun Interface ---
echo ""
echo -e "${YELLOW}Network Interfaces${NC}"
if ip link show ogstun > /dev/null 2>&1; then
  OGSTUN_IP=$(ip -4 addr show ogstun | grep -oP '(?<=inet\s)\S+' | head -1)
  check "ogstun interface up ($OGSTUN_IP)" "ok"
else
  check "ogstun TUN interface" "not found"
fi

# --- IP Forwarding ---
IP_FWD=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
if [ "$IP_FWD" = "1" ]; then
  check "IP forwarding enabled" "ok"
else
  check "IP forwarding" "disabled — run: sudo sysctl net.ipv4.ip_forward=1"
fi

# --- NAT ---
if sudo iptables -t nat -L POSTROUTING -n 2>/dev/null | grep -q "10.45.0.0"; then
  check "NAT MASQUERADE rule for 10.45.0.0/16" "ok"
else
  check "NAT rule" "missing — run: sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE"
fi

# --- CPU Governor ---
echo ""
echo -e "${YELLOW}System Performance${NC}"
GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
if [ "$GOV" = "performance" ]; then
  check "CPU governor: performance" "ok"
else
  check "CPU governor: $GOV" "should be 'performance' — run: sudo cpupower frequency-set -g performance"
fi

# --- USRP B210 ---
echo ""
echo -e "${YELLOW}USRP B210${NC}"
if lsusb 2>/dev/null | grep -qi "2500:002"; then
  check "USRP B210 detected on USB" "ok"
else
  check "USRP B210" "not detected — check USB 3.0 connection"
fi

# --- srsENB ---
echo ""
echo -e "${YELLOW}eNodeB${NC}"
if pgrep -x srsenb > /dev/null 2>&1; then
  check "srsenb running (PID $(pgrep -x srsenb))" "ok"
else
  check "srsenb" "not running — start with scripts/start_lte.sh"
fi

# --- VPN Check ---
echo ""
echo -e "${YELLOW}VPN Check${NC}"
VPN_PROCS=$(ps aux 2>/dev/null | grep -iE 'vpn|wireguard|openvpn|expressvpn' | grep -v grep | wc -l)
if [ "$VPN_PROCS" -eq 0 ]; then
  check "No VPN detected" "ok"
else
  check "VPN processes detected ($VPN_PROCS)" "may interfere with NAT — consider disabling"
fi

# --- Summary ---
echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
  echo -e "  ${GREEN}All $TOTAL checks passed! Network ready.${NC}"
else
  echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} out of $TOTAL checks"
fi
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
