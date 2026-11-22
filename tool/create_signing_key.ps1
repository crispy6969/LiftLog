param([string]$Keytool = 'keytool')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$keyDirectory = Join-Path $repoRoot '.keys'
$keyPath = Join-Path $keyDirectory 'liftlog-release.jks'
$propertiesPath = Join-Path $repoRoot 'android\key.properties'
if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw 'A signing key or configuration already exists. Keep it; do not replace it for app updates.'
}
New-Item -ItemType Directory -Force -Path $keyDirectory | Out-Null
$password = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
& $Keytool -genkeypair -keystore $keyPath -storetype JKS -alias liftlog -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Liftlog Personal' -storepass $password -keypass $password
if ($LASTEXITCODE -ne 0) { throw 'Key generation failed. No signing configuration was written.' }
$properties = "storeFile=../.keys/liftlog-release.jks`nstorePassword=$password`nkeyAlias=liftlog`nkeyPassword=$password`n"
[IO.File]::WriteAllText($propertiesPath, $properties)
Write-Output 'Created private signing files. Back up .keys/liftlog-release.jks and android/key.properties securely before relying on release builds. Do not commit them.'
