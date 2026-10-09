# SebitAssistan

Herramienta **portable** de diagnóstico y soporte para equipos Windows, pensada para técnicos.

Se ejecuta con permisos de administrador, automatiza las tareas habituales de
diagnóstico y mantenimiento, y permite al técnico completar un checklist manual.

**Versión:** 2.1.0 · **Licencia:** MIT

## Características

- **Información del equipo**: fabricante, modelo, número de serie, Windows, CPU y RAM.
- **Apagar / Reiniciar** el equipo desde la barra superior (con confirmación).
- **Checklist manual** de verificación (pantalla, teclado, puertos, etc.).
- **Diagnósticos**: red, almacenamiento, memoria y hardware (no destructivos).
- **Windows Update**: abre el panel de Configuración y permite limpiar/reiniciar sus componentes.
- **Activar Windows**: activa Windows con la clave digital OEM del equipo (`slmgr /ipk` + `/ato`).
- **Aplicaciones portátiles**: ejecuta las herramientas de la carpeta `apps/` (`.exe`, `.bat` o `.cmd`).
- **Drivers**: exporta los controladores del equipo e instálalos desde la carpeta `Drivers/`.
- **WiFi**: conexión mediante perfiles guardados en `wifi-profiles/`.
- **Comandos del sistema**: elija de la lista desplegable o **escriba cualquier comando** (como el cuadro Ejecutar de Windows).
- **Enlaces personalizados** y **reportes HTML**.
- **Ventana de actividad** en vivo y tema oscuro.

## Requisitos

- Windows 10 o Windows 11
- PowerShell 5.1 o superior (incluido en Windows)
- Permisos de administrador

## Uso

1. Descomprimir o copiar la carpeta `SebitAssistan` donde se desee (USB, `C:\Tools\`, etc.).
2. Hacer doble clic en **`Launcher.bat`**.
3. Aceptar la elevación de permisos (UAC).

La aplicación funciona desde cualquier ruta, incluso con espacios.

## Carpetas portables

Las siguientes carpetas se distribuyen vacías; cada usuario coloca en ellas su propio contenido:

- `apps/` — herramientas portátiles de diagnóstico (`.exe`, `.bat`, `.cmd`).
- `Drivers/` — controladores exportados o para instalar.
- `wifi-profiles/` — perfiles WiFi (`.xml`).

## Reportes y logs

- El reporte pide el **alias del técnico** y se guarda en `reports/` como `Report-<alias>-YYYY-MM-DD-HH-mm-ss.html`.
- La actividad se registra en `logs/`.

## Seguridad

El proyecto no desactiva Defender ni el Firewall, no modifica la política de
ejecución de PowerShell de forma permanente y valida las rutas antes de ejecutar
programas. Consulte [SECURITY.md](SECURITY.md) para más detalles.

## Licencia

Distribuido bajo la **Licencia MIT**. Consulte [LICENSE](LICENSE).
