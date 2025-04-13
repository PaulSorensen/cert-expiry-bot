# Cert Expiry Bot

## Overview

**Cert Expiry Bot** is a Bash script that monitors SSL certificates for multiple domains and sends Telegram alerts if they are expiring soon. It checks for expirations within 14 and 7 days (configurable) and includes error handling for invalid domains or missing certificates.

## Features

- Monitors SSL certificates for multiple domains.
- Sends Telegram alerts for certificates expiring within 14 days (long timeframe) and 7 days (short timeframe).
- Configurable expiration thresholds via `cert_expiry_bot.conf`.
- Includes error handling for invalid domains or missing certificates.
- Easy to set up with a Telegram bot for notifications.

## Requirements

Before running the script, ensure that:

- You have a **Telegram bot** set up with a bot token and chat ID.
- **OpenSSL** is installed to check SSL certificates.
- **curl** is installed to send Telegram messages.

## Usage

1. **Set up a Telegram bot**:
   
   - Create a Telegram bot using [BotFather](https://t.me/BotFather) to get your bot token.
   - Send a message to your bot (e.g., “Hi”).
   - Get chat ID: Open https://api.telegram.org/bot<your_bot_token>/getUpdates.
     Find “chat”:{“id”:<your_chat_id> (e.g., <your_chat_id>).

2. **Configure Telegram settings**:
   
   - Copy `.env.example` to .env:
     
     ```bash
     cp .env.example .env
     ```
   
   - Edit .env and add your `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.
   
   - Secure .env
     
     ```bash
     chmod 600 .env 
     ```

3. **Add domains to monitor**:
   
   - Copy `cert_expiry_bot.txt.example` to `cert_expiry_bot.txt`:
     
     ```bash
     cp cert_expiry_bot.txt.example cert_expiry_bot.txt
     ```
   
   - Edit `cert_expiry_bot.txt` and add one domain per line (e.g., domain1.com).

4. **Make the script executable**:
   
   ```bash
   chmod +x cert_expiry_bot.sh
   ```

5. **Test the script**:
   
   - To test, set `EXPIRATION_TIME_LONG` to 90 in `cert_expiry_bot.conf` (since domains typically renew 30 days before expiry, this will likely trigger alerts for most domains).
   
   - Run the script manually:
     
     ```bash
     ./cert_expiry_bot.sh
     ```

6. **Schedule daily checks at 12:00 (noon)**:
   
   - Open crontab:
     
     ```bash
     crontab -e
     ```
   
   - Add the following line to run at 12:00 every day (replace the path with your actual path):
     
     ```bash
     0 12 * * * /home/admin/scripts/cronjobs/cert-expiry-bot/cert_expiry_bot.sh
     ```

## Configuration

**Telegram Settings**:

- Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env` (copy from `.env.example`).
  
  **Domain List**:

- Add domains to `cert_expiry_bot.txt` (copy from `cert_expiry_bot.txt.example`). 
  
  **Expiration Thresholds**:

- The script checks for certificates expiring within 14 days (`EXPIRATION_TIME_LONG`) and 7 days (`EXPIRATION_TIME_SHORT`). Modify these in `cert_expiry_bot.conf`.

## Important Notes

- The script uses openssl to check SSL certificates, so the domains must be accessible over HTTPS on port 443.

## Enjoying This Script?

**If you found this script useful, a small tip is appreciated ❤️**
[https://buymeacoffee.com/paulsorensen](https://buymeacoffee.com/paulsorensen)

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License.

**Legal Notice:** If you edit and redistribute this code, you must mention the original author, **Paul Sørensen** ([paulsorensen.io](https://paulsorensen.io)), in the redistributed code or documentation.

**Copyright (C) 2025 Paul Sørensen ([paulsorensen.io](https://paulsorensen.io))**

See the LICENSE file in this repository for the full text of the GNU General Public License v3.0, or visit [https://www.gnu.org/licenses/gpl-3.0.txt](https://www.gnu.org/licenses/gpl-3.0.txt).