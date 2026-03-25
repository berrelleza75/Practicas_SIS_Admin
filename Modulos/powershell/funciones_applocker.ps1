# funciones_applocker.ps1
# Reglas de ejecucion por grupo usando GPO y AppLocker

$dcPath     = "DC=practica8,DC=local"
$notepadPath = "$env:SystemRoot\System32\notepad.exe"

function Get-HashNotepad {
    $info = Get-AppLockerFileInformation -Path $notepadPath
    return $info.Hash.HashDataString
}

function New-GPOAppLocker {
    param([string]$nombreGPO)

    if (-not (Get-GPO -Name $nombreGPO -ErrorAction SilentlyContinue)) {
        New-GPO -Name $nombreGPO | Out-Null
        Write-Host "GPO $nombreGPO creada"
    } else {
        Write-Host "GPO $nombreGPO ya existe"
    }
}

function Set-ReglaPermitirNotepad {
    $xml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FilePathRule Id="$(New-Guid)" Name="Denegar todo NoCuates" Description="Bloquea todo a NoCuates" UserOrGroupSid="$(Get-ADGroup NoCuates | Select-Object -ExpandProperty SID)" Action="Deny">
      <Conditions>
        <FilePathCondition Path="*\*" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="$(New-Guid)" Name="Permitir Notepad Cuates" Description="Permite notepad a Cuates" UserOrGroupSid="$(Get-ADGroup Cuates | Select-Object -ExpandProperty SID)" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%SYSTEM32%\notepad.exe" />
      </Conditions>
    </FilePathRule>
    <FilePathRule Id="$(New-Guid)" Name="Permitir Admins" Description="Admins sin restriccion" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
"@
    return $xml
}
function Set-ReglaBloquearNotepadHash {
    # NoCuates tienen bloqueado notepad por hash (resiste renombrado)
    $hash     = Get-HashNotepad
    $fileHash = Get-AppLockerFileInformation -Path $notepadPath

    $xml = @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">
    <FileHashRule Id="$(New-Guid)" Name="Bloquear Notepad NoCuates por Hash" Description="Bloqueo por hash resiste renombrado" UserOrGroupSid="$(Get-ADGroup NoCuates | Select-Object -ExpandProperty SID)" Action="Deny">
      <Conditions>
        <FileHashCondition>
          <FileHash Type="SHA256" Data="$hash" SourceFileName="notepad.exe" SourceFileLength="$($fileHash.Hash.SourceFileLength)" />
        </FileHashCondition>
      </Conditions>
    </FileHashRule>
    <FilePathRule Id="$(New-Guid)" Name="Permitir Admins" Description="Admins sin restriccion" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*" />
      </Conditions>
    </FilePathRule>
  </RuleCollection>
</AppLockerPolicy>
"@
    return $xml
}

function Invoke-ConfigurarAppLocker {
    Write-Host ""
    Write-Host "--- Configuracion de AppLocker ---"

    # Verificar que el servicio AppIDSvc este activo
    $svc = Get-Service -Name AppIDSvc -ErrorAction SilentlyContinue
    if ($null -eq $svc) {
        Write-Host "El servicio AppIDSvc no se encontro, verifica que AppLocker este disponible"
        return
    }
    if ($svc.Status -ne "Running") {
        sc.exe config AppIDSvc start= auto | Out-Null
        Start-Service -Name AppIDSvc
        Write-Host "Servicio AppIDSvc iniciado"
    }

    # GPO para Cuates
    $gpoCuates = "AppLocker-Cuates"
    New-GPOAppLocker -nombreGPO $gpoCuates

    $xmlCuates = Set-ReglaPermitirNotepad
    $tempCuates = "$env:TEMP\applocker_cuates.xml"
    $xmlCuates | Out-File -FilePath $tempCuates -Encoding UTF8

    Set-AppLockerPolicy -XmlPolicy $tempCuates -Merge
    New-GPLink -Name $gpoCuates -Target "OU=Cuates,$dcPath" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Regla Allow Notepad aplicada a Cuates"

    # GPO para NoCuates
    $gpoNoCuates = "AppLocker-NoCuates"
    New-GPOAppLocker -nombreGPO $gpoNoCuates

    $xmlNoCuates = Set-ReglaBloquearNotepadHash
    $tempNoCuates = "$env:TEMP\applocker_nocuates.xml"
    $xmlNoCuates | Out-File -FilePath $tempNoCuates -Encoding UTF8

    Set-AppLockerPolicy -XmlPolicy $tempNoCuates -Merge
    New-GPLink -Name $gpoNoCuates -Target "OU=NoCuates,$dcPath" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "Regla Deny Notepad por Hash aplicada a NoCuates"

    # Limpiar temporales
    Remove-Item $tempCuates, $tempNoCuates -ErrorAction SilentlyContinue

    Write-Host "Configuracion de AppLocker completada"
}