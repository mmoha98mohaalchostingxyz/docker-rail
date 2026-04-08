# 1. Use a stable Python version
FROM python:3.12-slim

# 2. Install System Dependencies (including ffmpeg from apt for better compatibility)
RUN apt-get update && \
    apt-get install -y curl unzip wget xz-utils ca-certificates ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# 3. Install Deno
ENV DENO_INSTALL=/usr/local
RUN curl -fsSL https://deno.land/x/install/install.sh | sh

# 4. Download and Install Xray-core
RUN curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip -o xray.zip xray && \
    mv xray /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    rm xray.zip

# 5. Set up working directory
WORKDIR /app

# 6. Copy project files
COPY . .

# 7. Create Xray Config File
RUN cat <<'EOF' > /app/config.json
{
  "inbounds": [{
    "port": 10808,
    "protocol": "socks",
    "settings": { "udp": true }
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "il1.vpnjantit.com",
        "port": 443,
        "users": [{
          "id": "6d2cca34-335a-11f1-b661-af67645aeea1",
          "encryption": "none",
          "flow": "xtls-rprx-vision"
        }]
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "publicKey": "2IngmHiqjpBvGW160GHT6bHy2I4maijrSIjJeEFRRlo",
        "shortId": "7b16eb7708db94e2",
        "sni": "cloudflare.com",
        "fingerprint": "chrome"
      }
    }
  }]
}
EOF

# 8. Create a Startup Script
RUN cat <<'EOF' > /app/start.sh
#!/bin/bash
echo "Starting Xray proxy..."
nohup xray run -c /app/config.json > /app/xray.log 2>&1 &

sleep 2

echo "Starting Python App..."
exec python app.py
EOF

RUN chmod +x /app/start.sh

# 9. Ensure the downloads folder exists
RUN mkdir -p /app/downloads && chmod 777 /app/downloads

# 10. Install Python Requirements
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir pysocks && \
    pip install --no-cache-dir -U -r requirements.txt "yt-dlp[default]" --pre

# 11. Environment Variables
ENV PORT=7860
ENV PYTHONUNBUFFERED=1
ENV ALL_PROXY="socks5h://127.0.0.1:10808"
ENV HTTP_PROXY="socks5h://127.0.0.1:10808"
ENV HTTPS_PROXY="socks5h://127.0.0.1:10808"

# 12. Run
CMD ["/app/start.sh"]
