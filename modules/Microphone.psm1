# ============================================
# Detección de micrófono
# ============================================

function Test-MicrophoneDevice {
    [CmdletBinding()]
    param()

    try {
        # Buscar endpoints de audio de captura (microfonos)
        $devices = @(Get-WmiObject -Class Win32_PnPEntity -ErrorAction Stop) |
            Where-Object {
                $_.PNPClass -eq "AudioEndpoint" -and
                ($_.Name -match "microphone|micrófono|mic" -or $_.Name -match "capture|entrada")
            }

        if ($devices.Count -gt 0) {
            return $true
        }

        # Alternativa: dispositivos de sonido de entrada
        $sound = @(Get-WmiObject -Class Win32_SoundDevice -ErrorAction SilentlyContinue)
        return ($sound.Count -gt 0)
    }
    catch {
        Write-Log "Error detectando microfono: $_" "ERROR"
        return $false
    }
}

function Open-SoundSettings {
    [CmdletBinding()]
    param()

    try {
        Start-Process "ms-settings:sound"
        Write-Log "Configuracion de sonido abierta." "INFO"
        return $true
    }
    catch {
        Write-Log "Error abriendo configuracion de sonido: $_" "ERROR"
        return $false
    }
}

Export-ModuleMember -Function Test-MicrophoneDevice, Open-SoundSettings
