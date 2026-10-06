# Security Policy

## Versiones soportadas

| Versión | Soportada |
|---------|-----------|
| 1.0.x   | Sí        |

## Reportar una vulnerabilidad

Si encuentras un problema de seguridad, **no lo publiques en un issue abierto**.
Envía un informe privado al mantenedor del repositorio:

- GitHub: [@WolfFaction](https://github.com/WolfFaction)

Incluye, si es posible:

- Descripción del problema.
- Pasos para reproducirlo.
- Impacto potencial.
- Versión de Windows y de PowerShell.
- Capturas o registros (sin datos sensibles).

Se intentará responder en un plazo razonable y se coordinará la divulgación.

## Alcance

SebitAssistan es una herramienta de diagnóstico y soporte que se ejecuta con
permisos administrativos en equipos Windows. Los puntos de interés de seguridad
son, entre otros:

- Ejecución de aplicaciones y comandos.
- Validación de rutas.
- Manejo de perfiles WiFi y posibles credenciales.
- Ejecución de `dism` y `pnputil` sobre controladores.
- Instalación de software mediante `winget`.

## Principios de seguridad del proyecto

- No se desactiva Windows Defender ni el Firewall.
- No se modifica de forma permanente la `ExecutionPolicy` de PowerShell
  (solo se aplica `-ExecutionPolicy Bypass` al proceso de la aplicación).
- No se realizan operaciones destructivas sobre discos.
- No se descarga software automáticamente: la instalación por `winget` requiere
  confirmación explícita del usuario.
- Los ejecutables portátiles solo se lanzan si están dentro de la carpeta del
  proyecto (validación de rutas).
- Solo se abren enlaces `http`/`https`.
- Los perfiles WiFi importados pueden contener claves en texto claro; la
  aplicación advierte al usuario y recomienda eliminarlos al terminar.
- Los drivers exportados/instalados se limitan a la carpeta `Drivers/` del
  proyecto.

## Buenas prácticas para el técnico

- Guardar la herramienta en un medio controlado (USB propio o cifrado).
- Eliminar los perfiles WiFi (`wifi-profiles/`) y los drivers sensibles cuando
  ya no se necesiten.
- Revisar la ventana de actividad para conocer exactamente qué comandos se
  ejecutan.
- No modificar `config/*.json` con rutas o comandos de fuentes no confiables.
