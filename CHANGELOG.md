# Changelog

Todas las modificaciones relevantes de este proyecto se documentan en este archivo.

## [2.0.5] - 2026-10-07

Interfaz Windows Forms con **tema oscuro** y **ventana de actividad en vivo** (incluye detalles en nivel DEBUG).

**Sistema y diagnóstico**
- Inventario del sistema: fabricante, modelo, número de serie, Windows, CPU y RAM.
- Checklist manual de verificación, sin redundancias con las acciones automáticas.
- Diagnósticos no destructivos: red, almacenamiento, memoria y hardware.
- Cámara y micrófono: detección automática y validación manual.
- Ejecución de tareas largas en segundo plano (la interfaz no se bloquea).

**Windows Update**
- Búsqueda de actualizaciones con barra de progreso en movimiento y tiempo transcurrido.
- Listado completo de actualizaciones pendientes (botón "Ver updates").
- **Descarga e instalación** de las actualizaciones pendientes (botón "Instalar updates").
- El botón "Buscar updates" ofrece instalar al terminar la búsqueda.
- Progreso por actualización en la ventana de actividad (`[i/N] título`).
- No reinicia el equipo: avisa si se requiere reinicio y vuelve a consultar el estado.

**Herramientas**
- Herramienta del fabricante (Dell, HP, Lenovo, ASUS, MSI) con recomendación e instalación opcional mediante `winget`.
- Drivers: exportación con `dism` e instalación con `pnputil` desde la carpeta `Drivers/`.
- WiFi: conexión mediante perfiles guardados en `wifi-profiles/`.
- Comandos del sistema configurables (`config/commands.json`).
- Aplicaciones portátiles (`apps/`) y enlaces personalizados (`config/links.json`).
- Reportes HTML y logs centralizados.

**Otros**
- Licencia MIT.
- Repositorio preparado (`.gitignore`, `.gitattributes`, `SECURITY.md`, `CHANGELOG.md`).
