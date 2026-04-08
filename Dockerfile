# 1. Use a stable Python version
FROM python:3.12-slim

# 2. Install System Dependencies
RUN apt-get update && \
    apt-get install -y curl unzip wget xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 3. Download and install FFmpeg
RUN wget https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz && \
    tar -xf ffmpeg-master-latest-linux64-gpl.tar.xz && \
    mv ffmpeg-master-latest-linux64-gpl/bin/ffmpeg /usr/local/bin/ffmpeg && \
    mv ffmpeg-master-latest-linux64-gpl/bin/ffprobe /usr/local/bin/ffprobe && \
    mv ffmpeg-master-latest-linux64-gpl/bin/ffplay /usr/local/bin/ffplay && \
    rm -rf ffmpeg-master-latest-linux64-gpl.tar.xz ffmpeg-master-latest-linux64-gpl

# 4. Install Deno
ENV DENO_INSTALL=/usr/local
RUN curl -fsSL https://deno.land/x/install/install.sh | sh

# 5. Download and Install Xray-core
RUN curl -L -o xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip -o xray.zip xray && \
    mv xray /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    rm xray.zip

# 6. Set up working directory
WORKDIR /app

# 7. Copy project files
COPY . .

# 8. Create Xray Config File
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

# 9. Create a Startup Script
RUN cat <<'EOF' > /app/start.sh
#!/bin/bash
echo "Starting Xray proxy..."
nohup xray run -c /app/config.json > /app/xray.log 2>&1 &

sleep 2

echo "Starting Python App..."
exec python app.py
EOF

RUN chmod +x /app/start.sh

# 10. Ensure the downloads folder exists
RUN mkdir -p /app/downloads

# 11. Install Python Requirements as root
# Removed 'USER user' to avoid permission issues with Railway volumes
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir pysocks && \
    pip install --no-cache-dir -U -r requirements.txt "yt-dlp[default]" --pre

# 12. Environment Variables
ENV PORT=7860
ENV PYTHONUNBUFFERED=1
ENV ALL_PROXY="socks5h://127.0.0.1:10808"
ENV HTTP_PROXY="socks5h://127.0.0.1:10808"
ENV HTTPS_PROXY="socks5h://127.0.0.1:10808"
ENV all_proxy="socks5h://127.0.0.1:10808"
ENV http_proxy="socks5h://127.0.0.1:10808"
ENV https_proxy="socks5h://127.0.0.1:10808"

# 13. Run
CMD ["/app/start.sh"]
