# ============================================
# Aplicaciones de diagnóstico (carpeta apps/)
# ============================================

function Get-DiagnosticApplications {
    [CmdletBinding()]
    param()

    $appsDir = Join-Path $global:ProjectRoot "apps"

    if (-not (Test-Path -LiteralPath $appsDir)) {
        return @()
    }

    $results = New-Object System.Collections.ArrayList

    foreach ($dir in (Get-ChildItem -LiteralPath $appsDir -Directory)) {
        # Buscar primero un ejecutable en el nivel superior; si no, recursivo (hasta 3 niveles)
        $exe = Get-ChildItem -LiteralPath $dir.FullName -Filter "*.exe" -File -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if (-not $exe) {
            $exe = Get-ChildItem -LiteralPath $dir.FullName -Filter "*.exe" -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
                Select-Object -First 1
        }

        if ($exe) {
            $relative = $exe.FullName
            $root = $global:ProjectRoot
            if ($relative.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relative = $relative.Substring($root.Length).TrimStart('\', '/')
            }

            [void]$results.Add([PSCustomObject]@{
                Name         = $dir.Name
                RelativePath = $relative
                FullPath     = $exe.FullName
            })
        }
    }

    return @($results | Sort-Object Name)
}

Export-ModuleMember -Function Get-DiagnosticApplications
