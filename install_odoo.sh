#!/bin/bash
# Instalación de Odoo desde código fuente + entorno virtual

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export TERM=xterm-256color

log()   { echo -e "   \033[1;30m▍\033[0m  $*"; }                           # gris oscuro   – información normal
info()  { echo -e "   \033[1;34m→\033[0m  $*"; }                           # azul          – acción que empieza
ok()    { echo -e "   \033[1;32m✓\033[0m  $*"; }                           # verde         – éxito
warn()  { echo -e "   \033[1;33m⚠\033[0m  $*"; }                           # amarillo      – advertencia
error() { echo -e "   \033[1;31m✗\033[0m  $*"; }                           # rojo          – error (no sale del script)
fail()  { echo -e "   \033[1;31m✗\033[0m  $*"; exit 1; }                   # rojo + mata el script
debug() { [[ "$DEBUG" == "1" ]] && echo -e "   \033[1;35m⋯\033[0m  $*"; }  # solo si DEBUG=1
title() { echo -e "\n\033[1;36m━━ $*\033[0m\n"; }                          # título grande cian

title "Odoo + Debian/Ubuntu = ❤️\nScript libre, sin trabas y hecho para que la comunidad siga creciendo"
cat <<EOF
¡Listo!
Acá te dejo mi script de instalación de Odoo para Debian/Ubuntu. Es totalmente gratis.

Dicho eso... si algún día instalás Odoo con este script, te ahorra unas cuantas horas
(o dolores de cabeza) y te pinta decirme "¡gracias, crack!"...
¡te dejo abajo mi botón mágico de Cafecito!

Cero drama, ni obligación. Si te sirve y te hace la vida más fácil ya estoy hecho 🤗

→ https://cafecito.app/jldalla ☕✨

¡Éxitos con tu Odoo y que los logs siempre estén de tu lado! 🚀

— JL
EOF
# read -p "Presiona ENTER para continuar..."

apt_update() {
    sudo apt-get update -qq > /dev/null
}

apt_install() {
    local pkgs="$*"

    sudo apt-get install -y -qq --no-install-recommends $pkgs > /dev/null 2>&1 || {
        error "Falló instalación de: $pkgs"
        return 1
    }
}

choose_odoo_branch() {
    ODOO_BRANCHS=$(git ls-remote --heads https://github.com/odoo/odoo.git 2>/dev/null \
                       | sed 's|.*/heads/||' \
                       | grep -E '^[0-9]+\.[0-9]+$' \
                       | sort -Vr \
                       | awk '{print $1 " \"" $1 "\""}'
    )
    whiptail --title "Odoo - Versión estable" \
                   --menu "Elige la versión que deseas usar" \
                   18 60 10 \
                   ${ODOO_BRANCHS} \
                   3>&1 1>&2 2>&3
}

install_wkhtmltopdf() {
    if [[ "$DISTRO_ID" == "ubuntu" ]]; then
        apt_install wkhtmltopdf
    else
        curl -sL -o "${WKHTMLTOPDF_FILE}" "${WKHTMLTOPDF_LINK}"
        apt_install ${WKHTMLTOPDF_FILE}
        rm -f ${WKHTMLTOPDF_FILE}
    fi
}

# Detectar distribución y versión
. /etc/os-release
DISTRO_ID="${ID}"
DISTRO_NAME="${NAME}"
DISTRO_VERSION_ID="${VERSION_ID}"
DISTRO_VERSION="${VERSION}"
title "Distribución detectada: ${DISTRO_NAME} ${DISTRO_VERSION}"

apt_update
ok "Repositorios actualizados"

apt_install git pwgen
ok "Aplicaciones requeridas instaladas"

ODOO_BRANCH=$(choose_odoo_branch)
ODOO_USER="odoo"
ODOO_PASS=$(pwgen --ambiguous --capitalize --numerals 16 1)
ODOO_HOME="/opt/${ODOO_USER}"
ODOO_BRANCH_HOME="${ODOO_HOME}/odoo_${ODOO_BRANCH}"
CUSTOM_ADDONS="${ODOO_BRANCH_HOME}/custom_addons"
VENV_DIR="$ODOO_BRANCH_HOME/venv"
ODOO_CONFIG="$ODOO_BRANCH_HOME/odoo.conf"
ODOO_LOG="$ODOO_BRANCH_HOME/odoo-server.log"
ODOO_SERVICE="odoo_${ODOO_BRANCH}.service"
WKHTMLTOPDF_VERSION="wkhtmltox_0.12.6.1-3"
WKHTMLTOPDF_LINK="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/${WKHTMLTOPDF_VERSION}.bookworm_amd64.deb"
WKHTMLTOPDF_FILE="/tmp/wkhtmltox.deb"

title "Instalación de Odoo $ODOO_BRANCH desde fuente + virtualenv"

apt_install \
    python3-pip python3-venv python3-wheel python3-dev \
    build-essential libpq-dev libjpeg-dev zlib1g-dev \
    libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev \
    libssl-dev libffi-dev
apt_install \
    postgresql postgresql-client node-less npm wget curl
install_wkhtmltopdf
ok "Dependencias del sistema instaladas"

# Crear usuario del sistema
sudo useradd -m -d $ODOO_HOME -U -r -s /bin/bash $ODOO_USER -c "Odoo system user" >/dev/null 2>&1 \
        && ok "Usuario $ODOO_USER creado" \
        || error "Usuario ya existe"
echo "$ODOO_USER:$ODOO_PASS" | sudo chpasswd

# Crear directorios principales
sudo mkdir -p $CUSTOM_ADDONS
sudo mkdir -p $ODOO_BRANCH_HOME/{filestore,sessions,addons}
sudo chown -R $ODOO_USER:$ODOO_USER $ODOO_BRANCH_HOME
ok "Estructura de directorios creada"

# Crear usuario PostgreSQL
sudo -u postgres psql -q -c "
    CREATE ROLE ${ODOO_USER} LOGIN CREATEDB NOINHERIT PASSWORD '$ODOO_PASS';
" 2>/dev/null || sudo -u postgres psql -q -c "ALTER ROLE ${ODOO_USER} WITH PASSWORD '$ODOO_PASS';"
ok "Usuario ${ODOO_USER} en PostgreSQL configurado"

# Clonar Odoo desde GitHub
sudo test -d "${ODOO_BRANCH_HOME}/odoo-source" && sudo rm -fr "${ODOO_BRANCH_HOME}/odoo-source"
sudo -u "${ODOO_USER}" \
        git clone \
            --depth 1 \
            --branch "${ODOO_BRANCH}" \
            "https://github.com/odoo/odoo.git" \
            "${ODOO_BRANCH_HOME}/odoo-source" \
            --quiet
ok "Repositorio de Odoo en Github clonado en $ODOO_BRANCH"

# Crear entorno virtual
sudo -u $ODOO_USER \
        python3 -m venv $VENV_DIR
sudo -u "${ODOO_USER}" \
        ${VENV_DIR}/bin/pip install \
            --upgrade pip wheel setuptools \
            --quiet \
            --quiet \
            --no-input \
            --disable-pip-version-check \
            --no-color \
            --no-cache-dir
ok "Entorno virtual creado"

# Instalar requisitos de Odoo
sudo -u "${ODOO_USER}" \
        ${VENV_DIR}/bin/pip install \
            -r "${ODOO_BRANCH_HOME}/odoo-source/requirements.txt" \
            --quiet \
            --quiet \
            --no-input \
            --disable-pip-version-check \
            --no-color \
            --no-cache-dir
ok "Requerimientos de Python para Odoo instalados"

# Crear archivo de configuración
sudo -u $ODOO_USER bash -c "cat > $ODOO_CONFIG" <<EOF
[options]
admin_passwd = admin
db_user = $ODOO_USER
addons_path = $ODOO_BRANCH_HOME/odoo-source/addons,$ODOO_BRANCH_HOME/addons,$CUSTOM_ADDONS
data_dir = $ODOO_BRANCH_HOME/filestore
logfile = $ODOO_LOG
log_level = info
xmlrpc_port = 8069
EOF
sudo chmod 640 $ODOO_CONFIG
sudo chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG
ok "Archivo de configuración de Odoo generado en $ODOO_CONFIG"

# Script de inicio
ODOO_START="$ODOO_BRANCH_HOME/start.sh"
sudo -u $ODOO_USER bash -c "cat > ${ODOO_START}" <<EOF
#!/bin/bash
source $VENV_DIR/bin/activate
exec python3 $ODOO_BRANCH_HOME/odoo-source/odoo-bin -c $ODOO_BRANCH_HOME/odoo.conf "\$@"
EOF
sudo chmod +x $ODOO_BRANCH_HOME/start.sh
ok "Script de arranque generado en ${ODOO_START}"

# Servicio systemd (opcional pero recomendado)
ODOO_SERVICE_FILENAME="/etc/systemd/system/${ODOO_SERVICE}"
sudo bash -c "cat > ${ODOO_SERVICE_FILENAME}" <<EOF
[Unit]
Description=Odoo ${ODOO_BRANCH} (source) en ${DISTRO_NAME} ${DISTRO_VERSION}
After=network.target postgresql.service

[Service]
Type=simple
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_BRANCH_HOME/start.sh
Restart=on-failure
RestartSec=5
Environment=PATH=${VENV_DIR}/bin

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now ${ODOO_SERVICE} >/dev/null 2>&1
ok "Archivo de configuración del servicio generado en ${ODOO_SERVICE_FILENAME}"

title "¡ODOO $ODOO_BRANCH INSTALADO CORRECTAMENTE EN ${DISTRO_NAME} ${DISTRO_VERSION}!"
log "Usuario → $ODOO_USER | Contraseña → $ODOO_PASS"
log "Módulos personalizados → $CUSTOM_ADDONS"
log "Accede por navegador → http://$(hostname -I | awk '{print $1}'):8069"
log "Comandos útiles:\nsudo systemctl status ${ODOO_SERVICE}\nsudo systemctl restart ${ODOO_SERVICE}\nsudo journalctl -u ${ODOO_SERVICE} -f"
log "Para crear un módulo nuevo:\nsudo -u $ODOO_USER mkdir $CUSTOM_ADDONS/mi_modulo\nsudo -u $ODOO_USER touch $CUSTOM_ADDONS/mi_modulo/{__init__.py,__manifest__.py}"
title "¡Listo para desarrollar con Odoo!"
