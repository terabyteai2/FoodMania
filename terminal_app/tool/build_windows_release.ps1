$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$Pubspec = Get-Content (Join-Path $RootDir "pubspec.yaml") -Raw
if ($Pubspec -notmatch "(?m)^version:\s*([^+\r\n]+)") {
  throw "Could not read the application version from pubspec.yaml."
}

$Version = $Matches[1]
$ReleaseDir = Join-Path $RootDir "build\windows\x64\runner\Release"
$DistDir = Join-Path $RootDir "dist"
$PortableDir = Join-Path $DistDir "Terafoods-POS-Windows-$Version"
$ZipPath = "$PortableDir.zip"

Push-Location $RootDir
try {
  flutter config --enable-windows-desktop
  flutter pub get
  flutter build windows --release

  $ApplicationExe = Join-Path $ReleaseDir "local_pos.exe"
  if (-not (Test-Path $ApplicationExe)) {
    throw "Windows executable was not found at: $ApplicationExe"
  }

  New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $PortableDir
  Remove-Item -Force -ErrorAction SilentlyContinue $ZipPath
  Copy-Item -Recurse -Force $ReleaseDir $PortableDir
  Compress-Archive -Path "$PortableDir\*" -DestinationPath $ZipPath

  Write-Host ""
  Write-Host "Application executable:"
  Write-Host "  $PortableDir\local_pos.exe"
  Write-Host "Portable Windows bundle:"
  Write-Host "  $ZipPath"

  $NsisCommand = Get-Command "makensis.exe" -ErrorAction SilentlyContinue
  $NsisPath = if ($NsisCommand) { $NsisCommand.Source } else { $null }
  if (-not $NsisPath) {
    $TypicalNsis = "${env:ProgramFiles(x86)}\NSIS\makensis.exe"
    if (Test-Path $TypicalNsis) {
      $NsisPath = $TypicalNsis
    }
  }

  if ($NsisPath) {
    $SetupExe = Join-Path $DistDir "Terafoods-POS-Setup-$Version.exe"
    $IconFile = Join-Path $RootDir "windows\runner\resources\app_icon.ico"
    & $NsisPath `
      "/DAPP_VERSION=$Version" `
      "/DRELEASE_DIR=$ReleaseDir" `
      "/DOUTPUT_FILE=$SetupExe" `
      "/DICON_FILE=$IconFile" `
      (Join-Path $RootDir "packaging\windows\terafoods_pos.nsi")
    Write-Host "Windows installer:"
    Write-Host "  $SetupExe"
  } else {
    Write-Host ""
    Write-Host "NSIS is not installed, so Setup.exe was skipped."
    Write-Host "Install NSIS and run this script again to create the installer."
  }
} finally {
  Pop-Location
}
