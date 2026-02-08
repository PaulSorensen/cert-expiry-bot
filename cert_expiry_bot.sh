#!/bin/bash
################################################################################
# Script Name   : Cert Expiry Bot
# Author        : Paul Sørensen
# Website       : https://paulsorensen.io
# GitHub        : https://github.com/paulsorensen
# Version       : 1.2
# Last Modified : 2026/02/08 17:59:39
#
# Description:
# Monitors SSL certificates for domains listed in cert_expiry_bot.txt and sends
# notifications if they expire within 14 or 7 days (configurable).
#
# Usage: Refer to README.md for details on how to use this script.
#
# If you found this script useful, a small tip is appreciated ❤️
# https://buymeacoffee.com/paulsorensen
################################################################################

BLUE='\033[38;5;81m'
RED='\033[38;5;203m'
NC='\033[0m'
echo -e "${BLUE}Cert Expiry Bot by paulsorensen.io${NC}"
echo ""

# Define script directory
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Set a safe PATH for cron
export PATH="/usr/local/bin:/usr/bin:/bin"

# Check for required configuration files
if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo -e "${RED}Error: .env file not found. Please create it by copying .env.example:${NC}"
  echo -e "${RED}  cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env${NC}"
  echo -e "${RED}Then edit .env to set push notification options.${NC}"  
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/cert_expiry_bot.txt" ]; then
  if [ -f "$SCRIPT_DIR/cert_expiry_bot.txt.example" ]; then
    echo -e "${RED}Error: cert_expiry_bot.txt not found. Please create it by copying cert_expiry_bot.txt.example:${NC}"
    echo -e "${RED}  cp $SCRIPT_DIR/cert_expiry_bot.txt.example $SCRIPT_DIR/cert_expiry_bot.txt${NC}"
    echo -e "${RED}Then edit cert_expiry_bot.txt to add your domains.${NC}"
  else
    echo -e "${RED}Error: cert_expiry_bot.txt and cert_expiry_bot.txt.example not found!${NC}"
  fi
  exit 1
fi

# Include sources
source "$SCRIPT_DIR/.env"
source "$SCRIPT_DIR/cert_expiry_bot.conf"

# Path to the domain list file
DOMAIN_LIST="$SCRIPT_DIR/cert_expiry_bot.txt"

# Check if notification options are set
if [ -z "$NTFY_TOPIC" ] && [ -z "$WEBHOOK_URL" ] && { [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; }; then
  echo -e "${RED}Error: No push notification options are set. Please update .env${NC}"
  exit 1
fi

# Check Telegram connection if credentials are provided
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
RESPONSE=$(curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe")
  if [ $? -ne 0 ] || echo "$RESPONSE" | grep -q '"error_code":404'; then
    echo -e "${RED}Error: Can't connect to Telegram Bot. Please check your TELEGRAM_BOT_TOKEN${NC}"
    exit 1
  fi
fi

# Helper function to send notifications
send_notification() {
  if [ -n "$NTFY_TOPIC" ]; then
    curl -s -H "Priority: high" -d "$MSG" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>/dev/null
  fi

  if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -s \
      --data chat_id="$TELEGRAM_CHAT_ID" \
      --data-urlencode "text=$MSG" \
      "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?parse_mode=HTML" >/dev/null 2>/dev/null
  fi

  if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST -H "Content-Type: text/plain" -d "$MSG" "$WEBHOOK_URL" >/dev/null 2>/dev/null
  fi
}

# Arrays to store domains expiring in long and short timeframes, and errors
declare -a EXPIRING_LONG
declare -a EXPIRING_SHORT
declare -a ERROR_DOMAINS

# Read domains from the file and process each one
while IFS= read -r DOMAIN; do
  # Strip leading/trailing spaces and tabs
  DOMAIN=$(echo "$DOMAIN" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')

  # Skip empty lines
  [ -z "$DOMAIN" ] && continue

  # Validate domain format (basic check for invalid symbols)
  if ! echo "$DOMAIN" | grep -qE '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
    ERROR_DOMAINS+=("$DOMAIN (invalid domain format)")
    continue
  fi

  # Get certificate expiration date
  EXPIRY=$(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

  # Check if we got a valid expiry date
  if [ -z "$EXPIRY" ]; then
    ERROR_DOMAINS+=("$DOMAIN (doesn’t have a certificate)")
    continue
  fi

  # Convert to epoch time
  EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null)
  if [ $? -ne 0 ]; then
    ERROR_DOMAINS+=("$DOMAIN (invalid certificate expiry format)")
    continue
  fi
  NOW_EPOCH=$(date +%s)

  # Calculate days until expiry
  DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

  # Check if expiry is within the long or short timeframe
  if [ "$DAYS_LEFT" -le "$EXPIRATION_TIME_SHORT" ] && [ "$DAYS_LEFT" -ge 0 ]; then
    EXPIRING_SHORT+=("$DOMAIN ($DAYS_LEFT days)")
  elif [ "$DAYS_LEFT" -le "$EXPIRATION_TIME_LONG" ] && [ "$DAYS_LEFT" -gt "$EXPIRATION_TIME_SHORT" ] && [ "$DAYS_LEFT" -ge 0 ]; then
    EXPIRING_LONG+=("$DOMAIN ($DAYS_LEFT days)")
  fi
done < "$DOMAIN_LIST"

# Build the notification message
MSG=""

# Start heredoc for the message
if [ ${#EXPIRING_LONG[@]} -gt 0 ] || [ ${#EXPIRING_SHORT[@]} -gt 0 ] || [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
  read -r -d '' MSG <<EOT
Cert Expiry Bot Notice!

EOT
  # Explicitly add two line breaks after the header
  MSG+=$'\n\n'

  # Add long timeframe expirations
  if [ ${#EXPIRING_LONG[@]} -gt 0 ]; then
    read -r -d '' MSG_LONG <<EOT
📅 Certificates for the domains listed below will expire within $EXPIRATION_TIME_LONG days:

$(for DOMAIN in "${EXPIRING_LONG[@]}"; do echo "$DOMAIN"; done)

(Total of ${#EXPIRING_LONG[@]} affected domains)
EOT
    MSG+="$MSG_LONG"
  fi

  # Add short timeframe expirations
  if [ ${#EXPIRING_SHORT[@]} -gt 0 ]; then
    # Add two newlines before the short timeframe section if the long timeframe section exists
    if [ ${#EXPIRING_LONG[@]} -gt 0 ]; then
      MSG+=$'\n\n'
    fi
    read -r -d '' MSG_SHORT <<EOT
⏰ Certificates for the domains listed below will expire within $EXPIRATION_TIME_SHORT days:

$(for DOMAIN in "${EXPIRING_SHORT[@]}"; do echo "$DOMAIN"; done)

(Total of ${#EXPIRING_SHORT[@]} affected domains)
EOT
    MSG+="$MSG_SHORT"
  fi

  # Add separator if both expiration and error sections are present
  if [ ${#EXPIRING_LONG[@]} -gt 0 ] || [ ${#EXPIRING_SHORT[@]} -gt 0 ]; then
    if [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
      MSG+=$'\n\n'"════════════════════"
      MSG+=$'\n\n'
    fi
  fi

  # Add error section if there are any errors
  if [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
    read -r -d '' MSG_ERRORS <<EOT
❌ Certificate checks containing errors:

$(for ERROR in "${ERROR_DOMAINS[@]}"; do echo "$ERROR"; done)

(Total of ${#ERROR_DOMAINS[@]} affected domains)
EOT
    MSG+="$MSG_ERRORS"
  fi

  # Send notification
  send_notification  

fi

# Completion message
if [ -t 1 ]; then
  echo "Done"
fi