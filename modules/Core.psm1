# ============================================
#  Funciones principales
# ============================================

# Resolver la raiz del proyecto a partir de la ubicacion del modulo (carpeta modules/)
if (-not $global:ProjectRoot) {
    $global:ProjectRoot = Split-Path -Parent $PSScriptRoot
}

# Función para escribir logs (nunca debe lanzar excepciones)
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"

    # Archivo de log
    try {
        $logDir = Join-Path $global:ProjectRoot "logs"
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $logFile = Join-Path $logDir ("session-{0}.log" -f (Get-Date -Format "yyyy-MM-dd"))
        Add-Content -LiteralPath $logFile -Value $logEntry -Encoding UTF8
    }
    catch {
        # El registro a disco no debe detener la aplicacion
    }

    # Ventana de actividad en vivo, si la GUI la registro
    if ($global:ActivitySink) {
        try { & $global:ActivitySink $logEntry } catch { }
    }
}

# Función para verificar privilegios administrativos
function Test-Administrator {
    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Log "No fue posible verificar privilegios administrativos: $_" "ERROR"
        return $false
    }
}

# Normaliza una ruta y garantiza que termine en separador de directorio
function Get-NormalizedDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $full += [System.IO.Path]::DirectorySeparatorChar
    }
    return $full
}

# Función centralizada para ejecutar aplicaciones externas de forma segura
function Invoke-DiagnosticApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$Arguments = ""
    )

    try {
        # Resolver la ruta (relativa a la raiz del proyecto o absoluta)
        $candidate = $Path
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path $global:ProjectRoot $candidate
        }
        $full = [System.IO.Path]::GetFullPath($candidate)

        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Write-Log "Aplicacion no encontrada: $full" "ERROR"
            return $false
        }

        # Validar que la ruta resuelta este dentro del proyecto
        $root = Get-NormalizedDirectory -Path $global:ProjectRoot
        if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Log "Ruta no permitida (fuera del proyecto): $full" "ERROR"
            return $false
        }

        Write-Log "Ejecutando aplicacion: $full" "INFO"
        $workDir = Split-Path -Parent $full
        if ([string]::IsNullOrWhiteSpace($Arguments)) {
            Start-Process -FilePath $full -WorkingDirectory $workDir
        }
        else {
            Start-Process -FilePath $full -WorkingDirectory $workDir -ArgumentList $Arguments
        }
        return $true
    }
    catch {
        Write-Log "Error ejecutando aplicacion: $_" "ERROR"
        return $false
    }
}

# Leer los enlaces personalizados definidos en config/links.json
function Get-CustomLinks {
    $configPath = Join-Path $global:ProjectRoot "config\links.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        Write-Log "Archivo de enlaces no encontrado: $configPath" "WARNING"
        return @()
    }

    try {
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $config.links) {
            return @($config.links)
        }
        return @()
    }
    catch {
        Write-Log "Error leyendo enlaces: $_" "ERROR"
        return @()
    }
}

# Abrir un enlace en el navegador predeterminado
function Open-CustomLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        if ($Url -notmatch '^(https?)://') {
            Write-Log "Enlace invalido (solo se permiten http/https): $Url" "ERROR"
            return $false
        }
        Start-Process $Url
        Write-Log "Enlace abierto: $Url" "INFO"
        return $true
    }
    catch {
        Write-Log "Error abriendo enlace: $_" "ERROR"
        return $false
    }
}

# Leer los comandos del sistema definidos en config/commands.json
function Get-SystemCommands {
    $configPath = Join-Path $global:ProjectRoot "config\commands.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        Write-Log "Archivo de comandos no encontrado: $configPath" "WARNING"
        return @()
    }

    try {
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $config.commands) {
            return @($config.commands)
        }
        return @()
    }
    catch {
        Write-Log "Error leyendo comandos: $_" "ERROR"
        return @()
    }
}

Export-ModuleMember -Function Write-Log, Test-Administrator, Invoke-DiagnosticApplication, Get-CustomLinks, Open-CustomLink, Get-SystemCommands
