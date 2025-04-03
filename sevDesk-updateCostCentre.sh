#!/bin/bash

# 🔐 API-Token – am besten später aus Datei oder ENV holen
API_TOKEN="23ebb...."  # <--- Ersetze mit deinem Token

# Funktion: Prüfen, ob jq installiert ist
function check_dependencies {
  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ Das Tool 'jq' ist nicht installiert."
    echo "➡️  Bitte installiere es mit: brew install jq"
    exit 1
  fi
}

# Funktion: Kostenstellen anzeigen
function list_cost_centres {
  echo "Verfügbare Kostenstellen:"
  curl -s -X GET "https://my.sevdesk.de/api/v1/CostCentre" \
    -H "Authorization: ${API_TOKEN}" | \
    jq -r '.objects[] | "\(.id): \(.name)"'
}

# Erst prüfen, ob jq vorhanden ist
check_dependencies

# Eingabeparameter prüfen
if [ "$#" -ne 3 ]; then
  echo "❌ Falsche Parameter!"
  echo "Usage: $0 [B|R] <Kostenstellen-ID> <Beleg/Rechnungs-ID>"
  echo ""
  list_cost_centres
  exit 1
fi

TYPE="$1"
COST_CENTRE_ID="$2"
DOC_ID="$3"
LOG_FILE="${DOC_ID}.log"

# Ziel-Endpoint bestimmen
if [ "$TYPE" == "B" ]; then
  ENDPOINT="Voucher"
elif [ "$TYPE" == "R" ]; then
  ENDPOINT="Invoice"
else
  echo "❌ Ungültiger Typ. Benutze B (Beleg) oder R (Rechnung)." | tee "$LOG_FILE"
  echo ""
  list_cost_centres | tee -a "$LOG_FILE"
  exit 1
fi

# API-Call zum Ändern der Kostenstelle
RESPONSE=$(curl -s -w "%{http_code}" -o response_body.json -X PUT "https://my.sevdesk.de/api/v1/${ENDPOINT}/${DOC_ID}" \
  -H "Authorization: ${API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"${DOC_ID}\",
    \"objectName\": \"${ENDPOINT}\",
    \"costCentre\": {
      \"id\": \"${COST_CENTRE_ID}\",
      \"objectName\": \"CostCentre\"
    }
  }")

HTTP_STATUS="${RESPONSE}"

# Ergebnis prüfen
if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "OK" | tee "$LOG_FILE"
else
  echo "Fehler! HTTP Status: $HTTP_STATUS" | tee "$LOG_FILE"
  cat response_body.json >> "$LOG_FILE"
fi

rm -f response_body.json