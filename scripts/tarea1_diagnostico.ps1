Write-Host "Hostname:"
$env:COMPUTERNAME

Write-Host ""
Write-Host "Direccion IP:"
ipconfig | findstr IPv4

Write-Host ""
Write-Host "Espacio en Disco:"
Get-PSDrive C | Select-Object Used, Free