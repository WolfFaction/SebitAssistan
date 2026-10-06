# Changelog

Todas las modificaciones relevantes de este proyecto se documentan en este archivo.

## [2.0.0] - 2026-10-07

Versión publicada inicialmente. Cambios y funcionalidades incluidas:

- Interfaz Windows Forms con **tema oscuro** y **ventana de actividad en vivo** (incluye detalles en nivel DEBUG).
- **Checklist manual** de verificación, sin tareas redundantes con las acciones automáticas.
- **Inventario del sistema**: fabricante, modelo, número de serie, Windows, CPU y RAM.
- **Windows Update**:
  - Búsqueda de actualizaciones en segundo plano.
  - Barra de progreso en movimiento y tiempo transcurrido.
  - Listado completo de actualizaciones pendientes (botón "Ver actualizaciones").
  - Sección de actualizaciones pendientes en el reporte.
- **Diagnósticos** no destructivos: red, almacenamiento, memoria y hardware.
- **Herramienta del fabricante** (Dell, HP, Lenovo, ASUS, MSI) con recomendación e instalación opcional mediante `winget`.
- **Drivers**: exportación con `dism` e instalación con `pnputil` desde la carpeta `Drivers/`.
- **WiFi**: conexión mediante perfiles guardados en `wifi-profiles/` (sin escaneo de redes nuevas).
- **Comandos del sistema** configurables (`config/commands.json`).
- **Aplicaciones portátiles** (`apps/`) y **enlaces personalizados** (`config/links.json`).
- **Reportes HTML** y **logs** centralizados.
- Ejecución de tareas largas en segundo plano para no bloquear la interfaz.
- Licencia MIT.
