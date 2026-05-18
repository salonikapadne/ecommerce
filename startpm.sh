#!/bin/sh

APPS="
todo|$HOME/to-do-app/server|$HOME/to-do-app/client
blog1|$HOME/blog1/backend|$HOME/blog1/frontend
blog|$HOME/blog/Backend|$HOME/blog/Frontend
ecomm|$HOME/ecommerce/backend|$HOME/ecommerce/frontend
event|$HOME/event/backend|$HOME/event/frontend
"

GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

STARTED=""
FAILED=""
USED_PORTS=""
RESERVED_PORT=""
PUBLIC_IP=""

log_started() { STARTED="$STARTED\n$1"; }
log_failed() { FAILED="$FAILED\n$1"; }

read_port() {
  ENV_FILE="$1"
  MODE="$2"
  if [ ! -f "$ENV_FILE" ]; then echo ""; return; fi
  if [ "$MODE" = "backend" ]; then
    grep -E "^PORT=" "$ENV_FILE" | tail -n 1 | cut -d"=" -f2- | tr -d "\r" | xargs
  else
    grep -E "^(PORT|VITE_PORT)=" "$ENV_FILE" | head -n 1 | cut -d"=" -f2- | tr -d "\r" | xargs
  fi
}

normalize_port() {
  RAW="$1"; DEF="$2"
  case "$RAW" in ""|*[!0-9]*) RAW="$DEF" ;; esac
  if [ "$RAW" -lt 1024 ] || [ "$RAW" -gt 65535 ]; then RAW="$DEF"; fi
  echo "$RAW"
}

is_port_taken() {
  P="$1"
  echo "$USED_PORTS" | tr ' ' '\n' | grep -qx "$P"
}

reserve_port() {
  P="$1"
  while is_port_taken "$P"; do
    P=$((P + 1))
    if [ "$P" -gt 65535 ]; then
      P=3000
    fi
  done
  USED_PORTS="$USED_PORTS $P"
  RESERVED_PORT="$P"
}

upsert_env() {
  FILE="$1"
  KEY="$2"
  VALUE="$3"

  touch "$FILE"
  if grep -qE "^${KEY}=" "$FILE"; then
    sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$FILE"
  else
    printf '%s=%s\n' "$KEY" "$VALUE" >> "$FILE"
  fi
}

sync_frontend_env_ip() {
  FRONT_DIR="$1"
  BACK_PORT="$2"
  ENV_FILE="$FRONT_DIR/.env"

  [ -n "$PUBLIC_IP" ] || return 0

  API_URL="http://$PUBLIC_IP:$BACK_PORT"

  upsert_env "$ENV_FILE" "PUBLIC_IP" "$PUBLIC_IP"
  upsert_env "$ENV_FILE" "API_URL" "$API_URL"
  upsert_env "$ENV_FILE" "VITE_API_URL" "$API_URL"
  upsert_env "$ENV_FILE" "REACT_APP_API_URL" "$API_URL"
  upsert_env "$ENV_FILE" "NEXT_PUBLIC_API_URL" "$API_URL"
  upsert_env "$ENV_FILE" "BACKEND_URL" "$API_URL"

  # Repoint any stale hardcoded AWS public IP host in existing URLs to current IP.
  sed -E -i "s|https?://[0-9]{1,3}(\.[0-9]{1,3}){3}:|http://$PUBLIC_IP:|g" "$ENV_FILE"
}

install_deps() {
  DIR="$1"
  [ -d "$DIR" ] || return 1
  cd "$DIR" || return 1
  [ -f package.json ] || return 1
  if [ ! -d node_modules ]; then
    npm install --no-audit --no-fund >/tmp/startpm-npm-install.log 2>&1 || return 1
  fi
  return 0
}

start_backend() {
  APP_KEY="$1"; BACK_DIR="$2"; BACK_PORT="$3"
  PM2_BACK_NAME="${APP_KEY}-back-${BACK_PORT}"
  pm2 delete "$PM2_BACK_NAME" >/dev/null 2>&1

  if ! install_deps "$BACK_DIR"; then
    log_failed "$APP_KEY backend: dependency install failed"
    printf "${RED}  backend dependency install failed in %s${NC}\n" "$BACK_DIR"
    return
  fi

  cd "$BACK_DIR" || { log_failed "$APP_KEY backend: cannot cd"; return; }

  if npm run | grep -q " start"; then
    PORT="$BACK_PORT" pm2 start npm --name "$PM2_BACK_NAME" -- run start >/tmp/startpm-back.log 2>&1
  elif [ -f index.js ]; then
    PORT="$BACK_PORT" pm2 start index.js --name "$PM2_BACK_NAME" >/tmp/startpm-back.log 2>&1
  elif [ -f server.js ]; then
    PORT="$BACK_PORT" pm2 start server.js --name "$PM2_BACK_NAME" >/tmp/startpm-back.log 2>&1
  elif [ -f app.js ]; then
    PORT="$BACK_PORT" pm2 start app.js --name "$PM2_BACK_NAME" >/tmp/startpm-back.log 2>&1
  elif npm run | grep -q " dev"; then
    PORT="$BACK_PORT" pm2 start npm --name "$PM2_BACK_NAME" -- run dev >/tmp/startpm-back.log 2>&1
  else
    log_failed "$APP_KEY backend: no runnable entry"
    printf "${RED}  no runnable backend entry found in %s${NC}\n" "$BACK_DIR"
    return
  fi

  if [ $? -eq 0 ]; then
    log_started "$PM2_BACK_NAME"
    printf "${GREEN}  backend started: %s${NC}\n" "$PM2_BACK_NAME"
  else
    log_failed "$APP_KEY backend: pm2 start failed"
    printf "${RED}  backend pm2 start failed for %s${NC}\n" "$PM2_BACK_NAME"
  fi
}

start_frontend() {
  APP_KEY="$1"; FRONT_DIR="$2"; FRONT_PORT="$3"; BACK_PORT="$4"
  PM2_FRONT_NAME="${APP_KEY}-front-${FRONT_PORT}"
  pm2 delete "$PM2_FRONT_NAME" >/dev/null 2>&1

  if ! install_deps "$FRONT_DIR"; then
    log_failed "$APP_KEY frontend: dependency install failed"
    printf "${RED}  frontend dependency install failed in %s${NC}\n" "$FRONT_DIR"
    return
  fi

  sync_frontend_env_ip "$FRONT_DIR" "$BACK_PORT"

  cd "$FRONT_DIR" || { log_failed "$APP_KEY frontend: cannot cd"; return; }

  npm run build >/tmp/startpm-front-build.log 2>&1
  if [ $? -ne 0 ]; then
    log_failed "$APP_KEY frontend: build failed"
    printf "${RED}  frontend build failed in %s${NC}\n" "$FRONT_DIR"
    return
  fi

  BUILD_FOLDER=""
  if [ -d dist ]; then BUILD_FOLDER="dist"; elif [ -d build ]; then BUILD_FOLDER="build"; else
    log_failed "$APP_KEY frontend: build output missing"
    printf "${RED}  frontend build output not found in %s${NC}\n" "$FRONT_DIR"
    return
  fi

  pm2 serve "$BUILD_FOLDER" "$FRONT_PORT" --name "$PM2_FRONT_NAME" --spa >/tmp/startpm-front-serve.log 2>&1
  if [ $? -eq 0 ]; then
    log_started "$PM2_FRONT_NAME"
    printf "${GREEN}  frontend started: %s${NC}\n" "$PM2_FRONT_NAME"
  else
    log_failed "$APP_KEY frontend: pm2 serve failed"
    printf "${RED}  frontend pm2 serve failed for %s${NC}\n" "$PM2_FRONT_NAME"
  fi
}

TOKEN=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" --connect-timeout 2 2>/dev/null || true)
if [ -n "$TOKEN" ]; then
  PUBLIC_IP=$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)
else
  PUBLIC_IP=$(curl -fsS --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)
fi

printf "${YELLOW}=== STARTING MATRIX DEPLOYMENT ===${NC}\n"
if [ -n "$PUBLIC_IP" ]; then
  printf "${CYAN}Detected public IP: %s${NC}\n" "$PUBLIC_IP"
else
  printf "${YELLOW}Could not detect public IP from metadata service. Keeping existing frontend env host values.${NC}\n"
fi

printf "${CYAN}[1/3] Resetting PM2...${NC}\n"
pm2 kill >/dev/null 2>&1 || true
pkill -f "node" >/dev/null 2>&1 || true
printf "${GREEN}  reset complete${NC}\n"

printf "${CYAN}[2/3] Processing app matrix...${NC}\n"
for APP_LINE in $APPS; do
  [ -z "$APP_LINE" ] && continue
  APP_KEY=$(echo "$APP_LINE" | cut -d"|" -f1)
  BACK_DIR=$(echo "$APP_LINE" | cut -d"|" -f2)
  FRONT_DIR=$(echo "$APP_LINE" | cut -d"|" -f3)

  printf "\n${YELLOW}> app: %s${NC}\n" "$APP_KEY"

  BACK_PORT="5000"
  if [ -d "$BACK_DIR" ]; then
    RAW_BACK_PORT=$(read_port "$BACK_DIR/.env" "backend")
    BACK_PORT=$(normalize_port "$RAW_BACK_PORT" "5000")
    reserve_port "$BACK_PORT"
    BACK_PORT="$RESERVED_PORT"
    printf "  backend dir: %s (port %s)\n" "$BACK_DIR" "$BACK_PORT"
    start_backend "$APP_KEY" "$BACK_DIR" "$BACK_PORT"
  else
    log_failed "$APP_KEY backend: missing directory $BACK_DIR"
    printf "${RED}  backend directory missing: %s${NC}\n" "$BACK_DIR"
  fi

  if [ -d "$FRONT_DIR" ]; then
    RAW_FRONT_PORT=$(read_port "$FRONT_DIR/.env" "frontend")
    FRONT_PORT=$(normalize_port "$RAW_FRONT_PORT" "3000")
    reserve_port "$FRONT_PORT"
    FRONT_PORT="$RESERVED_PORT"
    if [ "$RAW_FRONT_PORT" != "$FRONT_PORT" ]; then
      printf "${YELLOW}  frontend port adjusted from '%s' to '%s'${NC}\n" "$RAW_FRONT_PORT" "$FRONT_PORT"
    fi
    printf "  frontend dir: %s (port %s)\n" "$FRONT_DIR" "$FRONT_PORT"
    start_frontend "$APP_KEY" "$FRONT_DIR" "$FRONT_PORT" "$BACK_PORT"
  else
    log_failed "$APP_KEY frontend: missing directory $FRONT_DIR"
    printf "${RED}  frontend directory missing: %s${NC}\n" "$FRONT_DIR"
  fi
done

printf "\n${CYAN}[3/3] Saving PM2 state...${NC}\n"
pm2 save >/dev/null 2>&1 || true
printf "\n${GREEN}Started services:${NC}\n"
printf "%b\n" "$STARTED" | sed '/^$/d'
printf "\n${YELLOW}Failed services:${NC}\n"
printf "%b\n" "$FAILED" | sed '/^$/d'
printf "\n${CYAN}PM2 status:${NC}\n"
pm2 list
