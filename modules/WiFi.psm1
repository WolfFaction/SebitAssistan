# ============================================
# Conexión mediante perfiles guardados
# ============================================
# Este módulo NO escanea ni se conecta a redes arbitrarias.
# Solo trabaja con los perfiles (.xml) ubicados en la carpeta wifi-profiles/.

function ConvertFrom-XmlEscaped {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    return ($Text -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&apos;', "'" -replace '&amp;', '&')
}

# Devuelve los perfiles WiFi (.xml) disponibles en wifi-profiles/
function Get-WifiProfileFiles {
    [CmdletBinding()]
    param()

    $dir = Join-Path $global:ProjectRoot "wifi-profiles"
    if (-not (Test-Path -LiteralPath $dir)) { return @() }

    $items = @()
    foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter "*.xml" -File -ErrorAction SilentlyContinue)) {
        $ssid = $file.BaseName
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
            if ($content -match "<name>(.*?)</name>") {
                $ssid = ConvertFrom-XmlEscaped $matches[1]
            }
        }
        catch {
            Write-Log "No se pudo leer el perfil '$($file.Name)': $_" "WARNING"
        }

        $items += [PSCustomObject]@{
            Name     = $ssid
            FileName = $file.Name
            FullPath = $file.FullName
        }
    }

    return @($items | Sort-Object Name)
}

# Conecta a un perfil guardado: lo registra en Windows y se conecta
function Connect-SavedWifiProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $result = @{ Success = $false; Message = "" }

    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            $result.Message = "No se encontro el perfil: $Path"
            Write-Log $result.Message "ERROR"
            return $result
        }

        $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ($content -notmatch "<name>(.*?)</name>") {
            $result.Message = "El archivo no parece un perfil WiFi valido: $Path"
            Write-Log $result.Message "ERROR"
            return $result
        }
        $ssid = ConvertFrom-XmlEscaped $matches[1]

        $addCommand = "netsh wlan add profile filename=`"$Path`" user=current"
        Write-Log ("Ejecutando: {0}" -f $addCommand) "DEBUG"
        $add = (netsh wlan add profile filename="$Path" user=current | Out-String).Trim()
        if ($add) { Write-Log $add "DEBUG" }

        $connectCommand = "netsh wlan connect name=`"$ssid`""
        Write-Log ("Ejecutando: {0}" -f $connectCommand) "DEBUG"
        $conn = (netsh wlan connect name="$ssid" | Out-String).Trim()
        if ($conn) { Write-Log $conn "DEBUG" }

        Start-Sleep -Seconds 2
        $result.Success = $true
        $result.Message = "Solicitud de conexion enviada para '$ssid'."
        Write-Log $result.Message "INFO"
    }
    catch {
        $result.Message = "Error conectando al perfil: $_"
        Write-Log $result.Message "ERROR"
    }

    return $result
}

# Exporta los perfiles WiFi existentes en Windows hacia wifi-profiles/
function Import-SystemWifiProfiles {
    [CmdletBinding()]
    param()

    $result = @{ Success = $false; Message = ""; Count = 0 }

    try {
        $dir = Join-Path $global:ProjectRoot "wifi-profiles"
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $command = "netsh wlan export profile folder=`"$dir`" key=clear"
        Write-Log ("Ejecutando: {0}" -f $command) "DEBUG"
        $out = (netsh wlan export profile folder="$dir" key=clear | Out-String).Trim()
        if ($out) { Write-Log $out "DEBUG" }

        $result.Count = @(Get-ChildItem -LiteralPath $dir -Filter "*.xml" -File -ErrorAction SilentlyContinue).Count
        $result.Success = $true
        $result.Message = "Perfiles exportados a wifi-profiles: $($result.Count)."
        Write-Log $result.Message "INFO"
    }
    catch {
        $result.Message = "Error exportando perfiles: $_"
        Write-Log $result.Message "ERROR"
    }

    return $result
}

Export-ModuleMember -Function Get-WifiProfileFiles, Connect-SavedWifiProfile, Import-SystemWifiProfiles
