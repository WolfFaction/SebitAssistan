# ============================================
# WindowsUpdate.psm1 - Gestión de actualizaciones
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
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        # Buscar solo actualizaciones no instaladas y no ocultas
        $searchResult = $updateSearcher.Search("IsInstalled=0 and IsHidden=0")

        $result.Pending = [int]$searchResult.Updates.Count
        $result.Found = [int]$searchResult.Updates.Count

        foreach ($update in $searchResult.Updates) {
            $result.Updates += "$($update.Title)"
        }

        # Verificar si se requiere reinicio
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

# Descarga e instala las actualizaciones pendientes.
# Emite el progreso por la salida estándar (se muestra en la ventana de actividad)
# y marcadores "@@...@@" que la GUI interpreta. NO reinicia el equipo.
function Install-WindowsUpdate {
    [CmdletBinding()]
    param(
        [switch]$ExcludeDrivers
    )

    $found = 0
    $installed = 0
    $failed = 0
    $reboot = $false
    $pendingTitles = @()

    try {
        Write-Log "Iniciando descarga e instalacion de Windows Update..." "INFO"
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0")

        $toInstall = @()
        foreach ($u in $searchResult.Updates) {
            if ($ExcludeDrivers -and $u.Type -eq 2) { continue }  # 2 = Driver
            $toInstall += $u
        }

        $found = $toInstall.Count
        Write-Output ("Actualizaciones pendientes a procesar: {0}" -f $found)

        if ($found -eq 0) {
            Write-Output "No hay actualizaciones pendientes."
            Write-Log "No hay actualizaciones pendientes." "INFO"
        }
        else {
            $n = $found
            $i = 0

            foreach ($u in $toInstall) {
                $i++
                $title = "$($u.Title)"
                Write-Output ("[{0}/{1}] {2}" -f $i, $n, $title)

                try {
                    if (-not $u.EulaAccepted) {
                        try { [void]$u.AcceptEula() } catch { }
                    }

                    $coll = New-Object -ComObject Microsoft.Update.UpdateColl
                    [void]$coll.Add($u)

                    # --- Descarga ---
                    if (-not $u.IsDownloaded) {
                        $downloader = $session.CreateUpdateDownloader()
                        $downloader.Updates = $coll
                        $dlResult = $downloader.Download()
                        if ($dlResult.ResultCode -ne 2) {
                            Write-Output ("  Descarga con resultado: {0}" -f $dlResult.ResultCode)
                        }
                    }

                    if (-not $u.IsDownloaded) {
                        $failed++
                        Write-Output "  No se pudo descargar; se omite."
                        Write-Log ("No se pudo descargar: {0}" -f $title) "WARNING"
                        continue
                    }

                    # --- Instalacion ---
                    $installer = $session.CreateUpdateInstaller()
                    $installer.Updates = $coll
                    $installer.IsForced = $false
                    $installer.IsSilent = $true
                    $installer.AllowSourcePrompts = $false
                    $installResult = $installer.Install()

                    $updateResultCode = 2
                    try { $updateResultCode = $installResult.GetUpdateResult(0).ResultCode }
                    catch { $updateResultCode = $installResult.ResultCode }

                    if ($updateResultCode -eq 2 -or $updateResultCode -eq 3) {
                        $installed++
                        Write-Output "  Instalada correctamente."
                        Write-Log ("Actualizacion instalada: {0}" -f $title) "INFO"
                    }
                    else {
                        $failed++
                        Write-Output ("  Fallo la instalacion (resultado {0})." -f $updateResultCode)
                        Write-Log ("Fallo la instalacion ({0}): {1}" -f $updateResultCode, $title) "WARNING"
                    }

                    if ($installResult.RebootRequired) { $reboot = $true }
                }
                catch {
                    $failed++
                    Write-Output ("  Error: {0}" -f $_)
                    Write-Log ("Error instalando '{0}': {1}" -f $title, $_) "ERROR"
                }
            }

            Write-Output ("Resultado -> Instaladas: {0}; Fallidas: {1}; Reinicio requerido: {2}" -f $installed, $failed, $reboot)
            Write-Log ("Windows Update -> Instaladas: {0}; Fallidas: {1}; Reinicio: {2}" -f $installed, $failed, $reboot) "INFO"
        }

        # Re-buscar pendientes tras la instalacion
        try {
            $searcher2 = $session.CreateUpdateSearcher()
            $after = $searcher2.Search("IsInstalled=0 and IsHidden=0")
            foreach ($u in $after.Updates) { $pendingTitles += "$($u.Title)" }
        }
        catch {
            Write-Log "No se pudo re-consultar el estado tras la instalacion: $_" "WARNING"
        }

        Write-Output ("Actualizaciones pendientes tras la instalacion: {0}" -f $pendingTitles.Count)
    }
    catch {
        Write-Output ("Error general: {0}" -f $_)
        Write-Log "Error en la instalacion de Windows Update: $_" "ERROR"
        $failed++
    }

    # Marcadores para la GUI
    Write-Output ("@@WU_INSTALLED@@" + $installed)
    Write-Output ("@@WU_FAILED@@" + $failed)
    Write-Output ("@@WU_REBOOT@@" + $reboot)
    foreach ($t in $pendingTitles) { Write-Output ("@@UPDATE@@" + $t) }
    Write-Output ("@@WU_PENDING@@" + $pendingTitles.Count)
}

Export-ModuleMember -Function Get-WindowsUpdateStatus, Install-WindowsUpdate
