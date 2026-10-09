# ============================================
# Verificacion manual del tecnico
# ============================================
# Las tareas automaticas (Windows Update, fabricante, diagnosticos, inventario)
# se ejecutan desde sus botones y NO forman parte de este checklist, para evitar
# redundancia. Aqui solo van las comprobaciones manuales del tecnico.

function Initialize-Checklist {
    [CmdletBinding()]
    param()

    $tasks = @(
        @{ Id = 1;  Name = "Pantalla";                  Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 2;  Name = "Teclado";                   Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 3;  Name = "Touchpad";                  Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 4;  Name = "Camara";                    Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 5;  Name = "Microfono";                 Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 6;  Name = "Altavoces / audio";         Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 7;  Name = "Puertos USB";               Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 8;  Name = "Wi-Fi";                     Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 9;  Name = "Bluetooth";                 Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 10; Name = "Bateria / alimentacion";    Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 11; Name = "Estado fisico general";     Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" },
        @{ Id = 12; Name = "Revision final";            Category = "Manual"; Status = "Pending"; Result = ""; Notes = ""; Timestamp = "" }
    )

    return $tasks
}

Export-ModuleMember -Function Initialize-Checklist
