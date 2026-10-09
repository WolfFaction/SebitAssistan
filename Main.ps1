# ============================================
# SebitAssistan - Main.ps1
# ============================================

#Requires -Version 5.1

# Cargar Windows Forms de forma temprana (se usa incluso antes de la GUI)
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
}
catch {
    Write-Host "ERROR: No fue posible cargar System.Windows.Forms."
    exit 1
}

# Obtener la ruta del proyecto (directorio del script)
$global:ProjectRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($global:ProjectRoot)) {
    $global:ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
Set-Location -LiteralPath $global:ProjectRoot

# Importar modulos
$moduleNames = @(
    "Core",
    "SystemInfo",
    "WindowsUpdate",
    "Manufacturer",
    "Diagnostics",
    "Applications",
    "Checklist",
    "Reports",
    "WiFi",
    "Drivers",
    "Activation",
    "GUI"
)

foreach ($name in $moduleNames) {
    $modulePath = Join-Path $global:ProjectRoot ("modules\{0}.psm1" -f $name)
    if (-not (Test-Path -LiteralPath $modulePath)) {
        [System.Windows.Forms.MessageBox]::Show(
            "No se encontro el modulo requerido:`n$modulePath`n`nLa aplicacion no puede iniciar.",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit 1
    }

    try {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error al importar el modulo '$name':`n$_",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit 1
    }
}

# Inicializar aplicacion
function Start-SebitAssistan {
    Write-Log "Iniciando SebitAssistan..." "INFO"

    # Verificar privilegios administrativos
    if (-not (Test-Administrator)) {
        Write-Log "ERROR: La aplicacion requiere permisos administrativos." "ERROR"
        [System.Windows.Forms.MessageBox]::Show(
            "La aplicacion requiere permisos administrativos.`nPor favor, ejecute como administrador.",
            "Error de permisos",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        exit 1
    }

    Write-Log "Privilegios administrativos confirmados." "INFO"

    # Cargar configuración
    $configPath = Join-Path $global:ProjectRoot "config\config.json"
    if (Test-Path -LiteralPath $configPath) {
        try {
            $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $global:Config = $config
            Write-Log "Configuracion cargada (v$($config.version))." "INFO"
        }
        catch {
            Write-Log "No se pudo cargar config.json: $_" "WARNING"
        }
    }
    else {
        Write-Log "No se encontro config.json." "WARNING"
    }

    # Crear carpetas necesarias
    $directories = @("logs", "reports", "apps", "wifi-profiles", "Drivers")
    foreach ($dir in $directories) {
        $path = Join-Path $global:ProjectRoot $dir
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    # Inicializar checklist manual y resultados automaticos
    $global:ManualChecklist = Initialize-Checklist
    $global:AutoResults = $null   # se inicializa en New-MainForm

    # Crear y mostrar interfaz
    $form = New-MainForm
    [void]$form.ShowDialog()

    Write-Log "Aplicacion finalizada." "INFO"
}

# Iniciar
try {
    Start-SebitAssistan
}
catch {
    Write-Log "Error fatal: $_" "ERROR"
    [System.Windows.Forms.MessageBox]::Show(
        "Error fatal: $_",
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
