#!/bin/sh
set -eu

APP_DIR=/home/xilinx/afsk_sms
SERVICE_NAME=afsk-sms.service

mkdir -p "$APP_DIR"
cp /home/xilinx/jupyter_notebooks/afsk_sms_receiver_service.py "$APP_DIR/" 2>/dev/null || true
cp /home/xilinx/jupyter_notebooks/base_add.bit "$APP_DIR/" 2>/dev/null || true
cp /home/xilinx/jupyter_notebooks/base_add.hwh "$APP_DIR/" 2>/dev/null || true
mkdir -p "$APP_DIR/systemd"
cp /home/xilinx/jupyter_notebooks/systemd/$SERVICE_NAME "$APP_DIR/systemd/" 2>/dev/null || true

if [ ! -f "$APP_DIR/afsk_sms_receiver_service.py" ]; then
    echo "Missing $APP_DIR/afsk_sms_receiver_service.py"
    echo "Copy afsk_sms_receiver_service.py, base_add.bit, and base_add.hwh to $APP_DIR first."
    exit 1
fi

if [ ! -f "$APP_DIR/base_add.bit" ] || [ ! -f "$APP_DIR/base_add.hwh" ]; then
    echo "Missing base_add.bit or base_add.hwh in $APP_DIR"
    exit 1
fi

python3 - <<'PY'
try:
    import serial
except ImportError:
    raise SystemExit("pyserial missing. Run: sudo pip3 install pyserial")
PY

if [ -f "$APP_DIR/systemd/$SERVICE_NAME" ]; then
    cp "$APP_DIR/systemd/$SERVICE_NAME" /etc/systemd/system/
else
    cp /home/xilinx/jupyter_notebooks/systemd/$SERVICE_NAME /etc/systemd/system/
fi
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"
systemctl status "$SERVICE_NAME" --no-pager
