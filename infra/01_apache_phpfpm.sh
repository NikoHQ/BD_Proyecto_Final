#!/usr/bin/env bash
# Conecta Apache 2.4 con PHP-FPM por socket Unix (Arch/CachyOS).
# Uso: sudo bash infra/01_apache_phpfpm.sh
set -euo pipefail

CONF=/etc/httpd/conf/httpd.conf
MARKER='# --- PHP-FPM (INF324) ---'

if [[ ${EUID} -ne 0 ]]; then
    echo "Ejecutar con sudo." >&2
    exit 1
fi

if [[ ! -f ${CONF} ]]; then
    echo "No existe ${CONF}" >&2
    exit 1
fi

STAMP=$(date +%Y%m%d-%H%M%S)
cp -a "${CONF}" "${CONF}.bak-${STAMP}"
echo "Respaldo: ${CONF}.bak-${STAMP}"

# 1. Modulos de proxy (vienen comentados por defecto)
sed -i 's|^#LoadModule proxy_module modules/mod_proxy.so|LoadModule proxy_module modules/mod_proxy.so|' "${CONF}"
sed -i 's|^#LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|' "${CONF}"

# 2. index.php con prioridad sobre index.html
sed -i 's|^[[:space:]]*DirectoryIndex index.html[[:space:]]*$|    DirectoryIndex index.php index.html|' "${CONF}"

# 3. Handler hacia el socket de php-fpm
if ! grep -qF "${MARKER}" "${CONF}"; then
    cat >> "${CONF}" <<'EOF'

# --- PHP-FPM (INF324) ---
ServerName localhost
<FilesMatch \.php$>
    SetHandler "proxy:unix:/run/php-fpm/php-fpm.sock|fcgi://localhost/"
</FilesMatch>
EOF
fi

# 4. Validar y arrancar
httpd -t
systemctl enable --now php-fpm
systemctl enable --now httpd
systemctl --no-pager --lines=0 status php-fpm httpd

# 5. Pagina de prueba (borrar despues de validar)
cat > /srv/http/info.php <<'EOF'
<?php
echo 'PHP ' . PHP_VERSION . '<br>';
echo 'oci8: ' . (extension_loaded('oci8') ? 'OK' : 'FALTA') . '<br>';
EOF
chown http:http /srv/http/info.php

echo
echo "Prueba: curl -s http://127.0.0.1/info.php"
