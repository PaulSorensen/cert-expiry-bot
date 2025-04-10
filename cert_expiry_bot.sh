#!/bin/bash
################################################################################
#  Script Name : Cert Expiry Bot
#  Author      : Paul Sørensen
#  Website     : https://paulsorensen.io
#  GitHub      : https://github.com/paulsorensen
#  Version     : 1.0
#  Last Update : 10.04.2025
#
#  Description:
#  Monitors SSL certificates for domains listed in cert_expiry_bot.txt and sends
#  Telegram alerts if they expire within 14 or 7 days (configurable).
#
#  Usage:
#  1. Set up a Telegram bot and add your bot token and chat ID to .env
#     (copy .env.example, rename to .env, and edit:
#     TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID).
#  2. Add domains to cert_expiry_bot.txt (copy cert_expiry_bot.txt.example to
#     cert_expiry_bot.txt and edit).
#  3. Make the script executable: chmod +x cert_expiry_bot.sh
#  4. Test the script: Set EXPIRATION_TIME_LONG to 90 in cert_expiry_bot.conf
#     and run ./cert_expiry_bot.sh
#  5. Schedule daily checks at 12:00 (noon): Add to cron (crontab -e):
#     0 12 * * * /path/to/cert-expiry-bot/cert_expiry_bot.sh
#
#  Configuration:
#  - Adjust expiration thresholds (EXPIRATION_TIME_LONG, EXPIRATION_TIME_SHORT)
#  in cert_expiry_bot.conf if needed, or keep it as is.
#
#  If you found this script useful, a small tip is appreciated ❤️
#  https://buymeacoffee.com/paulsorensen
################################################################################

BLUE='\033[38;5;81m'
RED='\033[38;5;203m'
NC='\033[0m'
echo -e "${BLUE}Cert Expiry Bot by paulsorensen.io${NC}"
echo ""

# Check if .env exists
if [ ! -f ".env" ]; then
  echo -e "${RED}Error: .env file not found. Make sure to edit and rename .env.example before you run this script${NC}"
  exit 1
fi

# Include sources
source ./.env
source ./cert_expiry_bot.conf

# Path to the domain list file
DOMAIN_LIST="cert_expiry_bot.txt"

# Check if cert_expiry_bot.txt exists, if not, prompt to create it
if [ ! -f "$DOMAIN_LIST" ]; then
  if [ -f "cert_expiry_bot.txt.example" ]; then
    echo -e "${RED}Error: $DOMAIN_LIST not found. Please create it by copying cert_expiry_bot.txt.example:${NC}"
    echo -e "${RED}  cp cert_expiry_bot.txt.example $DOMAIN_LIST${NC}"
    echo -e "${RED}Then edit $DOMAIN_LIST to add your domains.${NC}"
  else
    echo -e "${RED}Error: $DOMAIN_LIST and cert_expiry_bot.txt.example not found!${NC}"
  fi
  exit 1
fi

# Check Telegram connection
RESPONSE=$(curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe")
if [ $? -ne 0 ] || echo "$RESPONSE" | grep -q '"error_code":404'; then
  echo -e "${RED}Error: Can't connect to Telegram Bot. Please check your TELEGRAM_BOT_TOKEN${NC}"
  exit 1
fi

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
  EXPIRY=$(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)

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

# Build the Telegram message using a heredoc with HTML formatting
MSG=""

# Start the heredoc for the message
if [ ${#EXPIRING_LONG[@]} -gt 0 ] || [ ${#EXPIRING_SHORT[@]} -gt 0 ] || [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
  read -r -d '' MSG <<EOT
<b>Cert Expiry Bot Notice!</b>
EOT
  # Explicitly add two line breaks after the header
  MSG+=$'\n\n'

  # Add long timeframe expirations
  if [ ${#EXPIRING_LONG[@]} -gt 0 ]; then
    read -r -d '' MSG_LONG <<EOT
Certificates for the domains listed below will expire within $EXPIRATION_TIME_LONG days:

$(for DOMAIN in "${EXPIRING_LONG[@]}"; do echo "$DOMAIN"; done)

<b>Total of ${#EXPIRING_LONG[@]} affected domains.</b>
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
Certificates for the domains listed below will expire within $EXPIRATION_TIME_SHORT days:

$(for DOMAIN in "${EXPIRING_SHORT[@]}"; do echo "$DOMAIN"; done)

<b>Total of ${#EXPIRING_SHORT[@]} affected domains.</b>
EOT
    MSG+="$MSG_SHORT"
  fi

  # Add separator if both expiration and error sections are present
  if [ ${#EXPIRING_LONG[@]} -gt 0 ] || [ ${#EXPIRING_SHORT[@]} -gt 0 ]; then
    if [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
      MSG+=$'\n\n'"$DIVIDER"
      MSG+=$'\n\n'
    fi
  fi

  # Add error section if there are any errors
  if [ ${#ERROR_DOMAINS[@]} -gt 0 ]; then
    read -r -d '' MSG_ERRORS <<EOT
<b>Certificate checks containing errors:</b>

$(for ERROR in "${ERROR_DOMAINS[@]}"; do echo "$ERROR"; done)

<b>Total of ${#ERROR_DOMAINS[@]} affected domains.</b>
EOT
    MSG+="$MSG_ERRORS"
  fi
fi

# Send the Telegram message if there’s anything to report
if [ -n "$MSG" ]; then
  curl -s --data chat_id="$TELEGRAM_CHAT_ID" \
    --data-urlencode "text=$MSG" \
    "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage?parse_mode=HTML"
fi