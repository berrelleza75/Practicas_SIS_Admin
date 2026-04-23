function Invoke-CrearFGPP {
    $dominio = (Get-ADDomain).DistinguishedName

    Write-Host "Configurando Fine-Grained Password Policies..." -ForegroundColor Cyan

    # --- Grupos de seguridad para aplicar las FGPP ---
    # FGPP se aplica a grupos o usuarios, no a OUs. Creamos 2 grupos.

    $grupoAdmins   = "FGPP_Admins"
    $grupoUsuarios = "FGPP_Usuarios"

    foreach ($grupo in @($grupoAdmins, $grupoUsuarios)) {
        if (-not (Get-ADGroup -Filter "Name -eq '$grupo'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $grupo -GroupScope Global -GroupCategory Security -Path $dominio
            Write-Host "Grupo creado: $grupo" -ForegroundColor Green
        } else {
            Write-Host "Grupo ya existe: $grupo" -ForegroundColor Yellow
        }
    }

    # --- Meter a los 4 admins delegados en FGPP_Admins ---
    $admins = @("admin_identidad","admin_storage","admin_politicas","admin_auditoria")
    foreach ($u in $admins) {
        Add-ADGroupMember -Identity $grupoAdmins -Members $u -ErrorAction SilentlyContinue
    }
    Write-Host "Admins delegados agregados a $grupoAdmins" -ForegroundColor Green

    # --- Meter a los usuarios de Cuates y NoCuates en FGPP_Usuarios ---
    $usuariosNormales = Get-ADUser -Filter * -SearchBase "OU=Cuates,$dominio"
    $usuariosNormales += Get-ADUser -Filter * -SearchBase "OU=NoCuates,$dominio"
    foreach ($u in $usuariosNormales) {
        Add-ADGroupMember -Identity $grupoUsuarios -Members $u.SamAccountName -ErrorAction SilentlyContinue
    }
    Write-Host "Usuarios normales agregados a $grupoUsuarios" -ForegroundColor Green

    # --- FGPP para Admins: 12 caracteres, complejidad ON ---
    if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'FGPP_Admins_Policy'" -ErrorAction SilentlyContinue)) {
        New-ADFineGrainedPasswordPolicy `
            -Name "FGPP_Admins_Policy" `
            -Precedence 10 `
            -MinPasswordLength 12 `
            -ComplexityEnabled $true `
            -PasswordHistoryCount 5 `
            -MinPasswordAge "1.00:00:00" `
            -MaxPasswordAge "60.00:00:00" `
            -LockoutThreshold 5 `
            -LockoutDuration "0.00:30:00" `
            -LockoutObservationWindow "0.00:30:00"
        Write-Host "FGPP_Admins_Policy creada (12 chars)" -ForegroundColor Green
    } else {
        Write-Host "FGPP_Admins_Policy ya existe" -ForegroundColor Yellow
    }
    Add-ADFineGrainedPasswordPolicySubject -Identity "FGPP_Admins_Policy" -Subjects $grupoAdmins

    # --- FGPP para Usuarios: 8 caracteres ---
    if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'FGPP_Usuarios_Policy'" -ErrorAction SilentlyContinue)) {
        New-ADFineGrainedPasswordPolicy `
            -Name "FGPP_Usuarios_Policy" `
            -Precedence 20 `
            -MinPasswordLength 8 `
            -ComplexityEnabled $true `
            -PasswordHistoryCount 3 `
            -MinPasswordAge "1.00:00:00" `
            -MaxPasswordAge "90.00:00:00" `
            -LockoutThreshold 5 `
            -LockoutDuration "0.00:15:00" `
            -LockoutObservationWindow "0.00:15:00"
        Write-Host "FGPP_Usuarios_Policy creada (8 chars)" -ForegroundColor Green
    } else {
        Write-Host "FGPP_Usuarios_Policy ya existe" -ForegroundColor Yellow
    }
    Add-ADFineGrainedPasswordPolicySubject -Identity "FGPP_Usuarios_Policy" -Subjects $grupoUsuarios

    Write-Host "`nFGPP configuradas correctamente." -ForegroundColor Cyan
}

