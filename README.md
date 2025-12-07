# Odoo en Debian/Ubuntu → Instalación fácil, rápida y sin sufrimiento

Script todo-en-uno para instalar **Odoo Community** (versión 17, 18 o la que elijas) en Debian 12/11 o Ubuntu 24.04/22.04 con un solo comando.  
Probado mil veces, actualizado constantemente y hecho con mucho amor para que nadie más tenga que pelearse con dependencias a las 4 a.m.

### Lo que hace este script por vos
- Instala y configura PostgreSQL (con usuario odoo sin password desde localhost)
- Crea el usuario del sistema `odoo`
- Descarga la versión oficial de Odoo Community desde GitHub
- Instala todas las dependencias del sistema y de Python
- Configura wkhtmltopdf correcto (el que sí anda con encabezados/pies de página)
- Crea el servicio systemd y lo deja corriendo
- Te deja todo listo para entrar por http://tu-ip:8069

### Cómo usarlo (es ridículamente fácil)

```bash
wget https://raw.githubusercontent.com/jldalla/install_odoo/main/install_odoo.sh
chmod +x install_odoo.sh
./install_odoo.sh
