#!/usr/bin/with-contenv bashio
set -ex

bashio::log.info "==================================================="
bashio::log.info " Starting TREK Add-on..."
bashio::log.info "==================================================="

# Ingress-Port auslesen (dynamisch von Home Assistant)
INGRESS_PORT=$(bashio::addon.ingress_port)
bashio::log.info "Ingress Port: ${INGRESS_PORT}"

# Timezone aus Config auslesen
TIMEZONE=$(bashio::config 'timezone')
if [ -n "${TIMEZONE}" ]; then
    bashio::log.info "Setting timezone to ${TIMEZONE}"
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    echo "${TIMEZONE}" > /etc/timezone
    export TZ="${TIMEZONE}"
fi

# Encryption Key prüfen/setzen
ENCRYPTION_KEY=$(bashio::config 'encryption_key')
if [ -z "${ENCRYPTION_KEY}" ]; then
    bashio::log.info "No encryption key provided, generating one..."
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    bashio::log.info "Generated encryption key: ${ENCRYPTION_KEY}"
    bashio::log.warning "Please save this key in your add-on config to avoid data loss on restart!"
fi
export ENCRYPTION_KEY

# Persistenz-Verzeichnisse erstellen (falls nicht vorhanden)
bashio::log.info "Setting up persistent directories..."
mkdir -p /data/logs /data/uploads/files /data/uploads/covers /data/uploads/avatars /data/uploads/photos

# Symlinks für TREK (wie im Original Dockerfile)
mkdir -p /app/data /app/uploads
ln -sf /data/logs /app/data/logs 2>/dev/null || true
ln -sf /data/uploads /app/uploads 2>/dev/null || true

# Berechtigungen setzen (für den aktuellen Benutzer)
chown -R $(id -u):$(id -g) /app/data /app/uploads /data 2>/dev/null || true
chmod -R 755 /app/data /app/uploads /data 2>/dev/null || true

# Umgebungsvariablen für TREK setzen
export PORT=${INGRESS_PORT}
export NODE_ENV=production

bashio::log.info "Starting TREK server on port ${PORT}..."
bashio::log.info "Working directory: $(pwd)"

# Arbeitsverzeichnis setzen
cd /app
bashio::log.info "Changed to directory: $(pwd)"

# TREK starten - exec ersetzt den aktuellen Prozess
# Kein su-exec, kein dumb-init - läuft direkt im Container
# tsx wird lokal in node_modules installiert, daher PATH erweitern
export PATH="/app/node_modules/.bin:$PATH"
exec node --import tsx src/index.ts
