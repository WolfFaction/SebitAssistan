# Changelog

Todas las modificaciones relevantes de este proyecto se documentan en este archivo.

## [2.0.8] - 2026-10-08

- **Causa raíz confirmada del fallo de Windows Update**: el código antiguo asignaba `$installer.IsSilent`, propiedad que el objeto COM no expone en este equipo, lanzando `0x80131501` en cada actualización. Ya no se usa.
- Se copió el archivo `PSWindowsUpdate.psm1` (declarado como `NestedModules`) que faltaba en `lib/PSWindowsUpdate/`.
- El import de PSWindowsUpdate ahora se **verifica** (se comprueba que exista el cmdlet) y, si falla, se registra el motivo y se pasa al respaldo COM.
- El respaldo COM ya no asigna `IsForced`/`AllowSourcePrompts` sin protección.
- Se añade un **banner de versión** en la ventana de actividad para confirmar qué versión del motor se ejecuta.

## [2.0.7] - 2026-10-08

- **Instalación de Windows Update mediante PSWindowsUpdate**:
  - Se incluye el módulo **PSWindowsUpdate** (Michal Gajda, licencia MIT) en `lib/PSWindowsUpdate/`.
  - La instalación usa `Install-WindowsUpdate -AcceptAll -IgnoreReboot`, que es la vía que funcionó en pruebas (frente a la API COM directa, que fallaba con `0x80131501`).
  - Se mantiene la API COM como respaldo si PSWindowsUpdate no está disponible.
  - Se conserva el registro de progreso y el resumen (instaladas/fallidas/pendientes/reinicio).

## [2.0.6] - 2026-10-07

- **Corrección de la instalación de Windows Update** (fallaban todas las actualizaciones con `0x80131501`):
  - La instalación arma **una sola colección**, **descarga en lote** e **instala en lote** (patrón documentado).
  - Si la API COM falla, se usa el **orquestador de Windows Update (`UsoClient`)**, la misma vía que Configuración, y se sondea el estado hasta 8 minutos.
  - Si todo falla, ofrece **abrir Windows Update de Windows** para instalar manualmente.
  - Se registra el **ResultCode y el HResult** de cada actualización en la ventana de actividad.
  - Se añade una línea de diagnóstico (usuario, elevación, PID, versión de PowerShell).
- **Interfaz**: se elimina "Ver updates" y "Buscar updates". Ahora **"Instalar updates" hace todo** (busca, descarga e instala).
- **Comandos**: se elimina la entrada "Configuracion de Windows".

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
