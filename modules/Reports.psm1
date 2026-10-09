# ============================================
# Generación de reportes
# ============================================

function ConvertTo-HtmlSafe {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return "" }
    return ($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

function New-DiagnosticReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$SystemInfo,

        [Parameter(Mandatory = $true)]
        [array]$Checklist,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [array]$AutoResults = @(),

        [array]$WindowsUpdates = @(),

        [string]$Technician = ""
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Resumen de estados
    $total = $Checklist.Count
    $completed = @($Checklist | Where-Object { $_.Status -in @("Passed", "Warning", "ManualCheck", "Failed", "Skipped") }).Count

    $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Reporte de Diagnostico - SebitAssistan</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 960px; margin: 0 auto; background: white; padding: 30px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; vertical-align: top; }
        th { background: #3498db; color: white; }
        tr:hover { background: #f5f5f5; }
        .status-passed { color: #27ae60; font-weight: bold; }
        .status-failed { color: #e74c3c; font-weight: bold; }
        .status-warning { color: #f39c12; font-weight: bold; }
        .status-manualcheck { color: #f39c12; font-weight: bold; }
        .status-running { color: #2980b9; font-weight: bold; }
        .status-skipped { color: #7f8c8d; }
        .status-pending { color: #95a5a6; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
        .info-item { padding: 10px; background: #ecf0f1; border-radius: 5px; }
        .info-label { font-weight: bold; color: #7f8c8d; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Reporte de Diagnostico - SebitAssistan</h1>
        <p>Generado: $timestamp</p>
        <p>Tecnico: $(ConvertTo-HtmlSafe $Technician)</p>
        <p>Tareas completadas: $completed / $total</p>

        <h2>Informacion del equipo</h2>
        <div class="info-grid">
            <div class="info-item"><span class="info-label">Fabricante:</span> $(ConvertTo-HtmlSafe $SystemInfo.Manufacturer)</div>
            <div class="info-item"><span class="info-label">Modelo:</span> $(ConvertTo-HtmlSafe $SystemInfo.Model)</div>
            <div class="info-item"><span class="info-label">Numero de serie:</span> $(ConvertTo-HtmlSafe $SystemInfo.Serial)</div>
            <div class="info-item"><span class="info-label">Windows:</span> $(ConvertTo-HtmlSafe $SystemInfo.OS)</div>
            <div class="info-item"><span class="info-label">Arquitectura:</span> $(ConvertTo-HtmlSafe $SystemInfo.Architecture)</div>
            <div class="info-item"><span class="info-label">CPU:</span> $(ConvertTo-HtmlSafe $SystemInfo.CPU)</div>
            <div class="info-item"><span class="info-label">RAM:</span> $(ConvertTo-HtmlSafe $SystemInfo.RAM)</div>
            <div class="info-item"><span class="info-label">BIOS:</span> $(ConvertTo-HtmlSafe $SystemInfo.BIOS)</div>
            <div class="info-item" style="grid-column: 1 / -1;"><span class="info-label">Discos:</span> $(ConvertTo-HtmlSafe $SystemInfo.Disks)</div>
            <div class="info-item" style="grid-column: 1 / -1;"><span class="info-label">Red:</span> $(ConvertTo-HtmlSafe $SystemInfo.NetworkAdapters)</div>
        </div>

        <h2>Checklist</h2>
        <table>
            <tr>
                <th>ID</th>
                <th>Tarea</th>
                <th>Categoria</th>
                <th>Estado</th>
                <th>Resultado</th>
                <th>Fecha</th>
            </tr>
"@

    foreach ($task in $Checklist) {
        $statusText = "$($task.Status)"
        if ([string]::IsNullOrEmpty($statusText)) { $statusText = "Pending" }
        $statusClass = "status-" + ($statusText.ToLower())

        $html += @"
            <tr>
                <td>$($task.Id)</td>
                <td>$(ConvertTo-HtmlSafe $task.Name)</td>
                <td>$(ConvertTo-HtmlSafe $task.Category)</td>
                <td class="$statusClass">$(ConvertTo-HtmlSafe $statusText)</td>
                <td>$(ConvertTo-HtmlSafe $task.Result)</td>
                <td>$(ConvertTo-HtmlSafe $task.Timestamp)</td>
            </tr>
"@
    }

    # Observaciones
    $notes = @($Checklist | Where-Object { -not [string]::IsNullOrEmpty($_.Notes) })

    # Seccion de acciones y diagnosticos automaticos
    $autoHtml = ""
    if ($AutoResults.Count -gt 0) {
        $autoHtml += @"
        </table>

        <h2>Diagnosticos y acciones automaticas</h2>
        <table>
            <tr>
                <th>Accion</th>
                <th>Estado</th>
                <th>Resultado</th>
                <th>Fecha</th>
            </tr>
"@
        foreach ($auto in $AutoResults) {
            $autoStatus = "$($auto.Status)"
            if ([string]::IsNullOrEmpty($autoStatus)) { $autoStatus = "Pending" }
            $autoClass = "status-" + ($autoStatus.ToLower())
            $autoHtml += @"
            <tr>
                <td>$(ConvertTo-HtmlSafe $auto.Name)</td>
                <td class="$autoClass">$(ConvertTo-HtmlSafe $autoStatus)</td>
                <td>$(ConvertTo-HtmlSafe $auto.Result)</td>
                <td>$(ConvertTo-HtmlSafe $auto.Timestamp)</td>
            </tr>
"@
        }
        $autoHtml += "        </table>`r`n"
    }
    else {
        $autoHtml = "        </table>`r`n"
    }

    $html += $autoHtml

    if ($WindowsUpdates.Count -gt 0) {
        $html += @"

        <h2>Actualizaciones de Windows pendientes ($($WindowsUpdates.Count))</h2>
        <ul>
"@
        foreach ($update in $WindowsUpdates) {
            $html += "            <li>$(ConvertTo-HtmlSafe $update)</li>`r`n"
        }
        $html += "        </ul>`r`n"
    }

    $html += @"

        <h2>Observaciones del tecnico</h2>
"@

    if ($notes.Count -gt 0) {
        $html += "<ul>"
        foreach ($n in $notes) {
            $html += "<li><strong>$(ConvertTo-HtmlSafe $n.Name):</strong> $(ConvertTo-HtmlSafe $n.Notes)</li>"
        }
        $html += "</ul>"
    }
    else {
        $html += "<p>Sin observaciones registradas.</p>"
    }

    $html += @"
        <div class="footer">
            <p>SebitAssistan v2.1.0 - Windows Diagnostic Assistant</p>
        </div>
    </div>
</body>
</html>
"@

    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $html | Out-File -LiteralPath $OutputPath -Encoding UTF8
    Write-Log "Reporte generado: $OutputPath" "INFO"
}

Export-ModuleMember -Function New-DiagnosticReport
