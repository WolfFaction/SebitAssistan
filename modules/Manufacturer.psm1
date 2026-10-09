# ============================================
# Aplicaciones del fabricante
# ============================================

function Get-ManufacturerConfig {
    $configPath = Join-Path $global:ProjectRoot "config\manufacturers.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        Write-Log "Archivo de fabricantes no encontrado: $configPath" "ERROR"
        return $null
    }

    try {
        return (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        Write-Log "Error leyendo fabricantes: $_" "ERROR"
        return $null
    }
}

function New-ManufacturerEntry {
    param($Key, $Entry)

    $name = $Key
    if ($Entry.name) { $name = [string]$Entry.name }

    return [PSCustomObject]@{
        Key         = $Key
        Name        = $name
        Application = "$($Entry.application)"
        WingetId    = if ($Entry.wingetId) { "$($Entry.wingetId)" } else { $null }
        DownloadUrl = if ($Entry.downloadUrl) { "$($Entry.downloadUrl)" } else { $null }
    }
}

function Get-ManufacturerEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Manufacturer
    )

    if ([string]::IsNullOrWhiteSpace($Manufacturer)) { return $null }

    $config = Get-ManufacturerConfig
    if (-not $config) { return $null }

    $detected = $Manufacturer.Trim()

    foreach ($prop in $config.PSObject.Properties) {
        $entry = $prop.Value

        # Construir lista de candidatos (clave, nombre y alias), los mas largos primero
        $candidates = New-Object System.Collections.ArrayList
        [void]$candidates.Add($prop.Name)
        if ($entry.name) { [void]$candidates.Add([string]$entry.name) }
        if ($entry.aliases) { foreach ($a in $entry.aliases) { [void]$candidates.Add([string]$a) } }

        $ordered = $candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object { $_.Length } -Descending

        foreach ($c in $ordered) {
            if ($detected -ieq $c.Trim()) {
                return (New-ManufacturerEntry -Key $prop.Name -Entry $entry)
            }
        }
    }

    # Segundo paso: coincidencia parcial
    foreach ($prop in $config.PSObject.Properties) {
        $entry = $prop.Value
        $candidates = New-Object System.Collections.ArrayList
        [void]$candidates.Add($prop.Name)
        if ($entry.name) { [void]$candidates.Add([string]$entry.name) }
        if ($entry.aliases) { foreach ($a in $entry.aliases) { [void]$candidates.Add([string]$a) } }

        $ordered = $candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object { $_.Length } -Descending
        foreach ($c in $ordered) {
            if ($detected -like ("*" + $c.Trim() + "*")) {
                return (New-ManufacturerEntry -Key $prop.Name -Entry $entry)
            }
        }
    }

    return $null
}

function Test-WingetAvailable {
    [CmdletBinding()]
    param()

    try {
        $null = Get-Command -Name "winget" -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Devuelve el plan de instalacion: si se puede automatizar con winget o hay que
# descargar manualmente desde el fabricante.
function Get-ManufacturerInstallPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Manufacturer
    )

    $entry = Get-ManufacturerEntry -Manufacturer $Manufacturer

    if (-not $entry) {
        return [PSCustomObject]@{
            Supported   = $false
            Manufacturer = $Manufacturer
            Application = $null
            WingetId    = $null
            DownloadUrl = $null
            Message     = "Fabricante no reconocido en config/manufacturers.json. Busque la herramienta oficial en la web del fabricante."
        }
    }

    if ($entry.WingetId -and (Test-WingetAvailable)) {
        return [PSCustomObject]@{
            Supported   = $true
            Manufacturer = $entry.Name
            Application = $entry.Application
            WingetId    = $entry.WingetId
            DownloadUrl = $entry.DownloadUrl
            Message     = "Se instalara '$($entry.Application)' de $($entry.Name) usando winget ($($entry.WingetId))."
        }
    }

    if ($entry.WingetId -and -not (Test-WingetAvailable)) {
        $reason = "winget no esta disponible en este equipo."
    }
    elseif (-not $entry.WingetId) {
        $reason = "no hay paquete de winget para $($entry.Name)."
    }
    else {
        $reason = "no fue posible automatizar la instalacion."
    }

    $fallback = "Descargue '$($entry.Application)' desde: $($entry.DownloadUrl)"

    return [PSCustomObject]@{
        Supported    = $false
        Manufacturer = $entry.Name
        Application  = $entry.Application
        WingetId     = $entry.WingetId
        DownloadUrl  = $entry.DownloadUrl
        Message      = "No se puede automatizar: $reason`n`n$fallback"
    }
}

Export-ModuleMember -Function Get-ManufacturerEntry, Test-WingetAvailable, Get-ManufacturerInstallPlan
