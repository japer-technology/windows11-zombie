$ErrorActionPreference = 'Stop'
$packageName = 'windows-zombie'
$url64 = 'https://github.com/japer-technology/windows-zombie/releases/download/v0.0.0/windows-zombie-0.0.0.zip'
$checksum64 = '0000000000000000000000000000000000000000000000000000000000000000'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$installDir = Join-Path $toolsDir 'app'
Install-ChocolateyZipPackage -PackageName $packageName -Url64bit $url64 -UnzipLocation $installDir `
    -Checksum64 $checksum64 -ChecksumType64 'sha256'
& (Join-Path $installDir 'scripts\Install.ps1') install
