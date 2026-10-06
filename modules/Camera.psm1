# ============================================
#  Detección de cámara
# ============================================

function Test-CameraDevice {
    [CmdletBinding()]
    param()

    try {
        $cameras = @(Get-WmiObject -Class Win32_PnPEntity -ErrorAction Stop) |
            Where-Object { $_.PNPClass -eq "Camera" -or $_.PNPClass -eq "Image" }
        return ($cameras.Count -gt 0)
    }
    catch {
        Write-Log "Error detectando camara: $_" "ERROR"
        return $false
    }
}

function Open-CameraApp {
    [CmdletBinding()]
    param()

    try {
        Start-Process "microsoft.windows.camera:"
        Write-Log "Aplicacion de camara abierta." "INFO"
        return $true
    }
    catch {
        Write-Log "Error abriendo aplicacion de camara: $_" "ERROR"
        return $false
    }
}

Export-ModuleMember -Function Test-CameraDevice, Open-CameraApp
