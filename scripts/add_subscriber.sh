#!/bin/bash
# ================================================================
# add_subscriber.sh — Add a UE subscriber to the Open5GS HSS
#
# Usage: ./scripts/add_subscriber.sh <IMSI> <Ki> <OPc>
#
# Example:
#   ./scripts/add_subscriber.sh 999700000120071 \
#       806F98D01616EFFB4F8B2FF609F5FA26 \
#       C814A6420644BB7BEFF74DDDF92A19EA
# ================================================================

set -e

if [ $# -ne 3 ]; then
  echo "Usage: $0 <IMSI> <Ki> <OPc>"
  echo ""
  echo "  IMSI  — International Mobile Subscriber Identity (15 digits)"
  echo "  Ki    — Authentication key (32 hex chars)"
  echo "  OPc   — Operator variant key (32 hex chars)"
  echo ""
  echo "Get these values from your sysmocom SIM card spreadsheet."
  exit 1
fi

IMSI="$1"
KI="$2"
OPC="$3"

# Validate IMSI (should be 15 digits)
if ! [[ "$IMSI" =~ ^[0-9]{15}$ ]]; then
  echo "ERROR: IMSI must be exactly 15 digits. Got: $IMSI"
  exit 1
fi

# Validate Ki (should be 32 hex chars)
if ! [[ "$KI" =~ ^[0-9A-Fa-f]{32}$ ]]; then
  echo "ERROR: Ki must be exactly 32 hex characters. Got: $KI"
  exit 1
fi

# Validate OPc (should be 32 hex chars)
if ! [[ "$OPC" =~ ^[0-9A-Fa-f]{32}$ ]]; then
  echo "ERROR: OPc must be exactly 32 hex characters. Got: $OPC"
  exit 1
fi

# Check if subscriber already exists
EXISTING=$(mongosh --quiet open5gs --eval "db.subscribers.countDocuments({imsi: \"$IMSI\"})" 2>/dev/null)
if [ "$EXISTING" -gt 0 ] 2>/dev/null; then
  echo "WARNING: Subscriber $IMSI already exists in database."
  echo -n "Replace? (y/n): "
  read -r REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    mongosh --quiet open5gs --eval "db.subscribers.deleteOne({imsi: \"$IMSI\"})" > /dev/null
    echo "Removed existing entry."
  else
    echo "Aborted."
    exit 0
  fi
fi

# Insert subscriber
mongosh --quiet open5gs --eval "
db.subscribers.insertOne({
  \"imsi\": \"$IMSI\",
  \"subscribed_rau_tau_timer\": 12,
  \"network_access_mode\": 0,
  \"subscriber_status\": 0,
  \"access_restriction_data\": 32,
  \"slice\": [{
    \"sst\": 1,
    \"default_indicator\": true,
    \"session\": [{
      \"name\": \"internet\",
      \"type\": 3,
      \"qos\": {
        \"index\": 9,
        \"arp\": {
          \"priority_level\": 8,
          \"pre_emption_capability\": 1,
          \"pre_emption_vulnerability\": 1
        }
      },
      \"ambr\": {
        \"downlink\": {\"value\": 1, \"unit\": 3},
        \"uplink\": {\"value\": 1, \"unit\": 3}
      },
      \"pcc_rule\": []
    }]
  }],
  \"ambr\": {
    \"downlink\": {\"value\": 1, \"unit\": 3},
    \"uplink\": {\"value\": 1, \"unit\": 3}
  },
  \"security\": {
    \"k\": \"$KI\",
    \"amf\": \"8000\",
    \"op\": null,
    \"opc\": \"$OPC\"
  },
  \"schema_version\": 1
})" > /dev/null

echo ""
echo "✓ Subscriber added successfully!"
echo "  IMSI: $IMSI"
echo "  Ki:   $KI"
echo "  OPc:  $OPC"
echo ""
echo "Verify: mongosh open5gs --eval 'db.subscribers.find({imsi: \"$IMSI\"}, {imsi:1, _id:0})'"
