FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    imagemagick \
    bc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY create-filmgrain.sh .
RUN chmod +x create-filmgrain.sh

ENTRYPOINT ["./create-filmgrain.sh"]