# ============================================
#  Información del sistema
# ============================================

function Get-SystemInformation {
    $info = @{
        Manufacturer    = "Desconocido"
        Model           = "Desconocido"
        Serial          = "Desconocido"
        OS              = "Desconocido"
        Architecture    = "Desconocido"
        CPU             = "Desconocido"
        RAM             = "Desconocido"
        Disks           = ""
        NetworkAdapters = ""
        BIOS            = "Desconocido"
    }

    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        if ($os) {
            $info.OS = $os.Caption
            $info.Architecture = $os.OSArchitecture
        }
    }
    catch {
        Write-Log "No se pudo leer Win32_OperatingSystem: $_" "WARNING"
    }

    try {
        $cs = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
        if ($cs) {
            $info.Manufacturer = $cs.Manufacturer
            $info.Model = $cs.Model
            if ($cs.TotalPhysicalMemory) {
                $totalRAM = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
                $info.RAM = "$totalRAM GB"
            }
        }
    }
    catch {
        Write-Log "No se pudo leer Win32_ComputerSystem: $_" "WARNING"
    }

    try {
        $bios = Get-WmiObject -Class Win32_BIOS -ErrorAction Stop
        if ($bios) {
            $info.Serial = $bios.SerialNumber
            $info.BIOS = "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)".Trim()
        }
    }
    catch {
        Write-Log "No se pudo leer Win32_BIOS: $_" "WARNING"
    }

    try {
        $cpu = @(Get-WmiObject -Class Win32_Processor -ErrorAction Stop) | Select-Object -First 1
        if ($cpu) {
            $info.CPU = "$($cpu.Name)".Trim()
        }
    }
    catch {
        Write-Log "No se pudo leer Win32_Processor: $_" "WARNING"
    }

    try {
        $disks = @(Get-WmiObject -Class Win32_DiskDrive -ErrorAction Stop) | ForEach-Object {
            if ($_.Size) {
                "$($_.Model) - $([math]::Round($_.Size / 1GB, 2)) GB"
            }
            else {
                "$($_.Model)"
            }
        }
        $info.Disks = ($disks -join "; ")
    }
    catch {
        Write-Log "No se pudieron leer los discos: $_" "WARNING"
    }

    try {
        $adapters = @(Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction Stop) |
            Where-Object { $_.NetEnabled -eq $true } |
            ForEach-Object { $_.Name }
        $info.NetworkAdapters = ($adapters -join "; ")
    }
    catch {
        Write-Log "No se pudieron leer los adaptadores de red: $_" "WARNING"
    }

    return $info
}

Export-ModuleMember -Function Get-SystemInformation
