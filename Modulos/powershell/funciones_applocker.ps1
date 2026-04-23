# funciones_applocker.ps1
# Reglas de ejecucion por grupo usando GPO y AppLocker

$dcPath      = "DC=practica8,DC=local"
$dominio     = "practica8.local"

# Hash de notepad.exe del cliente Windows 10 22H2 (19045.3803)
# Formato correcto: 0x en minusculas
$notepadHash       = "0xa5fb2a35f78c2fbcb1f1329ff1c8123a5b9cff95653c15381339599251d6d26d"
$notepadFileLength = 201216

function New-GPOAppLocker {
    param([string]$nombreGPO)

    if (-not (Get-GPO -Name $nombreGPO -ErrorAction SilentlyContinue)) {
        New-GPO -Name $nombreGPO | Out-Null
        Write-Host "GPO $nombreGPO creada"
    } else {
        Write-Host "GPO $nombreGPO ya existe"
    }

    return (Get-GPO -Name $nombreGPO).Id.ToString()
}

function Write-AppLockerXmlToGPO {
    param(
        [string]$nombreGPO,
        [string]$xmlContent
    )

    $tmpXml = "$env:TEMP\applocker_$nombreGPO.xml"
    $xmlContent | Set-Content $tmpXml -Encoding UTF8

    $gpo  = Get-GPO -Name $nombreGPO
    $guid = $gpo.Id.ToString().ToUpper()
    $ldap = "LDAP://CN={$guid},CN=Policies,CN=System,$dcPath"

    Set-AppLockerPolicy -XmlPolicy $tmpXml -Ldap $ldap -Merge
    Remove-Item $tmpXml -Force

    $gptPath = "C:\Windows\SYSVOL\sysvol\$dominio\Policies\{$guid}\gpt.ini"
    if (Test-Path $gptPath) {
        $content = Get-Content $gptPath -Raw
        if ($content -match "Version=(\d+)") {
            $newVersion = [int]$Matches[1] + 1
            $content = $content -replace "Version=\d+", "Version=$newVersion"
            $content | Set-Content $gptPath -Encoding ASCII
        }
    } else {
        @"
[General]
Version=65537
displayName=Nuevo objeto de directiva de grupo
"@ | Set-Content $gptPath -Encoding ASCII
    }

    Write-Host "Politica aplicada a GPO: $nombreGPO"
}

function Get-XmlCuates {
    return @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">

    <FilePathRule Id="$(New-Guid)" Name="Permitir Admins" Description="Admins sin restriccion" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*" />
      </Conditions>
    </FilePathRule>

    <FilePathRule Id="$(New-Guid)" Name="Permitir Windows" Description="Ejecutables del sistema" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\*" />
      </Conditions>
    </FilePathRule>

    <FilePathRule Id="$(New-Guid)" Name="Permitir Program Files" Description="Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%PROGRAMFILES%\*" />
      </Conditions>
    </FilePathRule>

  </RuleCollection>
</AppLockerPolicy>
"@
}

function Get-XmlNoCuates {
    $sidNoCuates = (Get-ADGroup "NoCuates").SID.Value

    Write-Host "Hash notepad: $notepadHash"
    Write-Host "Tamanio: $notepadFileLength bytes"

    return @"
<AppLockerPolicy Version="1">
  <RuleCollection Type="Exe" EnforcementMode="Enabled">

    <FilePathRule Id="$(New-Guid)" Name="Permitir Admins" Description="Admins sin restriccion" UserOrGroupSid="S-1-5-32-544" Action="Allow">
      <Conditions>
        <FilePathCondition Path="*" />
      </Conditions>
    </FilePathRule>

    <FilePathRule Id="$(New-Guid)" Name="Permitir Windows" Description="Ejecutables del sistema" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%WINDIR%\*" />
      </Conditions>
    </FilePathRule>

    <FilePathRule Id="$(New-Guid)" Name="Permitir Program Files" Description="Program Files" UserOrGroupSid="S-1-1-0" Action="Allow">
      <Conditions>
        <FilePathCondition Path="%PROGRAMFILES%\*" />
      </Conditions>
    </FilePathRule>

    <FileHashRule Id="$(New-Guid)" Name="Bloquear Notepad NoCuates por Hash" Description="Bloqueo por hash resiste renombrado" UserOrGroupSid="$sidNoCuates" Action="Deny">
      <Conditions>
        <FileHashCondition>
          <FileHash Type="SHA256" Data="$notepadHash" SourceFileName="notepad.exe" SourceFileLength="$notepadFileLength" />
        </FileHashCondition>
      </Conditions>
    </FileHashRule>

  </RuleCollection>
</AppLockerPolicy>
"@
}

function Invoke-ConfigurarAppLocker {

    Write-Host ""
    Write-Host "--- Configuracion de AppLocker ---"

    $svc = Get-Service -Name AppIDSvc -ErrorAction SilentlyContinue
    if ($null -eq $svc) {
        Write-Host "ERROR: Servicio AppIDSvc no encontrado"
        return
    }
    if ($svc.Status -ne "Running") {
        sc.exe config AppIDSvc start= auto | Out-Null
        Start-Service -Name AppIDSvc
        Write-Host "Servicio AppIDSvc iniciado"
    } else {
        Write-Host "AppIDSvc ya esta corriendo"
    }

    Write-Host ""
    Write-Host "[Cuates]"
    $gpoCuates = "AppLocker-Cuates"
    New-GPOAppLocker -nombreGPO $gpoCuates | Out-Null
    $xmlCuates = Get-XmlCuates
    Write-AppLockerXmlToGPO -nombreGPO $gpoCuates -xmlContent $xmlCuates
    New-GPLink -Name $gpoCuates -Target "OU=Cuates,$dcPath" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "GPO vinculada a OU=Cuates"

    Write-Host ""
    Write-Host "[NoCuates]"
    $gpoNoCuates = "AppLocker-NoCuates"
    New-GPOAppLocker -nombreGPO $gpoNoCuates | Out-Null
    $xmlNoCuates = Get-XmlNoCuates
    Write-AppLockerXmlToGPO -nombreGPO $gpoNoCuates -xmlContent $xmlNoCuates
    New-GPLink -Name $gpoNoCuates -Target "OU=NoCuates,$dcPath" -ErrorAction SilentlyContinue | Out-Null
    Write-Host "GPO vinculada a OU=NoCuates"

    Write-Host ""
    Write-Host "AppLocker configurado correctamente."
    Write-Host "En el cliente ejecuta: gpupdate /force"
    Write-Host "Luego cierra sesion y vuelve a entrar con un usuario NoCuates."
}