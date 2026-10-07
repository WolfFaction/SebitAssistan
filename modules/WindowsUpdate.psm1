# ============================================
# WindowsUpdate.psm1 - Gestión de actualizaciones
# ============================================
# Estrategia de instalacion:
#   1. PSWindowsUpdate (incluido en lib/PSWindowsUpdate o instalado en el sistema).
#      Es la via que funciona (misma que el modulo de PowerShellGallery).
#   2. Respaldo: API COM de Windows Update (descarga e instalacion en lote).
# NO reinicia el equipo.

function Format-WuCode {
    param($Code)
    try { return ("0x{0:X8}" -f ([int64]$Code -band 0xFFFFFFFF)) } catch { return "$Code" }
}

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

# Busca el modulo PSWindowsUpdate incluido en el proyecto o instalado en el sistema
function Get-PSWindowsUpdateModulePath {
    $local = Join-Path $global:ProjectRoot "lib\PSWindowsUpdate\PSWindowsUpdate.psd1"
    if (Test-Path -LiteralPath $local) { return $local }

    try {
        $mod = Get-Module -ListAvailable -Name "PSWindowsUpdate" | Select-Object -First 1
        if ($mod) { return $mod.Path }
    }
    catch { }

    return $null
}

# Respaldo: API COM de Windows Update (lote)
function Invoke-WindowsUpdateCom {
    param()

    $installed = 0
    $failed = 0
    $reboot = $false
    $total = 0

    try {
        Write-Output "Usando la API COM de Windows Update (respaldo)..."
        $session = New-Object -ComObject Microsoft.Update.Session
        $session.ClientApplicationID = "SebitAssistan"
        $searcher = $session.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0")

        $collection = New-Object -ComObject Microsoft.Update.UpdateColl
        $titles = @()
        foreach ($u in $searchResult.Updates) {
            if ($u.IsInstalled) { continue }
            try { if (-not $u.EulaAccepted) { [void]$u.AcceptEula() } } catch { }
            [void]$collection.Add($u)
            $titles += "$($u.Title)"
        }
        $total = $collection.Count

        if ($total -gt 0) {
            $downloader = $session.CreateUpdateDownloader()
            $downloader.Updates = $collection
            [void]$downloader.Download()

            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $collection
            $installer.IsForced = $false
            $installer.AllowSourcePrompts = $false
            $installResult = $installer.Install()

            for ($i = 0; $i -lt $collection.Count; $i++) {
                $code = 0; $hres = 0
                try {
                    $ur = $installResult.GetUpdateResult($i)
                    $code = [int]$ur.ResultCode
                    $hres = $ur.HResult
                }
                catch { continue }

                if ($code -eq 2 -or $code -eq 3) { $installed++ }
                else {
                    $failed++
                    Write-Output ("  FALLO [{0}] HResult={1}" -f $titles[$i], (Format-WuCode $hres))
                }
            }
            if ($installResult.RebootRequired) { $reboot = $true }
        }
    }
    catch {
        Write-Output ("Error en la API COM: {0}" -f $_)
        $failed++
    }

    return [PSCustomObject]@{
        Installed = $installed
        Failed    = $failed
        Reboot    = $reboot
        Total     = $total
    }
}

# Descarga e instala las actualizaciones pendientes. Emite progreso y marcadores.
function Invoke-WindowsUpdateInstall {
    [CmdletBinding()]
    param()

    $installed = 0
    $failed = 0
    $reboot = $false
    $total = 0
    $pendingTitles = @()

    try {
        Write-Log "Iniciando instalacion de Windows Update..." "INFO"
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            Write-Output ("[Diagnostico] Usuario={0}; Elevado={1}; PID={2}; PS={3}" -f $env:USERNAME, $isAdmin, $PID, $PSVersionTable.PSVersion)
        }
        catch { }

        $modulePath = Get-PSWindowsUpdateModulePath

        if ($modulePath) {
            Write-Output ("Usando PSWindowsUpdate: {0}" -f $modulePath)
            Write-Log ("Usando PSWindowsUpdate: {0}" -f $modulePath) "INFO"
            Import-Module $modulePath -Force

            # Buscar
            Write-Output "Buscando actualizaciones..."
            $list = @(PSWindowsUpdate\Get-WindowsUpdate -ErrorAction Stop)
            $total = $list.Count
            Write-Output ("Actualizaciones pendientes: {0}" -f $total)
            foreach ($u in $list) { Write-Output ("  - {0}" -f $u.Title) }

            if ($total -gt 0) {
                # Instalar todo (misma orden que funciono: Install-WindowsUpdate -AcceptAll)
                Write-Output "Instalando actualizaciones (AcceptAll). Puede tardar..."
                $results = @(PSWindowsUpdate\Install-WindowsUpdate -AcceptAll -IgnoreReboot -Confirm:$false -ErrorAction Stop)
                foreach ($r in $results) {
                    Write-Output ("  {0}  {1}" -f $r.Result, $r.Title)
                    if ("$($r.Result)" -match "Installed") { $installed++ }
                    elseif ("$($r.Result)" -match "Failed|Error") { $failed++ }
                }

                # Revisar reinicio
                try {
                    $rb = PSWindowsUpdate\Get-WURebootStatus -Silent -ErrorAction Stop
                    if ($rb) { $reboot = [bool]$rb.RebootRequired }
                }
                catch { }
            }
        }
        else {
            Write-Output "PSWindowsUpdate no esta disponible; usando la API COM de respaldo."
            $comResult = Invoke-WindowsUpdateCom
            $installed = $comResult.Installed
            $failed = $comResult.Failed
            $reboot = $comResult.Reboot
            $total = $comResult.Total
        }

        # Estado final real (conteo de pendientes)
        $status = Get-WindowsUpdateStatus
        $pendingTitles = @($status.Updates)
        if ($status.RebootRequired) { $reboot = $true }

        if ($installed -eq 0 -and $total -gt 0 -and $pendingTitles.Count -lt $total) {
            $installed = $total - $pendingTitles.Count
            $failed = 0
        }

        Write-Output ("Resultado -> Instaladas: {0}; Fallidas: {1}; Pendientes: {2}; Reinicio requerido: {3}" -f $installed, $failed, $pendingTitles.Count, $reboot)
        Write-Log ("Windows Update -> Instaladas: {0}; Fallidas: {1}; Pendientes: {2}; Reinicio: {3}" -f $installed, $failed, $pendingTitles.Count, $reboot) "INFO"
    }
    catch {
        Write-Output ("Error general: {0}" -f $_)
        try { Write-Output ("  HResult: {0}" -f (Format-WuCode $_.Exception.HResult)) } catch { }
        Write-Log "Error en la instalacion de Windows Update: $_" "ERROR"
        $failed++
    }

    # Marcadores para la GUI
    Write-Output ("@@WU_TOTAL@@" + $total)
    Write-Output ("@@WU_INSTALLED@@" + $installed)
    Write-Output ("@@WU_FAILED@@" + $failed)
    Write-Output ("@@WU_REBOOT@@" + $reboot)
    foreach ($t in $pendingTitles) { Write-Output ("@@UPDATE@@" + $t) }
    Write-Output ("@@WU_PENDING@@" + $pendingTitles.Count)
}

Export-ModuleMember -Function Get-WindowsUpdateStatus, Invoke-WindowsUpdateInstall
