Write-host 'Build FOGPatcher'

try
{
	$LePwd = $pwd.path

	if (-Not (Test-Path "$PSScriptRoot\prereboot.ps1")) {
	  Throw "BUILD : ${LePwd}prereboot.ps1 is missing"
	  exit 1
	}
	if (-Not (Test-Path "$PSScriptRoot\syreboot.dll")) {
	  Throw "BUILD : ${LePwd}syreboot.dll is missing"
	  exit 1
	}
	if (-Not (Test-Path "$PSScriptRoot\syreboot.pb")) {
	  Throw "BUILD : ${LePwd}syreboot.pb is missing"
	  exit 1
	}	
	if (-Not (Test-Path "$PSScriptRoot\_patcher.psone")) {
	  Throw "BUILD : ${LePwd}_patcher.psone is missing"
	  exit 1
	}

	$MD5_syreboot_dll=(Get-FileHash -Algorithm MD5 "$PSScriptRoot\syreboot.dll").hash
	$BIN_syreboot_dll = [System.IO.File]::ReadAllBytes("$PSScriptRoot\syreboot.dll")
	$B64_syreboot_dll = [Convert]::ToBase64String($BIN_syreboot_dll)

	$MD5_prereboot_ps1=(Get-FileHash -Algorithm MD5 "$PSScriptRoot\prereboot.ps1").hash
	$BIN_prereboot_ps1 = [System.IO.File]::ReadAllBytes("$PSScriptRoot\prereboot.ps1")
	$B64_prereboot_ps1 = [Convert]::ToBase64String($BIN_prereboot_ps1)
	
	$BIN_syreboot_pb = [System.IO.File]::ReadAllBytes("$PSScriptRoot\syreboot.pb")
	$B64_syreboot_pb = [Convert]::ToBase64String($BIN_syreboot_pb)	

	Copy-Item "$PSScriptRoot\_patcher.psone" -Destination "$PSScriptRoot\FOGpatcher.ps1" -Force

	$BIN_FOGPatcher = Get-Content -Path "$PSScriptRoot\FOGpatcher.ps1" -Raw
	$BIN_FOGPatcher = $BIN_FOGPatcher -replace 'KEY_SYREBOOT_DLL' , $B64_syreboot_dll
	$BIN_FOGPatcher = $BIN_FOGPatcher -replace 'MD5_SYREBOOT_DLL' , $MD5_syreboot_dll
	
	$BIN_FOGPatcher = $BIN_FOGPatcher -replace 'KEY_PREREBOOT_PS1', $B64_prereboot_ps1
	$BIN_FOGPatcher = $BIN_FOGPatcher -replace 'MD5_PREREBOOT_PS1' , $MD5_prereboot_ps1
	
	$BIN_FOGPatcher = $BIN_FOGPatcher -replace 'KEY_PREREBOOT_PB', $B64_syreboot_pb



	Set-Content -Path "$PSScriptRoot\FOGpatcher.ps1" -Value $BIN_FOGPatcher
	Write-host 'Done'
}
catch
{
	$e = $_.Exception
	$msg = $e.Message
	while ($e.InnerException) {
	  $e = $e.InnerException
	  $msg += "`n" + $e.Message
	}
	$msg
	Remove-Item -Path "$PSScriptRoot\FOGpatcher.ps1" -Force
	Write-host 'Failed'
}