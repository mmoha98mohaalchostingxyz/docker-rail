FROM python:3.12-slim

# 1. Install System Dependencies
RUN apt-get update && \
    apt-get install -y curl unzip wget xz-utils ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# 2. Download and install FFmpeg from BtbN
RUN wget https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz && \
    tar -xf ffmpeg-master-latest-linux64-gpl.tar.xz && \
    mv ffmpeg-master-latest-linux64-gpl/bin/ffmpeg /usr/local/bin/ffmpeg && \
    mv ffmpeg-master-latest-linux64-gpl/bin/ffprobe /usr/local/bin/ffprobe && \
    mv ffmpeg-master-latest-linux64-gpl/bin/ffplay /usr/local/bin/ffplay && \
    rm -rf ffmpeg-master-latest-linux64-gpl.tar.xz ffmpeg-master-latest-linux64-gpl

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

# 6. Create a non-root user (Required by Hugging Face Spaces)
RUN useradd -m -u 1000 user

# 7. Copy ALL project files
COPY --chown=user:user . .

# 8. Create Xray Config File dynamically
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

# 9. Create a Startup Script (Starts Xray in background, then Python in foreground)
RUN cat <<'EOF' > /app/start.sh
#!/bin/bash
echo "Starting Xray proxy..."
nohup xray run -c /app/config.json > /app/xray.log 2>&1 &

# Wait 2 seconds for Xray to establish connection
sleep 2

echo "Starting Python App..."
# 'exec' replaces the bash process with python, gracefully handling stop signals
exec python app.py
EOF

# Make start script executable and fix permissions
RUN chmod +x /app/start.sh && \
    chown user:user /app/config.json /app/start.sh

# 10. Ensure the downloads folder exists with correct permissions
RUN mkdir -p /app/downloads && chown -R user:user /app

# 11. Switch to the Hugging Face user
USER user

# 12. Install Python Requirements (pysocks added here)
ENV PATH="/home/user/.local/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir pysocks && \
    pip install --no-cache-dir -U -r requirements.txt "yt-dlp[default]" --pre

# 13. Environment Variables
ENV PORT=7860
ENV PYTHONUNBUFFERED=1

# Proxy settings so yt-dlp and python requests use Xray automatically
ENV ALL_PROXY="socks5h://127.0.0.1:10808"
ENV HTTP_PROXY="socks5h://127.0.0.1:10808"
ENV HTTPS_PROXY="socks5h://127.0.0.1:10808"
ENV all_proxy="socks5h://127.0.0.1:10808"
ENV http_proxy="socks5h://127.0.0.1:10808"
ENV https_proxy="socks5h://127.0.0.1:10808"

# 14. Run via wrapper script
CMD ["/app/start.sh"]