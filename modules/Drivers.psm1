# ============================================
#  Exportación e instalación de controladores
# ============================================
# Exporta los drivers del equipo a la carpeta Drivers/<nombre>/ con DISM y
# los instala desde una subcarpeta de Drivers/ con pnputil.

function Get-DriverFolders {
    [CmdletBinding()]
    param()

    $dir = Join-Path $global:ProjectRoot "Drivers"
    if (-not (Test-Path -LiteralPath $dir)) { return @() }

    $items = @()
    foreach ($d in (Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue)) {
        $items += [PSCustomObject]@{
            Name     = $d.Name
            FullPath = $d.FullName
        }
    }

    return @($items | Sort-Object Name)
}

function Get-SafeDriverFolderName {
    [CmdletBinding()]
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return "" }
    return (($Name -replace '[\\/:*?"<>|]', '_').Trim())
}

# Exporta todos los drivers del equipo a Drivers/<FolderName>/
function Export-Drivers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderName
    )

    $safe = Get-SafeDriverFolderName -Name $FolderName
    if (-not $safe) {
        Write-Output "Nombre de carpeta invalido."
        Write-Output "@@DRIVER_EXIT@@1"
        return
    }

    $base = Join-Path $global:ProjectRoot "Drivers"
    if (-not (Test-Path -LiteralPath $base)) { New-Item -ItemType Directory -Path $base -Force | Out-Null }

    $dest = Join-Path $base $safe
    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }

    $log = Join-Path $dest "log_exportacion.txt"
    Write-Log ("Ejecutando: dism /online /export-driver /destination=`"$dest`"") "DEBUG"

    Write-Output ("Exportando drivers a: $dest")
    $out = & dism /online /export-driver "/destination:$dest" 2>&1 | Out-String
    $out | Out-File -LiteralPath $log -Encoding UTF8

    foreach ($line in ($out -split "`r?`n")) {
        if ($line.Trim()) { Write-Output $line.TrimEnd() }
    }

    Write-Output ("Log guardado en: $log")
    Write-Output ("@@DRIVER_EXIT@@" + $LASTEXITCODE)
}

# Instala los drivers (.inf) desde una subcarpeta de Drivers/
function Install-DriversFromFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Output "Carpeta no encontrada: $Path"
        Write-Output "@@DRIVER_EXIT@@1"
        return
    }

    $log = Join-Path $Path "log_instalacion.txt"
    Write-Log ("Ejecutando: pnputil /add-driver `"$Path\*.inf`" /subdirs /install") "DEBUG"

    Write-Output ("Instalando drivers desde: $Path")
    $out = & pnputil /add-driver "$Path\*.inf" /subdirs /install 2>&1 | Out-String
    $out | Out-File -LiteralPath $log -Encoding UTF8

    foreach ($line in ($out -split "`r?`n")) {
        if ($line.Trim()) { Write-Output $line.TrimEnd() }
    }

    Write-Output ("Log guardado en: $log")
    Write-Output ("@@DRIVER_EXIT@@" + $LASTEXITCODE)
}

Export-ModuleMember -Function Get-DriverFolders, Get-SafeDriverFolderName, Export-Drivers, Install-DriversFromFolder
