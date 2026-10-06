# ============================================
#  Gestión de actualizaciones
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
            $result.Updates += $update.Title
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

Export-ModuleMember -Function Get-WindowsUpdateStatus
