$ErrorActionPreference = "Stop"

# Leer JSON desde stdin
$inputJson = $input | Out-String | ConvertFrom-Json

# Verificar si es run_command y contiene git commit
if ($inputJson.toolCall.name -eq "run_command") {
    $cmd = $inputJson.toolCall.args.CommandLine
    
    if ($cmd -match "git\s+commit") {
        Write-Error "Validando pre-commit (TestSuite y UTF-8-BOM)..." -ErrorAction SilentlyContinue
        
        # Ejecutar suite de pruebas
        $testScript = "$($inputJson.workspacePaths[0])\scripts\Testing\Test-OptimizedISO-v2.ps1"
        if (Test-Path $testScript) {
            & "powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $testScript
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -ne 0) {
                $response = @{
                    decision = "deny"
                    reason = "Pruebas de Test-OptimizedISO-v2.ps1 fallaron. No se permite el commit."
                }
                $response | ConvertTo-Json -Depth 10 | Write-Output
                exit 0
            }
        }
        
        # Opcional: verificar UTF-8-BOM en scripts .ps1 modificados
        $gitDiff = git diff --cached --name-only --diff-filter=ACM | Select-String "\.ps1$"
        foreach ($file in $gitDiff) {
            $filePath = "$($inputJson.workspacePaths[0])\$file"
            if (Test-Path $filePath) {
                $bytes = Get-Content -Path $filePath -Encoding Byte -ReadCount 3 -TotalCount 3
                if ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
                    $response = @{
                        decision = "deny"
                        reason = "El archivo $file no tiene codificaciÃ³n UTF-8-BOM. CorrÃ­gelo antes de hacer commit."
                    }
                    $response | ConvertTo-Json -Depth 10 | Write-Output
                    exit 0
                }
            }
        }
    }
}

# Si todo estÃ¡ bien o no es git commit, permitimos
$response = @{
    decision = "allow"
}
$response | ConvertTo-Json -Depth 10 | Write-Output
exit 0
