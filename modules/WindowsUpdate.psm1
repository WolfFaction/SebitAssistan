# ============================================
# WindowsUpdate.psm1 - Consulta y limpieza de Windows Update
# ============================================

function Get-WindowsUpdateStatus {
    [CmdletBinding()]
    param()

    $result = @{
        Found          = 0
        Installed      = 0
        Pending        = 0
        RebootRequired = $false
        Updates        = @()
        Error          = $null
    }

    try {
        Write-Log "Buscando actualizaciones de Windows..." "INFO"

        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSession.ClientApplicationID = "SebitAssistan"
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search("IsInstalled=0 and IsHidden=0")

        $result.Pending = [int]$searchResult.Updates.Count
        $result.Found = [int]$searchResult.Updates.Count

        foreach ($update in $searchResult.Updates) {
            $result.Updates += "$($update.Title)"
        }

        $systemInfo = New-Object -ComObject Microsoft.Update.SystemInfo
        $result.RebootRequired = [bool]$systemInfo.RebootRequired

        Write-Log "Actualizaciones encontradas: $($result.Found) (reinicio requerido: $($result.RebootRequired))" "INFO"
    }
    catch {
        $result.Error = "$_"
        Write-Log "Error consultando Windows Update: $_" "ERROR"
    }

    return $result
}

# Limpia/reinicia los componentes de Windows Update:
# detiene servicios, renombra SoftwareDistribution y catroot2, y los reinicia.
function Reset-WindowsUpdateComponents {
    [CmdletBinding()]
    param()

    $services = @("wuauserv", "bits", "cryptsvc", "msiserver")
    $softwareDistribution = Join-Path $env:windir "SoftwareDistribution"
    $catroot2 = Join-Path $env:windir "System32\catroot2"

    Write-Log "Limpiando componentes de Windows Update..." "INFO"
    Write-Output "Limpiando componentes de Windows Update..."

    # Detener servicios
    foreach ($name in $services) {
        try {
            $svc = Get-Service -Name $name -ErrorAction Stop
            if ($svc.Status -ne "Stopped") {
                Write-Output ("  Deteniendo servicio {0}..." -f $name)
                Stop-Service -Name $name -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Output ("  Servicio {0}: no se pudo detener ({1})" -f $name, $_.Exception.Message)
        }
    }

    # Renombrar carpetas de cache
    $pairs = @(
        @{ Src = $softwareDistribution; Dst = "$softwareDistribution.old" },
        @{ Src = $catroot2;            Dst = "$catroot2.old" }
    )
    foreach ($pair in $pairs) {
        if (Test-Path -LiteralPath $pair.Src) {
            try {
                if (Test-Path -LiteralPath $pair.Dst) {
                    Remove-Item -LiteralPath $pair.Dst -Recurse -Force -ErrorAction SilentlyContinue
                }
                Write-Output ("  Renombrando {0} -> {1}" -f $pair.Src, $pair.Dst)
                Rename-Item -LiteralPath $pair.Src -NewName (Split-Path -Leaf $pair.Dst) -Force -ErrorAction Stop
            }
            catch {
                Write-Output ("  No se pudo renombrar {0}: {1}" -f $pair.Src, $_.Exception.Message)
            }
        }
    }

    # Reiniciar servicios
    foreach ($name in $services) {
        try {
            $svc = Get-Service -Name $name -ErrorAction Stop
            Write-Output ("  Iniciando servicio {0}..." -f $name)
            Start-Service -Name $name -ErrorAction Stop
        }
        catch {
            Write-Output ("  Servicio {0}: no se pudo iniciar ({1})" -f $name, $_.Exception.Message)
        }
    }

    Write-Output "Limpieza de Windows Update finalizada. Se recomienda reiniciar el equipo."
    Write-Log "Componentes de Windows Update reiniciados." "INFO"
    Write-Output ("@@WU_RESET@@OK")
}

Export-ModuleMember -Function Get-WindowsUpdateStatus, Reset-WindowsUpdateComponents
