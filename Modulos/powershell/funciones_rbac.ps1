# funciones_rbac.ps1

function Invoke-CrearAdminsDelegados {
    $csvPath = "$PSScriptRoot\..\..\Practica 9\admins_delegados.csv"

    if (-not (Test-Path $csvPath)) {
        Write-Host "No se encontro el CSV en: $csvPath" -ForegroundColor Red
        return
    }

    $admins = Import-Csv $csvPath
    # OU donde van a vivir los admins delegados
    $ouAdmins = "OU=AdminsDelegados,$((Get-ADDomain).DistinguishedName)"

    # Si la OU no existe, la creamos
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouAdmins'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name "AdminsDelegados" -Path (Get-ADDomain).DistinguishedName
        Write-Host "OU 'AdminsDelegados' creada." -ForegroundColor Green
    }

    foreach ($admin in $admins) {
        if (Get-ADUser -Filter "SamAccountName -eq '$($admin.Usuario)'" -ErrorAction SilentlyContinue) {
            Write-Host "Usuario $($admin.Usuario) ya existe, se omite." -ForegroundColor Yellow
            continue
        }

        $securePass = ConvertTo-SecureString $admin.Password -AsPlainText -Force

        New-ADUser `
            -Name $admin.NombreCompleto `
            -SamAccountName $admin.Usuario `
            -UserPrincipalName "$($admin.Usuario)@$((Get-ADDomain).DNSRoot)" `
            -AccountPassword $securePass `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -Path $ouAdmins `
            -Description "Rol: $($admin.Rol)"

        Write-Host "Creado: $($admin.Usuario) (Rol: $($admin.Rol))" -ForegroundColor Green
    }
}

function Invoke-AplicarACLsDelegacion {
    $dominio = (Get-ADDomain).DistinguishedName
    $ouCuates   = "OU=Cuates,$dominio"
    $ouNoCuates = "OU=NoCuates,$dominio"

    Write-Host "Aplicando ACLs de delegacion..." -ForegroundColor Cyan

    # --- ROL 1: admin_identidad ---
    # Control total sobre objetos User en Cuates y NoCuates
    Write-Host "`n[Rol 1] admin_identidad -> gestion de usuarios" -ForegroundColor Yellow
    dsacls $ouCuates   /I:S /G "admin_identidad:GA;;user" | Out-Null
    dsacls $ouNoCuates /I:S /G "admin_identidad:GA;;user" | Out-Null
    # Permitir crear y borrar objetos user en la OU
    dsacls $ouCuates   /I:T /G "admin_identidad:CCDC;user" | Out-Null
    dsacls $ouNoCuates /I:T /G "admin_identidad:CCDC;user" | Out-Null
    Write-Host "  OK - permisos aplicados en Cuates y NoCuates" -ForegroundColor Green

    # --- ROL 2: admin_storage ---
    # DENY explicito sobre Reset Password (requisito critico de la rubrica)
    Write-Host "`n[Rol 2] admin_storage -> DENY Reset Password" -ForegroundColor Yellow
    dsacls $ouCuates   /I:S /D "admin_storage:CA;Reset Password;user" | Out-Null
    dsacls $ouNoCuates /I:S /D "admin_storage:CA;Reset Password;user" | Out-Null
    Write-Host "  OK - reset password denegado explicitamente" -ForegroundColor Green

    # --- ROL 3: admin_politicas ---
    # Lectura en todo el dominio
    Write-Host "`n[Rol 3] admin_politicas -> lectura dominio + escritura GPOs" -ForegroundColor Yellow
    dsacls $dominio /I:S /G "admin_politicas:GR" | Out-Null
    # Escritura sobre objetos groupPolicyContainer
    $gpoContainer = "CN=Policies,CN=System,$dominio"
    dsacls $gpoContainer /I:S /G "admin_politicas:GA;;groupPolicyContainer" | Out-Null
    Write-Host "  OK - lectura global + escritura sobre GPOs" -ForegroundColor Green

    # --- ROL 4: admin_auditoria ---
    # Solo lectura en todo el dominio (Read-Only estricto)
    Write-Host "`n[Rol 4] admin_auditoria -> lectura estricta" -ForegroundColor Yellow
    dsacls $dominio /I:S /G "admin_auditoria:GR" | Out-Null
    Write-Host "  OK - lectura global aplicada" -ForegroundColor Green

    Write-Host "`nDelegacion completa." -ForegroundColor Cyan
}

function Invoke-VerificarDelegacion {
    $dominio    = (Get-ADDomain).DistinguishedName
    $ouCuates   = "OU=Cuates,$dominio"
    $ouNoCuates = "OU=NoCuates,$dominio"

    Write-Host "Verificando ACLs aplicadas..." -ForegroundColor Cyan
    Write-Host ""

    $admins = @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")

    foreach ($admin in $admins) {
        Write-Host "=============================================" -ForegroundColor Yellow
        Write-Host " Permisos de: $admin" -ForegroundColor Yellow
        Write-Host "=============================================" -ForegroundColor Yellow

        # Revisar ACLs en OU Cuates
        Write-Host "`n-- En OU=Cuates --" -ForegroundColor Cyan
        dsacls $ouCuates | Select-String -Pattern $admin

        # Revisar ACLs en OU NoCuates
        Write-Host "`n-- En OU=NoCuates --" -ForegroundColor Cyan
        dsacls $ouNoCuates | Select-String -Pattern $admin

        Write-Host ""
    }

    Write-Host "Verificacion completa." -ForegroundColor Green
}