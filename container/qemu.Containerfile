# Build the repo's SH-4 QEMU board in an isolated Debian environment.
FROM ghcr.io/astral-sh/uv:0.12.23 AS uv
FROM debian:trixie-slim
COPY --from=uv /uv /uvx /usr/local/bin/

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates git build-essential patch pkg-config python3 python3-tk \
      meson ninja-build libglib2.0-dev libpixman-1-dev zlib1g-dev \
 && UV_CACHE_DIR=/tmp/uv-cache uv venv --python /usr/bin/python3 --system-site-packages --seed /opt/uv-python \
 && UV_CACHE_DIR=/tmp/uv-cache uv pip install --python /opt/uv-python/bin/python setuptools Pillow numpy \
 && rm -rf /var/lib/apt/lists/* /tmp/uv-cache

# QEMU's configure uses this uv-managed Python as the parent for its own venv.
ENV PYTHON=/opt/uv-python/bin/python
ENV PATH="/opt/uv-python/bin:${PATH}"

COPY container/build-qemu.sh /usr/local/bin/build-qemu
RUN chmod 0755 /usr/local/bin/build-qemu
ENTRYPOINT ["/usr/local/bin/build-qemu"]
