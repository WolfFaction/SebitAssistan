# ============================================
# Interfaz gráfica Windows Forms
# ============================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------
# Estado interno
# ---------------------------------------------------------

$script:ActiveJobs = @()
$script:JobsActiveSince = $null
$global:ActivityVerbose = $true

# Definicion de las acciones automaticas (no forman parte del checklist manual)
function Get-AutoActionDefinitions {
    return [ordered]@{
        inventory    = "Inventario del sistema"
        manufacturer = "Aplicacion del fabricante"
        apps         = "Aplicaciones de diagnostico"
        storage      = "Diagnostico de almacenamiento"
        memory       = "Diagnostico de memoria"
        network      = "Diagnostico de red"
        hardware     = "Diagnostico de hardware"
        wu           = "Windows Update"
    }
}

function Initialize-AutoResults {
    $defs = Get-AutoActionDefinitions
    $ordered = [ordered]@{}
    foreach ($key in $defs.Keys) {
        $ordered[$key] = [PSCustomObject]@{
            Id        = $key
            Name      = $defs[$key]
            Status    = "Pending"
            Result    = ""
            Timestamp = ""
        }
    }
    return $ordered
}

# ---------------------------------------------------------
# Actividad en vivo (muestra TODO, incluido DEBUG)
# ---------------------------------------------------------

function Register-ActivitySink {
    $global:ActivitySink = {
        param($line)
        try {
            if (-not $global:ActivityBox) { return }
            if (($line -match '\[DEBUG\]') -and (-not $global:ActivityVerbose)) { return }
            $global:ActivityBox.AppendText($line + "`r`n")
            $global:ActivityBox.SelectionStart = $global:ActivityBox.TextLength
            $global:ActivityBox.ScrollToCaret()
        }
        catch { }
    }
}

function Add-Activity {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    Write-Log -Message $Message -Level $Level
}

# ---------------------------------------------------------
# Utilidades de interfaz
# ---------------------------------------------------------

function Set-Progress {
    param([int]$Percent)

    try {
        if ($global:progressBar) {
            if ($Percent -gt 100) { $Percent = 100 }
            if ($Percent -lt 0) { $Percent = 0 }
            if ($global:progressBar.Style -ne "Marquee") { $global:progressBar.Value = $Percent }
        }
    }
    catch { }
}

# Barra en movimiento mientras hay tareas en segundo plano
function Set-ProgressMarquee {
    param([bool]$Enabled)

    try {
        if (-not $global:progressBar) { return }
        if ($Enabled) {
            $global:progressBar.Style = "Marquee"
            $global:progressBar.MarqueeAnimationSpeed = 30
        }
        else {
            $global:progressBar.Style = "Continuous"
        }
    }
    catch { }
}

# Aplica un tema oscuro a toda la ventana de forma recursiva
function Apply-DarkTheme {
    param([System.Windows.Forms.Control]$Control)

    $panelBg = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $controlBg = [System.Drawing.Color]::FromArgb(62, 62, 66)
    $fg = [System.Drawing.Color]::FromArgb(230, 230, 230)

    foreach ($child in $Control.Controls) {
        $typeName = $child.GetType().Name
        switch ($typeName) {
            "Button" {
                $child.BackColor = $controlBg
                $child.ForeColor = $fg
                $child.FlatStyle = "Flat"
                $child.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(90, 90, 94)
                $child.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(82, 82, 86)
                $child.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(40, 40, 44)
            }
            "ComboBox" {
                $child.BackColor = $controlBg
                $child.ForeColor = $fg
                $child.FlatStyle = "Flat"
            }
            "TextBox" {
                $child.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 28)
                $child.ForeColor = $fg
            }
            "ProgressBar" {
                # La barra de progreso mantiene el estilo del sistema
            }
            default {
                $child.BackColor = $panelBg
                $child.ForeColor = $fg
            }
        }

        if ($child.HasChildren) { Apply-DarkTheme -Control $child }
    }
}

function Update-UiStatus {
    param(
        [string]$Text,
        [int]$Percent = -1
    )

    try {
        if ($global:lblStatus) { $global:lblStatus.Text = "Estado: $Text" }
        if ($Percent -ge 0) { Set-Progress -Percent $Percent }
        [System.Windows.Forms.Application]::DoEvents()
    }
    catch { }
}

function Refresh-ChecklistUi {
    if (-not $global:checkboxes) { return }

    foreach ($chk in $global:checkboxes) {
        $id = [int]$chk.Tag
        $task = @($global:ManualChecklist | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
        if ($task) {
            $chk.Text = "{0}. {1}   [{2}]" -f $task.Id, $task.Name, $task.Status
        }
    }
}

function Update-SystemInfoLabels {
    param([hashtable]$Info)

    $global:SystemInfo = $Info
    if ($global:lblManufacturer) { $global:lblManufacturer.Text = "Fabricante: $($Info.Manufacturer)" }
    if ($global:lblModel)        { $global:lblModel.Text        = "Modelo: $($Info.Model)" }
    if ($global:lblSerial)       { $global:lblSerial.Text       = "Número de serie: $($Info.Serial)" }
    if ($global:lblOS)           { $global:lblOS.Text           = "Windows: $($Info.OS)" }
    if ($global:lblCPU)          { $global:lblCPU.Text          = "CPU: $($Info.CPU)" }
    if ($global:lblRAM)          { $global:lblRAM.Text          = "RAM: $($Info.RAM)" }
}

function Update-OverallProgress {
    $manualTotal = $global:ManualChecklist.Count
    $manualDone = @($global:ManualChecklist | Where-Object { $_.Status -ne "Pending" }).Count
    $autoTotal = $global:AutoResults.Count
    $autoDone = @($global:AutoResults.Values | Where-Object { $_.Status -notin @("Pending", "Running") }).Count

    $total = $manualTotal + $autoTotal
    if ($total -eq 0) { return }

    $done = $manualDone + $autoDone
    Set-Progress -Percent ([int](($done / $total) * 100))
}

function Set-AutoResult {
    param(
        [string]$Id,
        [string]$Status,
        [string]$Result
    )

    if (-not $global:AutoResults.Contains($Id)) { return }

    $global:AutoResults[$Id].Status = $Status
    $global:AutoResults[$Id].Result = $Result
    $global:AutoResults[$Id].Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Log ("Resultado [{0}]: {1} - {2}" -f $Id, $Status, $Result) "DEBUG"
    Update-OverallProgress
}

# ---------------------------------------------------------
# Ejecucion en segundo plano (jobs) con salida en vivo
# ---------------------------------------------------------

function Start-ActivityJob {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @(),
        [scriptblock]$OnComplete = $null,
        [string]$AutoId = ""
    )

    Write-Log "Iniciando: $Name" "INFO"
    Write-Log ("Argumentos del job: {0}" -f ($ArgumentList -join " | ")) "DEBUG"

    try {
        $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    }
    catch {
        Write-Log "No se pudo iniciar la tarea '$Name': $_" "ERROR"
        if ($AutoId) { Set-AutoResult -Id $AutoId -Status "Failed" -Result "No se pudo iniciar la tarea." }
        return $null
    }

    $record = [PSCustomObject]@{
        Name       = $Name
        Job        = $job
        Seen       = 0
        Lines      = (New-Object System.Collections.ArrayList)
        OnComplete = $OnComplete
        AutoId     = $AutoId
    }

    if ($script:ActiveJobs.Count -eq 0) { $script:JobsActiveSince = Get-Date }
    $script:ActiveJobs += $record
    if ($global:JobTimer) { $global:JobTimer.Start() }
    return $record
}

function Update-ActivityJobs {
    if (-not $script:ActiveJobs -or $script:ActiveJobs.Count -eq 0) {
        if ($global:JobTimer) { $global:JobTimer.Stop() }
        return
    }

    $remaining = @()

    foreach ($rec in $script:ActiveJobs) {
        $job = $rec.Job

        try {
            $output = @(Receive-Job -Job $job -Keep 2>&1)
        }
        catch {
            $output = @()
        }

        if ($output.Count -gt $rec.Seen) {
            for ($i = $rec.Seen; $i -lt $output.Count; $i++) {
                $text = "$($output[$i])".TrimEnd()
                if ($text.Trim() -ne "") {
                    [void]$rec.Lines.Add($text)
                    # No mostrar en la ventana los marcadores internos "@@..."
                    if ($text -notlike "@@*") {
                        Write-Log ("[{0}] {1}" -f $rec.Name, $text) "INFO"
                    }
                }
            }
            $rec.Seen = $output.Count
        }

        $state = $job.State
        if ($state -in @("Completed", "Failed", "Stopped")) {
            Write-Log ("Tarea '{0}' estado: {1}" -f $rec.Name, $state) "DEBUG"
            if ($state -eq "Completed") {
                Write-Log ("Finalizado: {0}" -f $rec.Name) "INFO"
            }
            else {
                Write-Log ("La tarea '{0}' termino con estado {1}" -f $rec.Name, $state) "ERROR"
            }

            if ($rec.OnComplete) {
                try { & $rec.OnComplete $rec }
                catch { Write-Log ("Error procesando resultado de '{0}': {1}" -f $rec.Name, $_) "ERROR" }
            }

            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
        else {
            $remaining += $rec
        }
    }

    $script:ActiveJobs = $remaining
    if ($script:ActiveJobs.Count -eq 0) {
        if ($global:JobTimer) { $global:JobTimer.Stop() }
        Set-ProgressMarquee -Enabled $false
        Update-OverallProgress
        Update-UiStatus "Tareas finalizadas"
    }
    else {
        Set-ProgressMarquee -Enabled $true
        $elapsed = 0
        if ($script:JobsActiveSince) { $elapsed = [int]((Get-Date) - $script:JobsActiveSince).TotalSeconds }
        Update-UiStatus ("Tareas en curso: {0} ({1}s)" -f $script:ActiveJobs.Count, $elapsed)
    }
}

# ---------------------------------------------------------
# Scripts que se ejecutan en segundo plano
# ---------------------------------------------------------

$script:DiagJobScript = {
    param($ModuleRoot, $Function)

    Import-Module (Join-Path $ModuleRoot "modules\Core.psm1") -Force
    Import-Module (Join-Path $ModuleRoot "modules\Diagnostics.psm1") -Force

    $r = & $Function
    Write-Output ("@@STATUS@@" + $r.Status)
    foreach ($m in $r.Messages) { Write-Output ("@@MSG@@" + $m) }
}

$script:WuJobScript = {
    param($ModuleRoot)

    Import-Module (Join-Path $ModuleRoot "modules\Core.psm1") -Force
    Import-Module (Join-Path $ModuleRoot "modules\WindowsUpdate.psm1") -Force

    $r = Get-WindowsUpdateStatus
    if ($r.Error) { Write-Output ("@@ERROR@@" + $r.Error) }
    Write-Output ("@@FOUND@@" + $r.Found)
    Write-Output ("@@PENDING@@" + $r.Pending)
    Write-Output ("@@REBOOT@@" + $r.RebootRequired)
    foreach ($u in $r.Updates) { Write-Output ("@@UPDATE@@" + $u) }
}

$script:WingetJobScript = {
    param($WingetId)

    $ErrorActionPreference = "Continue"
    Write-Output ("Ejecutando: winget install --id $WingetId -e --source winget --accept-package-agreements --accept-source-agreements --silent")
    & winget install --id $WingetId -e --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1 |
        ForEach-Object { Write-Output ("$_") }
    Write-Output ("@@EXITCODE@@" + $LASTEXITCODE)
}

$script:DriversJobScript = {
    param($ModuleRoot, $Action, $Argument)

    Import-Module (Join-Path $ModuleRoot "modules\Core.psm1") -Force
    Import-Module (Join-Path $ModuleRoot "modules\Drivers.psm1") -Force

    if ($Action -eq "export") {
        Export-Drivers -FolderName $Argument
    }
    elseif ($Action -eq "install") {
        Install-DriversFromFolder -Path $Argument
    }
}

$script:OnDiagComplete = {
    param($rec)

    $status = "Passed"
    $msgs = @()
    foreach ($l in $rec.Lines) {
        if ($l -like "@@STATUS@@*") { $status = $l.Substring(10) }
        elseif ($l -like "@@MSG@@*") { $msgs += $l.Substring(7) }
    }
    Set-AutoResult -Id $rec.AutoId -Status $status -Result ($msgs -join " | ")
}

$script:OnWUComplete = {
    param($rec)

    $found = 0; $pending = 0; $reboot = $false; $err = $null
    $items = @()
    foreach ($l in $rec.Lines) {
        if ($l -like "@@ERROR@@*") { $err = $l.Substring(9) }
        elseif ($l -like "@@FOUND@@*") { [void][int]::TryParse($l.Substring(9), [ref]$found) }
        elseif ($l -like "@@PENDING@@*") { [void][int]::TryParse($l.Substring(11), [ref]$pending) }
        elseif ($l -like "@@REBOOT@@*") { $reboot = ($l.Substring(10) -eq "True") }
        elseif ($l -like "@@UPDATE@@*") { $items += $l.Substring(10) }
    }

    $global:WindowsUpdateItems = $items

    if ($err) {
        Set-AutoResult -Id "wu" -Status "Failed" -Result $err
        Write-Log ("Windows Update: error -> {0}" -f $err) "ERROR"
    }
    else {
        $status = if ($pending -gt 0 -or $reboot) { "Warning" } else { "Passed" }
        Set-AutoResult -Id "wu" -Status $status -Result "Encontradas: $found; Pendientes: $pending; Reinicio requerido: $reboot"
        Write-Log ("Windows Update: {0} encontradas, {1} pendientes, reinicio={2}" -f $found, $pending, $reboot) "INFO"
        if ($items.Count -gt 0) {
            Write-Log ("Actualizaciones pendientes ({0}):" -f $items.Count) "INFO"
            foreach ($u in $items) { Write-Log ("  - {0}" -f $u) "INFO" }
        }
    }
}

$script:OnWingetComplete = {
    param($rec)

    $code = -1
    foreach ($l in $rec.Lines) {
        if ($l -like "@@EXITCODE@@*") { [void][int]::TryParse($l.Substring(12), [ref]$code) }
    }

    if ($code -eq 0) {
        Set-AutoResult -Id "manufacturer" -Status "Passed" -Result ("Instalacion completada: {0}" -f $rec.Name)
        Update-UiStatus "Instalacion completada: $($rec.Name)"
    }
    else {
        Set-AutoResult -Id "manufacturer" -Status "Failed" -Result ("winget finalizo con codigo $code")
        Update-UiStatus "Instalacion fallida (codigo $code)"
    }
}

$script:OnDriverComplete = {
    param($rec)

    $code = -1
    foreach ($l in $rec.Lines) {
        if ($l -like "@@DRIVER_EXIT@@*") { [void][int]::TryParse($l.Substring(15), [ref]$code) }
    }

    if ($code -eq 0) {
        Write-Log ("{0}: completado correctamente." -f $rec.Name) "INFO"
        Update-UiStatus ("{0}: completado" -f $rec.Name)
    }
    else {
        Write-Log ("{0}: finalizo con codigo {1}" -f $rec.Name, $code) "WARNING"
        Update-UiStatus ("{0}: codigo {1}" -f $rec.Name, $code)
    }

    try { Refresh-DriverFoldersUi } catch { }
}

# ---------------------------------------------------------
# Acciones automaticas
# ---------------------------------------------------------

function Start-DiagnosticJob {
    param(
        [string]$Id,
        [string]$Function
    )

    $name = if ($global:AutoResults.Contains($Id)) { $global:AutoResults[$Id].Name } else { $Function }
    Set-AutoResult -Id $Id -Status "Running" -Result "En ejecucion..."
    Start-ActivityJob -Name $name -ScriptBlock $script:DiagJobScript -ArgumentList @($global:ProjectRoot, $Function) -AutoId $Id -OnComplete $script:OnDiagComplete | Out-Null
}

function Start-WindowsUpdateJob {
    Set-AutoResult -Id "wu" -Status "Running" -Result "En ejecucion..."
    Write-Log "Buscando actualizaciones de Windows (puede tardar varios minutos)..." "INFO"
    Start-ActivityJob -Name "Windows Update" -ScriptBlock $script:WuJobScript -ArgumentList @($global:ProjectRoot) -AutoId "wu" -OnComplete $script:OnWUComplete | Out-Null
}

function Start-ManufacturerInstall {
    param(
        [string]$WingetId,
        [string]$Name
    )

    Set-AutoResult -Id "manufacturer" -Status "Running" -Result "Instalando $Name..."
    Start-ActivityJob -Name ("Instalacion: {0}" -f $Name) -ScriptBlock $script:WingetJobScript -ArgumentList @($WingetId) -AutoId "manufacturer" -OnComplete $script:OnWingetComplete | Out-Null
}

function Invoke-AutoAction {
    param([string]$Id)

    switch ($Id) {
        "inventory" {
            Write-Log "Recolectando informacion del sistema..." "INFO"
            $info = Get-SystemInformation
            Update-SystemInfoLabels -Info $info
            Set-AutoResult -Id "inventory" -Status "Passed" -Result ("Equipo: {0} {1}" -f $info.Manufacturer, $info.Model)
        }
        "manufacturer" {
            $mfr = if ($global:SystemInfo) { $global:SystemInfo.Manufacturer } else { (Get-SystemInformation).Manufacturer }
            Write-Log "Consultando herramienta del fabricante ($mfr)..." "INFO"
            $plan = Get-ManufacturerInstallPlan -Manufacturer $mfr
            Write-Log ("Plan fabricante: {0}" -f $plan.Message) "DEBUG"
            Set-AutoResult -Id "manufacturer" -Status "ManualCheck" -Result ("{0}: {1}" -f $plan.Manufacturer, $plan.Message)
        }
        "apps" {
            Write-Log "Buscando aplicaciones de diagnostico en apps/..." "INFO"
            $apps = Get-DiagnosticApplications
            if ($apps.Count -gt 0) {
                Set-AutoResult -Id "apps" -Status "Passed" -Result ("{0} aplicacion(es) detectada(s)." -f $apps.Count)
            }
            else {
                Set-AutoResult -Id "apps" -Status "Warning" -Result "No se encontraron aplicaciones en apps/."
            }
        }
        "storage"  { Start-DiagnosticJob -Id "storage"  -Function "Start-StorageDiagnostics" }
        "memory"   { Start-DiagnosticJob -Id "memory"   -Function "Start-MemoryDiagnostics" }
        "network"  { Start-DiagnosticJob -Id "network"  -Function "Start-NetworkDiagnostics" }
        "hardware" { Start-DiagnosticJob -Id "hardware" -Function "Start-HardwareDiagnostics" }
        "wu"       { Start-WindowsUpdateJob }
        default    { }
    }
}

function Invoke-AllAutoActions {
    Write-Log "=== Ejecutando diagnostico completo ===" "INFO"
    foreach ($id in @("inventory", "manufacturer", "apps", "storage", "memory", "network", "hardware", "wu")) {
        Invoke-AutoAction -Id $Id
    }
}

# ---------------------------------------------------------
# Comandos del sistema (desplegable)
# ---------------------------------------------------------

function Invoke-SystemCommand {
    param($Command)

    if (-not $Command) { return }

    $line = if ($Command.args) { "$($Command.target) $($Command.args)" } else { "$($Command.target)" }
    Write-Log ("Ejecutando comando del sistema: {0}" -f $line) "DEBUG"

    try {
        if ($Command.args) {
            Start-Process -FilePath $Command.target -ArgumentList $Command.args
        }
        else {
            Start-Process -FilePath $Command.target
        }
    }
    catch {
        Write-Log ("No se pudo ejecutar '{0}': {1}" -f $Command.name, $_) "ERROR"
        [System.Windows.Forms.MessageBox]::Show("No se pudo ejecutar '$($Command.name)':`n$_", "Comando", "OK", "Warning") | Out-Null
    }
}

# Ventana con el listado completo de actualizaciones pendientes
function Show-UpdatesDialog {
    $items = @($global:WindowsUpdateItems)

    if ($items.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No hay informacion de actualizaciones. Ejecute 'Windows Update' primero.", "Windows Update", "OK", "Information") | Out-Null
        return
    }

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Actualizaciones pendientes ($($items.Count))"
    $dlg.ClientSize = New-Object System.Drawing.Size(760, 480)
    $dlg.StartPosition = "CenterScreen"
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = New-Object System.Drawing.Point(10, 10)
    $tb.Size = New-Object System.Drawing.Size(740, 420)
    $tb.Multiline = $true
    $tb.ReadOnly = $true
    $tb.ScrollBars = "Both"
    $tb.WordWrap = $false
    $tb.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
    $tb.ForeColor = [System.Drawing.Color]::Gainsboro
    $tb.Font = New-Object System.Drawing.Font("Consolas", 9)
    $tb.Text = ($items | ForEach-Object { "$_" }) -join "`r`n"
    $dlg.Controls.Add($tb)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Cerrar"
    $btnClose.Location = New-Object System.Drawing.Point(650, 438)
    $btnClose.Size = New-Object System.Drawing.Size(100, 30)
    $btnClose.FlatStyle = "Flat"
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(62, 62, 66)
    $btnClose.ForeColor = [System.Drawing.Color]::Gainsboro
    $btnClose.Add_Click({ $dlg.Close() })
    $dlg.Controls.Add($btnClose)

    [void]$dlg.ShowDialog()
}

# Cuadro de entrada de texto sencillo (tema oscuro)
function Show-InputDialog {
    param(
        [string]$Title = "Entrada",
        [string]$Prompt = "",
        [string]$DefaultValue = ""
    )

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = $Title
    $dlg.ClientSize = New-Object System.Drawing.Size(460, 150)
    $dlg.StartPosition = "CenterScreen"
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Prompt
    $lbl.Location = New-Object System.Drawing.Point(12, 15)
    $lbl.Size = New-Object System.Drawing.Size(436, 20)
    $lbl.ForeColor = [System.Drawing.Color]::Gainsboro
    $dlg.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(12, 42)
    $txt.Size = New-Object System.Drawing.Size(436, 25)
    $txt.Text = $DefaultValue
    $txt.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 28)
    $txt.ForeColor = [System.Drawing.Color]::Gainsboro
    $dlg.Controls.Add($txt)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = "Aceptar"
    $ok.Location = New-Object System.Drawing.Point(242, 95)
    $ok.Size = New-Object System.Drawing.Size(100, 30)
    $ok.FlatStyle = "Flat"
    $ok.BackColor = [System.Drawing.Color]::FromArgb(62, 62, 66)
    $ok.ForeColor = [System.Drawing.Color]::Gainsboro
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $dlg.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = "Cancelar"
    $cancel.Location = New-Object System.Drawing.Point(348, 95)
    $cancel.Size = New-Object System.Drawing.Size(100, 30)
    $cancel.FlatStyle = "Flat"
    $cancel.BackColor = [System.Drawing.Color]::FromArgb(62, 62, 66)
    $cancel.ForeColor = [System.Drawing.Color]::Gainsboro
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dlg.Controls.Add($cancel)

    $dlg.AcceptButton = $ok
    $dlg.CancelButton = $cancel

    $result = $dlg.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $txt.Text }
    return $null
}

# ---------------------------------------------------------
# Drivers
# ---------------------------------------------------------

function Refresh-DriverFoldersUi {
    if (-not $global:cmbDrivers) { return }
    $global:cmbDrivers.Items.Clear()
    $global:DriverItems = Get-DriverFolders
    foreach ($item in $global:DriverItems) { [void]$global:cmbDrivers.Items.Add($item) }
    if ($global:cmbDrivers.Items.Count -gt 0) { $global:cmbDrivers.SelectedIndex = 0 }
}

# ---------------------------------------------------------
# Construcción de la ventana principal
# ---------------------------------------------------------

function New-MainForm {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    if ($null -eq $global:ManualChecklist) { $global:ManualChecklist = Initialize-Checklist }
    if ($null -eq $global:AutoResults) { $global:AutoResults = Initialize-AutoResults }
    if ($null -eq $global:ActivityVerbose) { $global:ActivityVerbose = $true }
    if ($null -eq $global:WindowsUpdateItems) { $global:WindowsUpdateItems = @() }
    Register-ActivitySink

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Windows Diagnostic Assistant"
    $form.ClientSize = New-Object System.Drawing.Size(1000, 845)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)

    # ----- Panel de información del equipo -----
    $infoPanel = New-Object System.Windows.Forms.Panel
    $infoPanel.Location = New-Object System.Drawing.Point(10, 10)
    $infoPanel.Size = New-Object System.Drawing.Size(980, 92)
    $infoPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($infoPanel)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Equipo"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(10, 4)
    $lblTitle.Size = New-Object System.Drawing.Size(200, 18)
    $infoPanel.Controls.Add($lblTitle)

    $global:lblManufacturer = New-Object System.Windows.Forms.Label
    $global:lblManufacturer.Location = New-Object System.Drawing.Point(10, 24)
    $global:lblManufacturer.Size = New-Object System.Drawing.Size(480, 20)
    $infoPanel.Controls.Add($global:lblManufacturer)

    $global:lblModel = New-Object System.Windows.Forms.Label
    $global:lblModel.Location = New-Object System.Drawing.Point(10, 46)
    $global:lblModel.Size = New-Object System.Drawing.Size(480, 20)
    $infoPanel.Controls.Add($global:lblModel)

    $global:lblSerial = New-Object System.Windows.Forms.Label
    $global:lblSerial.Location = New-Object System.Drawing.Point(10, 68)
    $global:lblSerial.Size = New-Object System.Drawing.Size(480, 20)
    $infoPanel.Controls.Add($global:lblSerial)

    $global:lblOS = New-Object System.Windows.Forms.Label
    $global:lblOS.Location = New-Object System.Drawing.Point(500, 24)
    $global:lblOS.Size = New-Object System.Drawing.Size(470, 20)
    $infoPanel.Controls.Add($global:lblOS)

    $global:lblCPU = New-Object System.Windows.Forms.Label
    $global:lblCPU.Location = New-Object System.Drawing.Point(500, 46)
    $global:lblCPU.Size = New-Object System.Drawing.Size(470, 20)
    $infoPanel.Controls.Add($global:lblCPU)

    $global:lblRAM = New-Object System.Windows.Forms.Label
    $global:lblRAM.Location = New-Object System.Drawing.Point(500, 68)
    $global:lblRAM.Size = New-Object System.Drawing.Size(470, 20)
    $infoPanel.Controls.Add($global:lblRAM)

    # ----- Panel de Checklist (manual) -----
    $checklistPanel = New-Object System.Windows.Forms.Panel
    $checklistPanel.Location = New-Object System.Drawing.Point(10, 108)
    $checklistPanel.Size = New-Object System.Drawing.Size(330, 397)
    $checklistPanel.BorderStyle = "FixedSingle"
    $checklistPanel.AutoScroll = $true
    $form.Controls.Add($checklistPanel)

    $lblChecklist = New-Object System.Windows.Forms.Label
    $lblChecklist.Text = "Checklist manual"
    $lblChecklist.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblChecklist.Location = New-Object System.Drawing.Point(10, 6)
    $lblChecklist.Size = New-Object System.Drawing.Size(200, 18)
    $checklistPanel.Controls.Add($lblChecklist)

    $global:checkboxes = @()
    $y = 32
    foreach ($task in $global:ManualChecklist) {
        $chk = New-Object System.Windows.Forms.CheckBox
        $chk.Text = "{0}. {1}   [{2}]" -f $task.Id, $task.Name, $task.Status
        $chk.Location = New-Object System.Drawing.Point(10, $y)
        $chk.Size = New-Object System.Drawing.Size(300, 21)
        $chk.Tag = $task.Id
        $chk.Add_CheckedChanged({
            param($sender, $eventArgs)
            $id = [int]$sender.Tag
            $task = @($global:ManualChecklist | Where-Object { $_.Id -eq $id }) | Select-Object -First 1
            if ($task) {
                if ($sender.Checked) {
                    $task.Status = "ManualCheck"
                    $task.Result = "Verificado por el tecnico"
                }
                else {
                    $task.Status = "Pending"
                    $task.Result = ""
                }
                $task.Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            Refresh-ChecklistUi
            Update-OverallProgress
        })
        $global:checkboxes += $chk
        $checklistPanel.Controls.Add($chk)
        $y += 24
    }

    # ----- Panel de WiFi (solo perfiles guardados) -----
    $wifiPanel = New-Object System.Windows.Forms.Panel
    $wifiPanel.Location = New-Object System.Drawing.Point(350, 108)
    $wifiPanel.Size = New-Object System.Drawing.Size(640, 75)
    $wifiPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($wifiPanel)

    $lblWifi = New-Object System.Windows.Forms.Label
    $lblWifi.Text = "WiFi - perfiles guardados (wifi-profiles/)"
    $lblWifi.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblWifi.Location = New-Object System.Drawing.Point(10, 5)
    $lblWifi.Size = New-Object System.Drawing.Size(500, 18)
    $wifiPanel.Controls.Add($lblWifi)

    $global:cmbWifi = New-Object System.Windows.Forms.ComboBox
    $global:cmbWifi.Location = New-Object System.Drawing.Point(10, 26)
    $global:cmbWifi.Size = New-Object System.Drawing.Size(320, 25)
    $global:cmbWifi.DropDownStyle = "DropDownList"
    $global:cmbWifi.DisplayMember = "Name"
    $wifiPanel.Controls.Add($global:cmbWifi)

    $btnConnectWifi = New-Object System.Windows.Forms.Button
    $btnConnectWifi.Text = "Conectar"
    $btnConnectWifi.Location = New-Object System.Drawing.Point(335, 25)
    $btnConnectWifi.Size = New-Object System.Drawing.Size(85, 28)
    $wifiPanel.Controls.Add($btnConnectWifi)

    $btnRefreshWifi = New-Object System.Windows.Forms.Button
    $btnRefreshWifi.Text = "Actualizar"
    $btnRefreshWifi.Location = New-Object System.Drawing.Point(425, 25)
    $btnRefreshWifi.Size = New-Object System.Drawing.Size(85, 28)
    $wifiPanel.Controls.Add($btnRefreshWifi)

    $btnImportWifi = New-Object System.Windows.Forms.Button
    $btnImportWifi.Text = "Importar de Windows"
    $btnImportWifi.Location = New-Object System.Drawing.Point(515, 25)
    $btnImportWifi.Size = New-Object System.Drawing.Size(110, 28)
    $wifiPanel.Controls.Add($btnImportWifi)

    $global:WifiItems = @()

    $btnRefreshWifi.Add_Click({
        Write-Log "Actualizando lista de perfiles WiFi desde wifi-profiles/..." "DEBUG"
        $global:cmbWifi.Items.Clear()
        $global:WifiItems = Get-WifiProfileFiles
        foreach ($item in $global:WifiItems) { [void]$global:cmbWifi.Items.Add($item) }
        if ($global:cmbWifi.Items.Count -gt 0) { $global:cmbWifi.SelectedIndex = 0 }
        Update-UiStatus "Perfiles WiFi encontrados: $($global:cmbWifi.Items.Count)"
    })

    $btnConnectWifi.Add_Click({
        $sel = $global:cmbWifi.SelectedItem
        if (-not $sel) {
            [System.Windows.Forms.MessageBox]::Show("No hay un perfil seleccionado. Coloque archivos .xml en wifi-profiles/ o use 'Importar de Windows'.", "WiFi", "OK", "Warning") | Out-Null
            return
        }
        Update-UiStatus "Conectando al perfil '$($sel.Name)'..."
        $res = Connect-SavedWifiProfile -Path $sel.FullPath
        $icon = if ($res.Success) { "Information" } else { "Warning" }
        [System.Windows.Forms.MessageBox]::Show($res.Message, "WiFi", "OK", $icon) | Out-Null
        Update-UiStatus $res.Message
    })

    $btnImportWifi.Add_Click({
        $warn = [System.Windows.Forms.MessageBox]::Show(
            "Se exportaran los perfiles WiFi de Windows (INCLUIDAS las contrasenas en texto claro) a wifi-profiles/.`n`nGuarde esta carpeta en un medio seguro y elimine los perfiles cuando termine.`n`n¿Continuar?",
            "Importar perfiles WiFi",
            "YesNo",
            "Warning"
        )
        if ($warn -ne "Yes") { return }

        Update-UiStatus "Exportando perfiles WiFi..."
        $res = Import-SystemWifiProfiles
        [System.Windows.Forms.MessageBox]::Show($res.Message, "WiFi", "OK", "Information") | Out-Null
        $global:cmbWifi.Items.Clear()
        $global:WifiItems = Get-WifiProfileFiles
        foreach ($item in $global:WifiItems) { [void]$global:cmbWifi.Items.Add($item) }
        if ($global:cmbWifi.Items.Count -gt 0) { $global:cmbWifi.SelectedIndex = 0 }
        Update-UiStatus $res.Message
    })

    # ----- Panel de comandos del sistema (desplegable) -----
    $commandsPanel = New-Object System.Windows.Forms.Panel
    $commandsPanel.Location = New-Object System.Drawing.Point(350, 188)
    $commandsPanel.Size = New-Object System.Drawing.Size(640, 75)
    $commandsPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($commandsPanel)

    $lblCommands = New-Object System.Windows.Forms.Label
    $lblCommands.Text = "Comandos del sistema"
    $lblCommands.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblCommands.Location = New-Object System.Drawing.Point(10, 5)
    $lblCommands.Size = New-Object System.Drawing.Size(300, 18)
    $commandsPanel.Controls.Add($lblCommands)

    $global:cmbCommands = New-Object System.Windows.Forms.ComboBox
    $global:cmbCommands.Location = New-Object System.Drawing.Point(10, 26)
    $global:cmbCommands.Size = New-Object System.Drawing.Size(500, 25)
    $global:cmbCommands.DropDownStyle = "DropDownList"
    $global:cmbCommands.DisplayMember = "name"
    $commandsPanel.Controls.Add($global:cmbCommands)

    $btnRunCommand = New-Object System.Windows.Forms.Button
    $btnRunCommand.Text = "Ejecutar"
    $btnRunCommand.Location = New-Object System.Drawing.Point(520, 25)
    $btnRunCommand.Size = New-Object System.Drawing.Size(110, 28)
    $commandsPanel.Controls.Add($btnRunCommand)

    $global:CommandItems = @()

    $btnRunCommand.Add_Click({
        $sel = $global:cmbCommands.SelectedItem
        if (-not $sel) {
            [System.Windows.Forms.MessageBox]::Show("Seleccione un comando.", "Comandos", "OK", "Warning") | Out-Null
            return
        }
        Invoke-SystemCommand -Command $sel
        Update-UiStatus "Ejecutando: $($sel.name)"
    })

    # ----- Panel de herramientas automaticas -----
    $toolsPanel = New-Object System.Windows.Forms.Panel
    $toolsPanel.Location = New-Object System.Drawing.Point(350, 268)
    $toolsPanel.Size = New-Object System.Drawing.Size(640, 75)
    $toolsPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($toolsPanel)

    $lblTools = New-Object System.Windows.Forms.Label
    $lblTools.Text = "Herramientas automaticas"
    $lblTools.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblTools.Location = New-Object System.Drawing.Point(10, 5)
    $lblTools.Size = New-Object System.Drawing.Size(300, 18)
    $toolsPanel.Controls.Add($lblTools)

    $btnMfr = New-Object System.Windows.Forms.Button
    $btnMfr.Text = "Instalar app fabricante"
    $btnMfr.Location = New-Object System.Drawing.Point(10, 28)
    $btnMfr.Size = New-Object System.Drawing.Size(150, 30)
    $toolsPanel.Controls.Add($btnMfr)

    $btnWU = New-Object System.Windows.Forms.Button
    $btnWU.Text = "Windows Update"
    $btnWU.Location = New-Object System.Drawing.Point(165, 28)
    $btnWU.Size = New-Object System.Drawing.Size(150, 30)
    $toolsPanel.Controls.Add($btnWU)

    $btnWUDetail = New-Object System.Windows.Forms.Button
    $btnWUDetail.Text = "Ver actualizaciones"
    $btnWUDetail.Location = New-Object System.Drawing.Point(320, 28)
    $btnWUDetail.Size = New-Object System.Drawing.Size(150, 30)
    $toolsPanel.Controls.Add($btnWUDetail)

    $btnDiag = New-Object System.Windows.Forms.Button
    $btnDiag.Text = "Diagnosticos"
    $btnDiag.Location = New-Object System.Drawing.Point(475, 28)
    $btnDiag.Size = New-Object System.Drawing.Size(150, 30)
    $toolsPanel.Controls.Add($btnDiag)

    $btnMfr.Add_Click({
        $mfr = if ($global:SystemInfo) { $global:SystemInfo.Manufacturer } else { (Get-SystemInformation).Manufacturer }
        $plan = Get-ManufacturerInstallPlan -Manufacturer $mfr
        Write-Log ("Plan de fabricante: {0}" -f $plan.Message) "DEBUG"

        if ($plan.Supported) {
            $confirm = [System.Windows.Forms.MessageBox]::Show(
                "Se instalara:`n`n$($plan.Application)`nFabricante: $($plan.Manufacturer)`nID winget: $($plan.WingetId)`n`n¿Desea continuar?",
                "Confirmar instalacion",
                "YesNo",
                "Question"
            )
            if ($confirm -eq "Yes") {
                Start-ManufacturerInstall -WingetId $plan.WingetId -Name $plan.Application
            }
        }
        else {
            if ($plan.DownloadUrl) {
                $open = [System.Windows.Forms.MessageBox]::Show(
                    "$($plan.Message)`n`n¿Abrir la pagina de descargas del fabricante?",
                    "Aplicacion del fabricante",
                    "YesNo",
                    "Information"
                )
                if ($open -eq "Yes") { Open-CustomLink -Url $plan.DownloadUrl | Out-Null }
            }
            else {
                [System.Windows.Forms.MessageBox]::Show($plan.Message, "Aplicacion del fabricante", "OK", "Information") | Out-Null
            }
        }
    })

    $btnWU.Add_Click({ Invoke-AutoAction -Id "wu" })

    $btnWUDetail.Add_Click({ Show-UpdatesDialog })

    $btnDiag.Add_Click({
        foreach ($id in @("storage", "memory", "network", "hardware")) { Invoke-AutoAction -Id $id }
    })

    # ----- Panel de aplicaciones portatiles -----
    $appsPanel = New-Object System.Windows.Forms.Panel
    $appsPanel.Location = New-Object System.Drawing.Point(350, 348)
    $appsPanel.Size = New-Object System.Drawing.Size(640, 75)
    $appsPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($appsPanel)

    $lblApps = New-Object System.Windows.Forms.Label
    $lblApps.Text = "Aplicaciones de diagnostico (carpeta apps/)"
    $lblApps.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblApps.Location = New-Object System.Drawing.Point(10, 5)
    $lblApps.Size = New-Object System.Drawing.Size(610, 18)
    $appsPanel.Controls.Add($lblApps)

    $global:cmbApps = New-Object System.Windows.Forms.ComboBox
    $global:cmbApps.Location = New-Object System.Drawing.Point(10, 26)
    $global:cmbApps.Size = New-Object System.Drawing.Size(410, 25)
    $global:cmbApps.DropDownStyle = "DropDownList"
    $global:cmbApps.DisplayMember = "Name"
    $appsPanel.Controls.Add($global:cmbApps)

    $btnRunApp = New-Object System.Windows.Forms.Button
    $btnRunApp.Text = "Ejecutar"
    $btnRunApp.Location = New-Object System.Drawing.Point(425, 25)
    $btnRunApp.Size = New-Object System.Drawing.Size(90, 28)
    $appsPanel.Controls.Add($btnRunApp)

    $btnRefreshApps = New-Object System.Windows.Forms.Button
    $btnRefreshApps.Text = "Actualizar"
    $btnRefreshApps.Location = New-Object System.Drawing.Point(520, 25)
    $btnRefreshApps.Size = New-Object System.Drawing.Size(100, 28)
    $appsPanel.Controls.Add($btnRefreshApps)

    $global:AppItems = @()

    $btnRefreshApps.Add_Click({
        $global:cmbApps.Items.Clear()
        $global:AppItems = Get-DiagnosticApplications
        foreach ($app in $global:AppItems) { [void]$global:cmbApps.Items.Add($app) }
        if ($global:cmbApps.Items.Count -gt 0) { $global:cmbApps.SelectedIndex = 0 }
        Update-UiStatus "Aplicaciones detectadas: $($global:cmbApps.Items.Count)"
        Write-Log "Aplicaciones detectadas: $($global:cmbApps.Items.Count)" "INFO"
    })

    $btnRunApp.Add_Click({
        $sel = $global:cmbApps.SelectedItem
        if (-not $sel) {
            [System.Windows.Forms.MessageBox]::Show("No hay aplicaciones seleccionadas.", "Aplicaciones", "OK", "Warning") | Out-Null
            return
        }
        $ok = Invoke-DiagnosticApplication -Path $sel.RelativePath
        if (-not $ok) {
            [System.Windows.Forms.MessageBox]::Show("No fue posible ejecutar '$($sel.Name)'.", "Aplicaciones", "OK", "Warning") | Out-Null
        }
        else {
            Update-UiStatus "Ejecutando: $($sel.Name)"
        }
    })

    # ----- Panel de Drivers -----
    $driversPanel = New-Object System.Windows.Forms.Panel
    $driversPanel.Location = New-Object System.Drawing.Point(350, 428)
    $driversPanel.Size = New-Object System.Drawing.Size(640, 77)
    $driversPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($driversPanel)

    $lblDrivers = New-Object System.Windows.Forms.Label
    $lblDrivers.Text = "Drivers (carpeta Drivers/)"
    $lblDrivers.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lblDrivers.Location = New-Object System.Drawing.Point(10, 5)
    $lblDrivers.Size = New-Object System.Drawing.Size(400, 18)
    $driversPanel.Controls.Add($lblDrivers)

    $global:cmbDrivers = New-Object System.Windows.Forms.ComboBox
    $global:cmbDrivers.Location = New-Object System.Drawing.Point(10, 27)
    $global:cmbDrivers.Size = New-Object System.Drawing.Size(320, 25)
    $global:cmbDrivers.DropDownStyle = "DropDownList"
    $global:cmbDrivers.DisplayMember = "Name"
    $driversPanel.Controls.Add($global:cmbDrivers)

    $btnExportDrivers = New-Object System.Windows.Forms.Button
    $btnExportDrivers.Text = "Exportar drivers"
    $btnExportDrivers.Location = New-Object System.Drawing.Point(335, 26)
    $btnExportDrivers.Size = New-Object System.Drawing.Size(105, 28)
    $driversPanel.Controls.Add($btnExportDrivers)

    $btnInstallDrivers = New-Object System.Windows.Forms.Button
    $btnInstallDrivers.Text = "Instalar drivers"
    $btnInstallDrivers.Location = New-Object System.Drawing.Point(445, 26)
    $btnInstallDrivers.Size = New-Object System.Drawing.Size(100, 28)
    $driversPanel.Controls.Add($btnInstallDrivers)

    $btnRefreshDrivers = New-Object System.Windows.Forms.Button
    $btnRefreshDrivers.Text = "Actualizar"
    $btnRefreshDrivers.Location = New-Object System.Drawing.Point(550, 26)
    $btnRefreshDrivers.Size = New-Object System.Drawing.Size(80, 28)
    $driversPanel.Controls.Add($btnRefreshDrivers)

    $global:DriverItems = @()

    $btnRefreshDrivers.Add_Click({
        Write-Log "Actualizando lista de carpetas de Drivers/..." "DEBUG"
        Refresh-DriverFoldersUi
        Update-UiStatus "Carpetas de drivers encontradas: $($global:cmbDrivers.Items.Count)"
    })

    $btnExportDrivers.Add_Click({
        $default = "drivers_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss")
        $name = Show-InputDialog -Title "Exportar drivers" -Prompt "Nombre de la carpeta para guardar los drivers:" -DefaultValue $default
        if ([string]::IsNullOrWhiteSpace($name)) { return }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Se exportaran los drivers del equipo a:`nDrivers\$name`n`nEsto puede tardar varios minutos. ¿Continuar?",
            "Exportar drivers",
            "YesNo",
            "Question"
        )
        if ($confirm -ne "Yes") { return }

        Start-ActivityJob -Name ("Exportar drivers: {0}" -f $name) -ScriptBlock $script:DriversJobScript -ArgumentList @($global:ProjectRoot, "export", $name) -OnComplete $script:OnDriverComplete | Out-Null
    })

    $btnInstallDrivers.Add_Click({
        $sel = $global:cmbDrivers.SelectedItem
        if (-not $sel) {
            [System.Windows.Forms.MessageBox]::Show("No hay carpetas de drivers. Exporte o coloque controladores en Drivers/.", "Drivers", "OK", "Warning") | Out-Null
            return
        }

        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Se instalaran los drivers desde:`nDrivers\$($sel.Name)`n`nMediante: pnputil /add-driver ... /subdirs /install`n`n¿Esta seguro?",
            "Instalar drivers",
            "YesNo",
            "Question"
        )
        if ($confirm -ne "Yes") { return }

        Start-ActivityJob -Name ("Instalar drivers: {0}" -f $sel.Name) -ScriptBlock $script:DriversJobScript -ArgumentList @($global:ProjectRoot, "install", $sel.FullPath) -OnComplete $script:OnDriverComplete | Out-Null
    })

    # ----- Panel de enlaces -----
    $linksGroup = New-Object System.Windows.Forms.GroupBox
    $linksGroup.Text = "Enlaces personalizados"
    $linksGroup.Location = New-Object System.Drawing.Point(10, 510)
    $linksGroup.Size = New-Object System.Drawing.Size(980, 46)
    $form.Controls.Add($linksGroup)

    $global:linksFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $global:linksFlow.Location = New-Object System.Drawing.Point(8, 15)
    $global:linksFlow.Size = New-Object System.Drawing.Size(964, 26)
    $global:linksFlow.AutoScroll = $true
    $global:linksFlow.WrapContents = $false
    $linksGroup.Controls.Add($global:linksFlow)

    # ----- Ventana de actividad en vivo -----
    $activityGroup = New-Object System.Windows.Forms.GroupBox
    $activityGroup.Text = "Actividad (todo lo que se esta haciendo)"
    $activityGroup.Location = New-Object System.Drawing.Point(10, 561)
    $activityGroup.Size = New-Object System.Drawing.Size(980, 190)
    $form.Controls.Add($activityGroup)

    $global:chkVerbose = New-Object System.Windows.Forms.CheckBox
    $global:chkVerbose.Text = "Modo detallado (DEBUG)"
    $global:chkVerbose.Checked = $global:ActivityVerbose
    $global:chkVerbose.Location = New-Object System.Drawing.Point(760, 15)
    $global:chkVerbose.Size = New-Object System.Drawing.Size(210, 20)
    $global:chkVerbose.Add_CheckedChanged({
        $global:ActivityVerbose = $global:chkVerbose.Checked
        Write-Log ("Modo detallado: {0}" -f $global:ActivityVerbose) "DEBUG"
    })
    $activityGroup.Controls.Add($global:chkVerbose)

    $global:ActivityBox = New-Object System.Windows.Forms.TextBox
    $global:ActivityBox.Location = New-Object System.Drawing.Point(8, 36)
    $global:ActivityBox.Size = New-Object System.Drawing.Size(964, 146)
    $global:ActivityBox.Multiline = $true
    $global:ActivityBox.ReadOnly = $true
    $global:ActivityBox.ScrollBars = "Both"
    $global:ActivityBox.WordWrap = $false
    $global:ActivityBox.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 17)
    $global:ActivityBox.ForeColor = [System.Drawing.Color]::Gainsboro
    $global:ActivityBox.Font = New-Object System.Drawing.Font("Consolas", 8.25)
    $activityGroup.Controls.Add($global:ActivityBox)

    # ----- Panel de progreso -----
    $progressPanel = New-Object System.Windows.Forms.Panel
    $progressPanel.Location = New-Object System.Drawing.Point(10, 756)
    $progressPanel.Size = New-Object System.Drawing.Size(980, 38)
    $progressPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($progressPanel)

    $global:lblStatus = New-Object System.Windows.Forms.Label
    $global:lblStatus.Text = "Estado: Esperando..."
    $global:lblStatus.Location = New-Object System.Drawing.Point(10, 2)
    $global:lblStatus.Size = New-Object System.Drawing.Size(960, 16)
    $progressPanel.Controls.Add($global:lblStatus)

    $global:progressBar = New-Object System.Windows.Forms.ProgressBar
    $global:progressBar.Location = New-Object System.Drawing.Point(10, 18)
    $global:progressBar.Size = New-Object System.Drawing.Size(960, 14)
    $progressPanel.Controls.Add($global:progressBar)

    # ----- Botones de acción -----
    $btnRunAll = New-Object System.Windows.Forms.Button
    $btnRunAll.Text = "Ejecutar todo"
    $btnRunAll.Location = New-Object System.Drawing.Point(10, 799)
    $btnRunAll.Size = New-Object System.Drawing.Size(190, 30)
    $form.Controls.Add($btnRunAll)

    $btnReset = New-Object System.Windows.Forms.Button
    $btnReset.Text = "Reiniciar"
    $btnReset.Location = New-Object System.Drawing.Point(205, 799)
    $btnReset.Size = New-Object System.Drawing.Size(190, 30)
    $form.Controls.Add($btnReset)

    $btnClearActivity = New-Object System.Windows.Forms.Button
    $btnClearActivity.Text = "Limpiar actividad"
    $btnClearActivity.Location = New-Object System.Drawing.Point(400, 799)
    $btnClearActivity.Size = New-Object System.Drawing.Size(190, 30)
    $form.Controls.Add($btnClearActivity)

    $btnReport = New-Object System.Windows.Forms.Button
    $btnReport.Text = "Generar reporte"
    $btnReport.Location = New-Object System.Drawing.Point(595, 799)
    $btnReport.Size = New-Object System.Drawing.Size(190, 30)
    $form.Controls.Add($btnReport)

    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text = "Salir"
    $btnExit.Location = New-Object System.Drawing.Point(790, 799)
    $btnExit.Size = New-Object System.Drawing.Size(190, 30)
    $form.Controls.Add($btnExit)

    $btnRunAll.Add_Click({ Invoke-AllAutoActions })

    $btnReset.Add_Click({
        $global:ManualChecklist = Initialize-Checklist
        $global:AutoResults = Initialize-AutoResults
        foreach ($chk in $global:checkboxes) { $chk.Checked = $false }
        Refresh-ChecklistUi
        Set-Progress -Percent 0
        Update-UiStatus "Estado: Esperando..."
        Write-Log "Checklist y resultados reiniciados." "INFO"
    })

    $btnClearActivity.Add_Click({
        if ($global:ActivityBox) { $global:ActivityBox.Clear() }
    })

    $btnReport.Add_Click({
        try {
            $info = Get-SystemInformation
            Update-SystemInfoLabels -Info $info

            $fileName = "Report-{0}.html" -f (Get-Date -Format "yyyy-MM-dd-HH-mm-ss")
            $reportPath = Join-Path (Join-Path $global:ProjectRoot "reports") $fileName
            $autoForReport = @($global:AutoResults.Values)

            New-DiagnosticReport -SystemInfo $info -Checklist $global:ManualChecklist -OutputPath $reportPath -AutoResults $autoForReport -WindowsUpdates $global:WindowsUpdateItems
            [System.Windows.Forms.MessageBox]::Show("Reporte generado:`n$reportPath", "Reporte", "OK", "Information") | Out-Null
            Update-UiStatus "Reporte generado: $fileName"
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Error generando reporte:`n$_", "Reporte", "OK", "Error") | Out-Null
        }
    })

    $btnExit.Add_Click({ $form.Close() })

    # ----- Temporizador para leer la salida de los jobs -----
    $global:JobTimer = New-Object System.Windows.Forms.Timer
    $global:JobTimer.Interval = 500
    $global:JobTimer.Add_Tick({ Update-ActivityJobs })

    $form.Add_FormClosing({
        try { if ($global:JobTimer) { $global:JobTimer.Stop() } } catch { }
        foreach ($rec in $script:ActiveJobs) {
            Stop-Job -Job $rec.Job -ErrorAction SilentlyContinue
            Remove-Job -Job $rec.Job -Force -ErrorAction SilentlyContinue
        }
        $script:ActiveJobs = @()
        Write-Log "Aplicacion cerrada por el usuario." "INFO"
    })

    # ----- Cargar datos iniciales -----
    $form.Add_Shown({
        Write-Log ("Entorno: PS={0}; OS={1}; Admin={2}; Usuario={3}" -f $PSVersionTable.PSVersion, [System.Environment]::OSVersion.VersionString, (Test-Administrator), $env:USERNAME) "DEBUG"
        Update-UiStatus "Recolectando informacion del sistema..."
        $info = Get-SystemInformation
        Update-SystemInfoLabels -Info $info
        Set-AutoResult -Id "inventory" -Status "Passed" -Result ("Equipo: {0} {1}" -f $info.Manufacturer, $info.Model)
        Update-OverallProgress

        # Enlaces
        $global:linksFlow.Controls.Clear()
        foreach ($link in (Get-CustomLinks)) {
            $b = New-Object System.Windows.Forms.Button
            $b.Text = "$($link.name)"
            $b.AutoSize = $true
            $b.BackColor = [System.Drawing.Color]::FromArgb(62, 62, 66)
            $b.ForeColor = [System.Drawing.Color]::Gainsboro
            $b.FlatStyle = "Flat"
            $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(90, 90, 94)
            $url = "$($link.url)"
            $handler = { param($sender, $eventArgs) Open-CustomLink -Url $url | Out-Null }.GetNewClosure()
            $b.Add_Click($handler)
            [void]$global:linksFlow.Controls.Add($b)
        }

        # Comandos del sistema
        $global:cmbCommands.Items.Clear()
        $global:CommandItems = Get-SystemCommands
        foreach ($cmd in $global:CommandItems) { [void]$global:cmbCommands.Items.Add($cmd) }
        if ($global:cmbCommands.Items.Count -gt 0) { $global:cmbCommands.SelectedIndex = 0 }

        # Perfiles WiFi guardados
        $global:cmbWifi.Items.Clear()
        $global:WifiItems = Get-WifiProfileFiles
        foreach ($item in $global:WifiItems) { [void]$global:cmbWifi.Items.Add($item) }
        if ($global:cmbWifi.Items.Count -gt 0) { $global:cmbWifi.SelectedIndex = 0 }

        # Aplicaciones portatiles
        $global:cmbApps.Items.Clear()
        $global:AppItems = Get-DiagnosticApplications
        foreach ($app in $global:AppItems) { [void]$global:cmbApps.Items.Add($app) }
        if ($global:cmbApps.Items.Count -gt 0) { $global:cmbApps.SelectedIndex = 0 }

        # Carpetas de drivers
        Refresh-DriverFoldersUi

        Write-Log ("Perfiles WiFi: {0}; comandos: {1}; apps: {2}; drivers: {3}" -f $global:WifiItems.Count, $global:CommandItems.Count, $global:AppItems.Count, $global:DriverItems.Count) "DEBUG"
        Update-UiStatus "Listo. Use 'Ejecutar todo' y marque el checklist manual."
    })

    # ----- Tema oscuro -----
    Apply-DarkTheme -Control $form
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $global:ActivityBox.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 17)
    $global:ActivityBox.ForeColor = [System.Drawing.Color]::Gainsboro
    $global:ActivityBox.Font = New-Object System.Drawing.Font("Consolas", 8.25)

    return $form
}

Export-ModuleMember -Function New-MainForm, Invoke-AllAutoActions, Invoke-AutoAction, Update-ActivityJobs, Add-Activity, Invoke-SystemCommand
