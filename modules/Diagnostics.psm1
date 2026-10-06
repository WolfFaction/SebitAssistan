# ============================================
# Diagnósticos del sistema
# ============================================

function New-DiagnosticResult {
    param([string]$Status = "Passed")
    return @{
        Status   = $Status
        Messages = @()
    }
}

function Start-NetworkDiagnostics {
    [CmdletBinding()]
    param()

    $result = New-DiagnosticResult

    try {
        $adapters = @(Get-WmiObject -Class Win32_NetworkAdapter -ErrorAction Stop) |
            Where-Object { $_.NetEnabled -eq $true }

        if ($adapters.Count -eq 0) {
            $result.Status = "Failed"
            $result.Messages += "No se encontraron adaptadores de red activos."
            return $result
        }

        foreach ($adapter in $adapters) {
            $result.Messages += "Adaptador de red activo: $($adapter.Name)"
        }

        # Direccion IP / gateway / DNS del primer adaptador con IP
        $configs = @(Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ErrorAction Stop) |
            Where-Object { $_.IPEnabled -eq $true }

        if ($configs.Count -eq 0) {
            $result.Status = "Warning"
            $result.Messages += "No se encontro configuracion IP activa."
        }
        else {
            $cfg = $configs | Select-Object -First 1
            if ($cfg.IPAddress) { $result.Messages += "Direccion IP: $($cfg.IPAddress -join ', ')" }
            if ($cfg.DefaultIPGateway) { $result.Messages += "Gateway: $($cfg.DefaultIPGateway -join ', ')" }
            if ($cfg.DNSServerSearchOrder) { $result.Messages += "DNS: $($cfg.DNSServerSearchOrder -join ', ')" }
        }

        # Conectividad
        if (Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            $result.Messages += "Conectividad a Internet: OK"
        }
        else {
            if ($result.Status -eq "Passed") { $result.Status = "Warning" }
            $result.Messages += "Sin conectividad a Internet (ping 8.8.8.8 fallo)."
        }

        # Resolucion DNS
        try {
            $null = Resolve-DnsName -Name "www.microsoft.com" -ErrorAction Stop
            $result.Messages += "Resolucion DNS: OK"
        }
        catch {
            if ($result.Status -eq "Passed") { $result.Status = "Warning" }
            $result.Messages += "Resolucion DNS fallida."
        }
    }
    catch {
        $result.Status = "Failed"
        $result.Messages += "Error en diagnostico de red: $_"
    }

    return $result
}

function Start-StorageDiagnostics {
    [CmdletBinding()]
    param()

    $result = New-DiagnosticResult

    try {
        $disks = @(Get-WmiObject -Class Win32_LogicalDisk -ErrorAction Stop) |
            Where-Object { $_.DriveType -eq 3 }

        if ($disks.Count -eq 0) {
            $result.Status = "Warning"
            $result.Messages += "No se encontraron discos locales."
            return $result
        }

        foreach ($disk in $disks) {
            if (-not $disk.Size -or $disk.Size -eq 0) { continue }

            $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
            $totalSpace = [math]::Round($disk.Size / 1GB, 2)
            $percentFree = [math]::Round(($freeSpace / $totalSpace) * 100, 2)

            $result.Messages += "Disco $($disk.DeviceID) - Libre: $freeSpace GB de $totalSpace GB ($percentFree% libre)"

            if ($percentFree -lt 10) {
                $result.Status = "Warning"
                $result.Messages += "ADVERTENCIA: Poco espacio en disco $($disk.DeviceID)."
            }
        }
    }
    catch {
        $result.Status = "Failed"
        $result.Messages += "Error en diagnostico de almacenamiento: $_"
    }

    return $result
}

function Start-MemoryDiagnostics {
    [CmdletBinding()]
    param()

    $result = New-DiagnosticResult

    try {
        $memory = @(Get-WmiObject -Class Win32_PhysicalMemory -ErrorAction Stop)

        if ($memory.Count -eq 0) {
            $result.Status = "Warning"
            $result.Messages += "No se detectaron modulos de memoria fisica."
            return $result
        }

        $totalRAM = 0
        foreach ($module in $memory) {
            if ($module.Capacity) {
                $capacity = [math]::Round($module.Capacity / 1GB, 2)
                $totalRAM += $capacity
                $result.Messages += "Modulo: $capacity GB - Velocidad: $($module.Speed) MHz"
            }
        }

        $result.Messages += "Total RAM instalada: $([math]::Round($totalRAM, 2)) GB"
    }
    catch {
        $result.Status = "Failed"
        $result.Messages += "Error en diagnostico de memoria: $_"
    }

    return $result
}

function Start-HardwareDiagnostics {
    [CmdletBinding()]
    param()

    $result = New-DiagnosticResult

    try {
        # Tarjeta grafica
        $gpus = @(Get-WmiObject -Class Win32_VideoController -ErrorAction SilentlyContinue)
        foreach ($gpu in $gpus) {
            if ($gpu.Name) { $result.Messages += "GPU: $($gpu.Name)" }
        }
        if ($gpus.Count -eq 0) {
            $result.Messages += "No se detectaron tarjetas graficas."
            $result.Status = "Warning"
        }

        # Bateria (si aplica)
        $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $result.Messages += "Bateria detectada: $($battery.EstimatedChargeRemaining)% restante"
        }

        # Dispositivos con problemas
        $problemDevices = @(Get-WmiObject -Class Win32_PnPEntity -ErrorAction SilentlyContinue) |
            Where-Object { $_.ConfigManagerErrorCode -ne 0 }

        if ($problemDevices.Count -gt 0) {
            $result.Status = "Warning"
            foreach ($dev in $problemDevices) {
                $result.Messages += "Dispositivo con problema: $($dev.Name) (codigo $($dev.ConfigManagerErrorCode))"
            }
        }
        else {
            $result.Messages += "No se detectaron dispositivos con problemas."
        }
    }
    catch {
        $result.Status = "Failed"
        $result.Messages += "Error en diagnostico de hardware: $_"
    }

    return $result
}

Export-ModuleMember -Function Start-NetworkDiagnostics, Start-StorageDiagnostics, Start-MemoryDiagnostics, Start-HardwareDiagnostics
