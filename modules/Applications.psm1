# ============================================
# Applications.psm1 - Aplicaciones de diagnóstico (carpeta apps/)
# ============================================
# Detecta ejecutables (.exe), scripts de lote (.bat) y .cmd dentro de apps/.

# Elige el mejor lanzable de una carpeta: primero .exe, luego .bat, luego .cmd.
# Busca en el nivel superior y, si no hay, hasta 3 niveles de profundidad.
function Get-AppLaunchCandidate {
    param([string]$Folder)

    $priority = @("*.exe", "*.bat", "*.cmd")

    foreach ($pattern in $priority) {
        $file = Get-ChildItem -LiteralPath $Folder -Filter $pattern -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($file) { return $file }
    }

    foreach ($pattern in $priority) {
        $file = Get-ChildItem -LiteralPath $Folder -Filter $pattern -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($file) { return $file }
    }

    return $null
}

function Get-DiagnosticApplications {
    [CmdletBinding()]
    param()

    $appsDir = Join-Path $global:ProjectRoot "apps"

    if (-not (Test-Path -LiteralPath $appsDir)) {
        return @()
    }

    $results = New-Object System.Collections.ArrayList

    foreach ($dir in (Get-ChildItem -LiteralPath $appsDir -Directory)) {
        $file = Get-AppLaunchCandidate -Folder $dir.FullName

        if ($file) {
            $relative = $file.FullName
            $root = $global:ProjectRoot
            if ($relative.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relative = $relative.Substring($root.Length).TrimStart('\', '/')
            }

            [void]$results.Add([PSCustomObject]@{
                Name         = $dir.Name
                RelativePath = $relative
                FullPath     = $file.FullName
                Extension    = $file.Extension.ToLower()
            })
        }
    }

    return @($results | Sort-Object Name)
}

Export-ModuleMember -Function Get-DiagnosticApplications
