# SebitAssistan

Herramienta **portable** de diagnóstico y soporte para equipos Windows, pensada para técnicos.

Se ejecuta con permisos de administrador, automatiza las tareas habituales de
diagnóstico y mantenimiento, y permite al técnico completar un checklist manual.

**Versión:** 2.0.7 · **Licencia:** MIT

## Características

- **Información del equipo**: fabricante, modelo, número de serie, Windows, CPU y RAM.
- **Checklist manual** de verificación (pantalla, teclado, cámara, puertos, etc.).
- **Windows Update**: busca e instala las actualizaciones pendientes (no reinicia automáticamente).
- **Diagnósticos**: red, almacenamiento, memoria y hardware (no destructivos).
- **Aplicaciones portátiles**: ejecuta las herramientas de la carpeta `apps/`.
- **Drivers**: exporta los controladores del equipo e instálalos desde la carpeta `Drivers/`.
- **WiFi**: conexión mediante perfiles guardados en `wifi-profiles/`.
- **Comandos del sistema**: acceso rápido a herramientas como visor de eventos, servicios o administración de discos.
- **Cámara y micrófono**: detección automática y validación manual.
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

- `apps/` — herramientas portátiles de diagnóstico.
- `Drivers/` — controladores exportados o para instalar.
- `wifi-profiles/` — perfiles WiFi (`.xml`).

## Reportes y logs

- Los reportes se generan en `reports/` como `Report-YYYY-MM-DD-HH-mm-ss.html`.
- La actividad se registra en `logs/`.

## Seguridad

El proyecto no desactiva Defender ni el Firewall, no modifica la política de
ejecución de PowerShell de forma permanente y valida las rutas antes de ejecutar
programas. Consulte [SECURITY.md](SECURITY.md) para más detalles.

## Licencia

Distribuido bajo la **Licencia MIT**. Consulte [LICENSE](LICENSE).

## Créditos

- **PSWindowsUpdate** de Michal Gajda (licencia MIT), incluido en `lib/PSWindowsUpdate/` para la instalación de actualizaciones de Windows. Ver `lib/PSWindowsUpdate/LICENSE`.
