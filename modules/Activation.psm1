# ============================================
# Activation.psm1 - Activación de Windows
# ============================================
# Intenta activar Windows usando la clave digital OEM del equipo
# (OA3xOriginalProductKey) mediante slmgr.
#
# Nota: Microsoft esta retirando VBScript de Windows. Si en el futuro
# slmgr.vbs deja de funcionar, se usara slmgr.exe en su lugar (si existe)
# o habra que actualizar este modulo.

function Get-WindowsOemKey {
    [CmdletBinding()]
    param()

    try {
        return (Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop).OA3xOriginalProductKey
    }
    catch {
        Write-Log "No se pudo consultar SoftwareLicensingService: $_" "WARNING"
        return $null
    }
}

function Invoke-SlmgrCommand {
    param([string[]]$Arguments)

    $slmgrExe = Join-Path $env:SystemRoot "System32\slmgr.exe"
    $slmgrVbs = Join-Path $env:SystemRoot "System32\slmgr.vbs"

    if (Test-Path -LiteralPath $slmgrExe) {
        return (& $slmgrExe @Arguments 2>&1 | Out-String)
    }
    if (Test-Path -LiteralPath $slmgrVbs) {
        return (& cscript.exe //nologo $slmgrVbs @Arguments 2>&1 | Out-String)
    }
    throw "No se encontro slmgr.exe ni slmgr.vbs en el sistema."
}

function Write-SlmgrOutput {
    param([string]$Text)

    foreach ($line in ($Text -split "`r?`n")) {
        if ($line.Trim()) { Write-Output ("  " + $line.Trim()) }
    }
}

function Invoke-WindowsActivation {
    [CmdletBinding()]
    param()

    Write-Output "Verificando clave digital de Windows..."

    $key = Get-WindowsOemKey
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Output "No se encontro clave digital OEM (OA3xOriginalProductKey) en este equipo."
        Write-Log "Activacion: no se encontro clave digital OEM." "WARNING"
        Write-Output ("@@ACTIVATION@@NOKEY")
        return
    }

    # Mostrar la clave enmascarada (no registrar la clave completa)
    $masked = if ($key.Length -gt 10) {
        $key.Substring(0, 5) + "-*****-*****-*****-" + $key.Substring($key.Length - 5)
    }
    else { "*****" }

    Write-Output ("Clave digital OEM detectada: {0}" -f $masked)
    Write-Log ("Activacion: clave digital OEM detectada ({0})" -f $masked) "INFO"

    try {
        Write-Output "Instalando clave de producto (slmgr /ipk)..."
        Write-SlmgrOutput (Invoke-SlmgrCommand -Arguments @("/ipk", $key))

        Write-Output "Activando en linea (slmgr /ato)..."
        Write-SlmgrOutput (Invoke-SlmgrCommand -Arguments @("/ato"))

        Write-Output "Estado de activacion (slmgr /xpr):"
        Write-SlmgrOutput (Invoke-SlmgrCommand -Arguments @("/xpr"))

        Write-Log "Activacion de Windows finalizada." "INFO"
        Write-Output ("@@ACTIVATION@@OK")
    }
    catch {
        Write-Output ("Error al activar Windows: {0}" -f $_)
        Write-Log ("Error al activar Windows: {0}" -f $_) "ERROR"
        Write-Output ("@@ACTIVATION@@ERROR")
    }
}

Export-ModuleMember -Function Invoke-WindowsActivation, Get-WindowsOemKey
