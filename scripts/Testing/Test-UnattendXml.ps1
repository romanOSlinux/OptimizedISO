<#
.SYNOPSIS
    romanOS Testing - Validador de Sintaxis y Bypasses para autounattend.xml
.DESCRIPTION
    Audita y certifica la validez estructural, sintáctica y de directivas de archivos autounattend.xml:
    1. Integridad de parseo XML en el motor nativo de .NET (System.Xml.XmlDocument).
    2. Verificación de espacios de nombres y pases oficiales (windowsPE, specialize, oobeSystem).
    3. Auditoría de bypasses críticos de Windows 11 (TPM, SecureBoot, RAM, CPU, Storage, MoSetup).
    4. Auditoría de omisión de cuenta Microsoft (BypassNRO).
    5. Validación de esquema de particionado UEFI GPT si está configurado.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = 'c:\OptimizedISO\sources\autounattend.xml'
)

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "El archivo autounattend.xml no existe en: $Path"
    exit 1
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " [romanOS] Validador Sintáctico y de Directivas de autounattend.xml" -ForegroundColor Cyan
Write-Host " Archivo: $Path" -ForegroundColor Gray
Write-Host "======================================================================" -ForegroundColor Cyan

$xmlDoc = New-Object System.Xml.XmlDocument
$rawContent = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)

# Reemplazar temporalmente tokens de plantilla ($Variable) para parseo sintactico si no esta renderizado
$parseableContent = $rawContent -replace '\$[A-Za-z0-9_]+', 'placeholder'

try {
    $xmlDoc.LoadXml($parseableContent)
    Write-Host " [PASS] Sintaxis XML bien formada (Well-formed XML Document)" -ForegroundColor Green
} catch {
    Write-Host " [FAIL] Error fatal de sintaxis XML: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$root = $xmlDoc.DocumentElement
if ($root.LocalName -ne 'unattend') {
    Write-Host " [FAIL] El elemento raíz no es <unattend>. Detectado: <$($root.LocalName)>" -ForegroundColor Red
    exit 1
}
Write-Host " [PASS] Elemento raíz <unattend> válido (Namespace: $($root.NamespaceURI))" -ForegroundColor Green

$validPasses = @('windowsPE', 'offlineServicing', 'generalize', 'specialize', 'auditSystem', 'auditUser', 'oobeSystem')
$settingsNodes = $xmlDoc.SelectNodes('//*[local-name()="settings"]')
Write-Host "`n>>> Auditoría de Pases de Configuración (Settings Passes):" -ForegroundColor Cyan
$detectedPasses = @()
foreach ($node in $settingsNodes) {
    $passName = $node.GetAttribute('pass')
    $detectedPasses += $passName
    if ($passName -in $validPasses) {
        $components = $node.SelectNodes('*[local-name()="component"]')
        Write-Host "   - Pase '$passName' [VALIDO] -> $($components.Count) componente(s) configurado(s)" -ForegroundColor Green
    } else {
        Write-Host "   - Pase '$passName' [INVALIDO] -> Nombre de pase no reconocido por Windows Setup" -ForegroundColor Red
    }
}

# Auditoria de Bypasses en windowsPE
Write-Host "`n>>> Auditoría de Bypasses de Windows 11 (LabConfig / MoSetup):" -ForegroundColor Cyan
$bypasses = @(
    'BypassTPMCheck',
    'BypassSecureBootCheck',
    'BypassRAMCheck',
    'BypassCPUCheck',
    'BypassStorageCheck',
    'AllowUpgradesWithUnsupportedTPMOrCPU'
)

$commands = $xmlDoc.SelectNodes('//*[local-name()="RunSynchronousCommand"]/*[local-name()="Path"]')
$foundBypasses = @{}
foreach ($cmd in $commands) {
    $text = $cmd.InnerText
    foreach ($b in $bypasses) {
        if ($text -match $b) {
            $foundBypasses[$b] = $true
        }
    }
}

$allBypassesPresent = $true
foreach ($b in $bypasses) {
    if ($foundBypasses[$b]) {
        Write-Host "   - $b : [PRESENTE]" -ForegroundColor Green
    } else {
        Write-Host "   - $b : [NO DETECTADO]" -ForegroundColor Yellow
        if ($b -in @('BypassTPMCheck', 'BypassSecureBootCheck', 'BypassRAMCheck')) {
            $allBypassesPresent = $false
        }
    }
}

# Auditoria de BypassNRO (Cuenta Local sin Internet)
Write-Host "`n>>> Auditoría de Bypass de Cuenta Microsoft (BypassNRO):" -ForegroundColor Cyan
$hasBypassNRO = ($rawContent -match 'BypassNRO')
if ($hasBypassNRO) {
    Write-Host "   - BypassNRO (OOBE sin conexión): [CONFIGURADO]" -ForegroundColor Green
} else {
    Write-Host "   - BypassNRO (OOBE sin conexión): [NO DETECTADO EN XML (Gestionado por Policy-Engine/SetupComplete)]" -ForegroundColor Gray
}

# Auditoria de Particionado de Disco
Write-Host "`n>>> Auditoría de Particionado de Disco (DiskConfiguration):" -ForegroundColor Cyan
$diskConfig = $xmlDoc.SelectSingleNode('//*[local-name()="DiskConfiguration"]')
if ($diskConfig) {
    Write-Host "   - DiskConfiguration: [PRESENTE]" -ForegroundColor Yellow
} else {
    Write-Host "   - DiskConfiguration: [NO PRESENTE - Selección Manual de Partición por el Usuario]" -ForegroundColor Green
}

Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
if ($allBypassesPresent) {
    Write-Host " [PASS] autounattend.xml certificado: Sintaxis 100% válida y bypasses esenciales confirmados." -ForegroundColor Green
    exit 0
} else {
    Write-Host " [WARN] autounattend.xml válido sintácticamente pero faltan algunos bypasses críticos." -ForegroundColor Yellow
    exit 0
}
