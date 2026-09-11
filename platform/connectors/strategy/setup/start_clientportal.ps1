[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$GatewayDirectory,
    [string]$JavaExecutable = 'java.exe'
)
$ErrorActionPreference = 'Stop'
$gateway = [IO.Path]::GetFullPath($GatewayDirectory)
if (-not [IO.Path]::IsPathFullyQualified($GatewayDirectory)) { throw 'Use the absolute directory of your prepared Client Portal Gateway.' }
$localRoot = Join-Path $gateway 'leo-local'
foreach ($relative in @('leo-local\policy-receipt.json', 'leo-local\conf.yaml', 'leo-local\localhost.pem', 'leo-local\localhost.cer', 'leo-local\localhost.jks', 'leo-local\logback.xml', 'dist\ibgroup.web.core.iblink.router.clientportal.gw.jar')) {
    if (-not (Test-Path -LiteralPath (Join-Path $gateway $relative) -PathType Leaf)) { throw 'Gateway local TLS/IP configuration is not prepared. Complete the local setup first.' }
}
$policy = Get-Content -LiteralPath (Join-Path $localRoot 'policy-receipt.json') -Raw | ConvertFrom-Json
if ($policy.schemaVersion -ne 'leo.clientportal-local-policy.v1' -or $policy.localIpPolicyVerified -ne $true -or $policy.tlsReadinessVerified -ne $true) { throw 'The prepared gateway has no verified local IP/TLS policy receipt.' }
foreach ($entry in @(@('leo-local\conf.yaml', $policy.configurationSha256), @('leo-local\localhost.cer', $policy.certificateSha256), @('dist\ibgroup.web.core.iblink.router.clientportal.gw.jar', $policy.gatewayJarSha256))) {
    if ($entry[1] -notmatch '^[a-f0-9]{64}$' -or (Get-FileHash -LiteralPath (Join-Path $gateway $entry[0]) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry[1]) { throw 'Gateway files changed after local IP/TLS validation. Repeat setup verification before starting.' }
}
if (Get-NetTCPConnection -State Listen -LocalPort 5000 -ErrorAction SilentlyContinue) { throw 'Port5000 is already in use. Inspect the existing gateway; do not start a duplicate.' }
$java = (Get-Command $JavaExecutable -ErrorAction Stop).Source
$arguments = @('-server', '-Dvertx.disableDnsResolver=true', '-Djava.net.preferIPv4Stack=true', '-Dvertx.logger-delegate-factory-class-name=io.vertx.core.logging.SLF4JLogDelegateFactory', '-Dlogback.configurationFile=leo-local/logback.xml', '-classpath', 'leo-local;root;dist/ibgroup.web.core.iblink.router.clientportal.gw.jar;build/lib/runtime/*', 'ibgroup.web.core.clientportal.gw.GatewayStart', '-conf', 'conf.yaml')
$gatewayProcess = Start-Process -FilePath $java -ArgumentList $arguments -WorkingDirectory $gateway -WindowStyle Hidden -RedirectStandardOutput (Join-Path $localRoot 'gateway.stdout.log') -RedirectStandardError (Join-Path $localRoot 'gateway.stderr.log') -PassThru
$gatewayProcess.Id | Set-Content -LiteralPath (Join-Path $localRoot 'gateway.pid') -Encoding ascii
Write-Host "Gateway process started (PID $($gatewayProcess.Id)). Verify readiness, then sign into your PAPER account at https://localhost:5000."
Write-Host ('Expected local certificate SHA256: ' + (Get-FileHash -LiteralPath (Join-Path $localRoot 'localhost.cer') -Algorithm SHA256).Hash.ToLowerInvariant())
Write-Host 'This does not log in, approve broker access, pair a Leo device or start a strategy.'
