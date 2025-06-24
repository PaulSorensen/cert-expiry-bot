# Cert Expiry Bot

[![Badge](https://img.shields.io/badge/License-MIT-97CA00)](/LICENSE)
[![Badge](https://img.shields.io/badge/-Buy%20Me%20a%20Coffee-dab728?logo=buymeacoffee&logoColor=white)](https://buymeacoffee.com/paulsorensen)

**Cert Expiry Bot** is a Bash script that monitors SSL certificates for multiple domains and sends notifications if they are expiring soon. It checks for expirations within 14 and 7 days (configurable), and includes error handling for invalid domains or missing certificates.

---

## Features

- Monitors SSL certificates for multiple domains.
- Sends notifications for certificates expiring within configurable thresholds.
- Supports multiple notification methods:
  - [ntfy](https://ntfy.sh)
  - Telegram Bot
  - Webhook
- Includes error handling for invalid domains or missing certificates.
- Easy configuration via `.env` and `.conf` files.

---

## Requirements

- `curl` and `openssl` must be installed.
- At least one notification method must be configured in `.env`.

---

## Usage

1. **Configure environment**:

   - Copy `.env.example` to `.env`:

     ```bash
     cp .env.example .env
     ```

   - Edit `.env` and set one or more of the following:

     ```dotenv
     # ntfy
     NTFY_TOPIC=server-topic-123

     # Telegram
     TELEGRAM_BOT_TOKEN=1234567890:ABC
     TELEGRAM_CHAT_ID=9876543210

     # Webhook
     WEBHOOK_URL=https://webhook.domain.com/endpoint
     ```

   - Secure the file:

     ```bash
     chmod 600 .env
     ```

2. **Add domains to monitor**:

   - Copy `cert_expiry_bot.txt.example` to `cert_expiry_bot.txt`:

     ```bash
     cp cert_expiry_bot.txt.example cert_expiry_bot.txt
     ```

   - Edit `cert_expiry_bot.txt` and add one domain per line (e.g., domain1.com).

3. **Configure thresholds**:

   - Edit `cert_expiry_bot.conf` and adjust if needed, or leave default values:

     ```bash
     EXPIRATION_TIME_SHORT=7
     EXPIRATION_TIME_LONG=14
     ```

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

6. **Schedule a cron job**:

   - Edit your crontab:

     ```bash
     crontab -e
     ```

   - Add this line to run every day at 12:00:

     ```bash
     0 12 * * * /path/to/cert_expiry_bot.sh
     ```

---

## Important Notes

- The script uses openssl to check SSL certificates, so the domains must be accessible over HTTPS on port 443.

---

## Author

**Paul Sørensen**  
[https://paulsorensen.io](https://paulsorensen.io)  
[https://github.com/paulsorensen](https://github.com/paulsorensen)

---

## Support

If you found this project useful, a small tip is appreciated ❤️  
[https://buymeacoffee.com/paulsorensen](https://buymeacoffee.com/paulsorensen)

---

## License

This project is licensed under the MIT License.  
See [LICENSE](LICENSE) for details.
