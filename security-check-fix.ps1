$Host.UI.RawUI.WindowTitle = "WINDOWS SECURITY TOOL"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

function Write-Typewriter {
    param(
        [string]$Text,
        [ConsoleColor]$Color = "White",
        [int]$MinDelay = 10,
        [int]$MaxDelay = 30,
        [switch]$NoNewLine
    )
    foreach ($char in $Text.ToCharArray()) {
        Write-Host $char -NoNewline -ForegroundColor $Color
        Start-Sleep -Milliseconds (Get-Random -Minimum $MinDelay -Maximum $MaxDelay)
    }
    if (-not $NoNewLine) { Write-Host "" }
}

function Show-Spinner {
    param(
        [string]$Text,
        [scriptblock]$Action,
        [int]$MinDuration = 2000,
        [int]$MaxDuration = 4000
    )
    
    $spinChars = @('|', '/', '-', '\')
    $duration = Get-Random -Minimum $MinDuration -Maximum $MaxDuration
    $startTime = Get-Date
    $result = $null
    $jobDone = $false
    
    $job = Start-Job -ScriptBlock $Action
    
    $i = 0
    while (-not $jobDone) {
        $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
        $spin = $spinChars[$i % 4]
        
        Write-Host "`r  [$spin] $Text" -NoNewline -ForegroundColor Cyan
        Start-Sleep -Milliseconds 100
        $i++
        
        if ((Get-Job -Id $job.Id).State -eq 'Completed' -and $elapsed -ge $duration) {
            $jobDone = $true
        }
    }
    
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    
    Write-Host "`r" -NoNewline
    Write-Host ("  " + " " * ($Text.Length + 10)) -NoNewline
    Write-Host "`r" -NoNewline
    
    return $result
}

function Show-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Label = "Progresso"
    )
    
    $percent = [math]::Round(($Current / $Total) * 100)
    $barWidth = 40
    $filled = [math]::Round(($percent / 100) * $barWidth)
    $empty = $barWidth - $filled
    
    $bar = "[" + ("=" * $filled) + (">" * [math]::Min(1, $empty)) + (" " * [math]::Max(0, $empty - 1)) + "]"
    
    Write-Host "`r  $bar $percent% - $Label" -NoNewline -ForegroundColor DarkCyan
}

function Show-CheckItem {
    param(
        [string]$Name,
        [string]$Status,  # "OK", "ERRO", "ALERTA", "FIX"
        [string]$Detail = ""
    )
    
    $icon = switch ($Status) {
        "OK"     { "[OK]"; break }
        "ERRO"   { "[X]"; break }
        "ALERTA" { "[!]"; break }
        "FIX"    { "[~]"; break }
        default  { "[ ]" }
    }
    
    $color = switch ($Status) {
        "OK"     { "Green"; break }
        "ERRO"   { "Red"; break }
        "ALERTA" { "Yellow"; break }
        "FIX"    { "Magenta"; break }
        default  { "Gray" }
    }
    
    Write-Host "  $icon " -NoNewline -ForegroundColor $color
    Write-Host "$Name" -NoNewline -ForegroundColor White
    
    if ($Detail) {
        Write-Host " - " -NoNewline -ForegroundColor DarkGray
        Write-Host "$Detail" -ForegroundColor DarkCyan
    } else {
        Write-Host ""
    }
}

function Show-Header {
    $width = 60
    $border = "=" * $width
    
    Clear-Host
    Write-Host ""
    Write-Host "  $border" -ForegroundColor Cyan
    Write-Host ""
    
    $title = "WINDOWS SECURITY TOOL"
    $subtitle = "Developed by @bygreatness on Discord"
    $version = "v2.0 PHANTOM"
    
    $titlePad = [math]::Floor(($width - $title.Length) / 2)
    $subtitlePad = [math]::Floor(($width - $subtitle.Length) / 2)
    $versionPad = [math]::Floor(($width - $version.Length) / 2)
    
    Write-Host (" " * ($titlePad + 2)) -NoNewline
    Write-Typewriter -Text $title -Color Cyan -MinDelay 30 -MaxDelay 60
    
    Write-Host (" " * ($subtitlePad + 2)) -NoNewline
    Write-Host $subtitle -ForegroundColor DarkGray
    
    Write-Host (" " * ($versionPad + 2)) -NoNewline
    Write-Host $version -ForegroundColor DarkCyan
    
    Write-Host ""
    Write-Host "  $border" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "  --- $Title ---" -ForegroundColor Yellow
    Write-Host ""
}

function Show-CountdownTimer {
    param(
        [int]$Seconds,
        [string]$Message
    )
    
    for ($i = $Seconds; $i -ge 0; $i--) {
        Write-Host "`r  $Message em ${i}s...  " -NoNewline -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    Write-Host "`r  $Message agora!          " -ForegroundColor Green
}

$checks = @{
    Admin = @{ Status = "PENDING"; Detail = "" }
    TPM = @{ Status = "PENDING"; Detail = "" }
    SecureBoot = @{ Status = "PENDING"; Detail = "" }
    UEFI = @{ Status = "PENDING"; Detail = "" }
    Hypervisor = @{ Status = "PENDING"; Detail = "" }
    Virtualization = @{ Status = "PENDING"; Detail = "" }
    HVCI = @{ Status = "PENDING"; Detail = "" }
    VBS = @{ Status = "PENDING"; Detail = "" }
}

$fixNeeded = @{
    Hypervisor = $false
    HVCI = $false
}

Show-Header

Write-Host "  Verificando privilegios..." -ForegroundColor DarkGray
Start-Sleep -Milliseconds 500

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Show-CheckItem -Name "Privilegios de Administrador" -Status "ERRO" -Detail "Execute como Admin!"
    Write-Host ""
    Write-Host "  Pressione qualquer tecla para sair..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

$checks.Admin.Status = "OK"
Show-CheckItem -Name "Privilegios de Administrador" -Status "OK" -Detail "Elevado"

Start-Sleep -Milliseconds 800
$os = Get-CimInstance Win32_OperatingSystem
Write-Host ""
Write-Host "  Sistema: " -NoNewline -ForegroundColor DarkGray
Write-Typewriter -Text "$($os.Caption)" -Color White -MinDelay 5 -MaxDelay 15
Write-Host "  Build:   " -NoNewline -ForegroundColor DarkGray
Write-Host "$($os.Version)" -ForegroundColor Cyan

Show-Section "VERIFICACAO DE SEGURANCA"

$totalChecks = 7
$currentCheck = 0

$currentCheck++
Show-ProgressBar -Current $currentCheck -Total $totalChecks -Label "Verificando TPM"

$tpmResult = Show-Spinner -Text "Analisando TPM 2.0..." -Action {
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent -and $tpm.TpmReady) {
            return @{ OK = $true; Detail = "TPM 2.0 Ready" }
        } else {
            return @{ OK = $false; Detail = "TPM ausente ou nao pronto" }
        }
    } catch {
        return @{ OK = $false; Detail = "Erro ao verificar" }
    }
}

if ($tpmResult.OK) {
    $checks.TPM.Status = "OK"
    Show-CheckItem -Name "TPM 2.0" -Status "OK" -Detail $tpmResult.Detail
} else {
    $checks.TPM.Status = "ERRO"
    Show-CheckItem -Name "TPM 2.0" -Status "ERRO" -Detail $tpmResult.Detail
}

$currentCheck++
Show-ProgressBar -Current $currentCheck -Total $totalChecks -Label "Verificando Secure Boot"

$sbResult = Show-Spinner -Text "Verificando Secure Boot..." -Action {
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        if ($sb) {
            return @{ OK = $true; Detail = "Ativado" }
        } else {
            return @{ OK = $false; Detail = "Desativado" }
        }
    } catch {
        return @{ OK = $false; Detail = "Indisponivel" }
    }
}

if ($sbResult.OK) {
    $checks.SecureBoot.Status = "OK"
    Show-CheckItem -Name "Secure Boot" -Status "OK" -Detail $sbResult.Detail
} else {
    $checks.SecureBoot.Status = "ERRO"
    Show-CheckItem -Name "Secure Boot" -Status "ERRO" -Detail $sbResult.Detail
}

$currentCheck++
Show-ProgressBar -Current $currentCheck -Total $totalChecks -Label "Verificando UEFI"

$uefiResult = Show-Spinner -Text "Detectando modo de firmware..." -Action {
    $detected = $false
    $method = ""
    
    $fwType = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name PEFirmwareType -ErrorAction SilentlyContinue).PEFirmwareType
    if ($fwType -eq 2) {
        $detected = $true
        $method = "Registro"
    }
    
    if (-not $detected) {
        try {
            $bcd = bcdedit /enum '{current}' 2>$null | Select-String "path"
            if ($bcd -match "\.efi") {
                $detected = $true
                $method = "Bootloader EFI"
            }
        } catch { }
    }
    
    if (-not $detected) {
        try {
            $efi = Get-Partition -ErrorAction SilentlyContinue | 
                Where-Object { $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" }
            if ($efi) {
                $detected = $true
                $method = "Particao GPT"
            }
        } catch { }
    }
    
    return @{ OK = $detected; Detail = $method }
}

if ($uefiResult.OK) {
    $checks.UEFI.Status = "OK"
    Show-CheckItem -Name "UEFI Mode" -Status "OK" -Detail $uefiResult.Detail
} else {
    $checks.UEFI.Status = "ERRO"
    Show-CheckItem -Name "UEFI Mode" -Status "ERRO" -Detail "Legacy BIOS detectado"
}

$currentCheck++
Show-ProgressBar -Current $currentCheck -Total $totalChecks -Label "Verificando Hypervisor"

$hvResult = Show-Spinner -Text "Analisando configuracao do Hypervisor..." -Action {
    try {
        $hv = bcdedit /enum 2>$null | Select-String "hypervisorlaunchtype"
        if ($hv -match "Auto") {
            return @{ OK = $true; NeedFix = $false; Detail = "Auto" }
        } else {
            return @{ OK = $false; NeedFix = $true; Detail = "Desativado" }
        }
    } catch {
        return @{ OK = $false; NeedFix = $true; Detail = "Erro" }
    }
}

if ($hvResult.OK) {
    $checks.Hypervisor.Status = "OK"
    Show-CheckItem -Name "Hypervisor" -Status "OK" -Detail $hvResult.Detail
} else {
    $checks.Hypervisor.Status = "ERRO"
    $fixNeeded.Hypervisor = $true
    Show-CheckItem -Name "Hypervisor" -Status "ERRO" -Detail $hvResult.Detail
}

$currentCheck++
Show-ProgressBar -Current $currentCheck -Total $totalChecks -Label "Verificando Virtualizacao"

$virtResult = Show-Spinner -Text "Detectando suporte a virtualizacao..." -Action {
    $detected = $false
    $detail = ""
    
    $hvPresent = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
    if ($hvPresent -eq $true) {
        $detected = $true
        $detail = "Hypervisor ativo"
    }
    
    if (-not $detected) {
        $proc = Get-CimInstance Win32_Processor
        if ($proc.VirtualizationFirmwareEnabled -eq $true) {
            $detected = $true
            $detail = "VT-x/AMD-V"
        }
        if ($proc.SecondLevelAddressTranslationExtensions -eq $true) {
            $detected = $true
            $detail = "SLAT"
        }
    }
    
    return @{ OK = $detected; Detail = $detail }
}

if ($virtResult.OK) {
    $checks.Virtualization.Status = "OK"
    Show-CheckItem -Name "Virtualizacao (VT-x/SVM)" -Status "OK" -Detail $virtResult.Detail
} else {
    $checks.Virtualization.Status = "ERRO"
    Show-CheckItem -Name "Virtualizacao (VT-x/SVM)" -Status "ERRO" -Detail "Verifique BIOS/UEFI"
}

$currentCheck++
Show-ProgressBar -Current $currentCheck -Total $totalChecks -Label "Verificando HVCI"

$hvciResult = Show-Spinner -Text "Verificando Memory Integrity (HVCI)..." -Action {
    $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    $hvci = Get-ItemProperty -Path $hvciPath -Name Enabled -ErrorAction SilentlyContinue
    
    if ($hvci.Enabled -eq 1) {
        return @{ OK = $true; NeedFix = $false; Detail = "Ativado" }
    } else {
        return @{ OK = $false; NeedFix = $true; Detail = "Desativado" }
    }
}

if ($hvciResult.OK) {
    $checks.HVCI.Status = "OK"
    Show-CheckItem -Name "HVCI (Memory Integrity)" -Status "OK" -Detail $hvciResult.Detail
} else {
    $checks.HVCI.Status = "ERRO"
    $fixNeeded.HVCI = $true
    Show-CheckItem -Name "HVCI (Memory Integrity)" -Status "ERRO" -Detail $hvciResult.Detail
}

$currentCheck++
Show-ProgressBar -Current $currentCheck -Total $totalChecks -Label "Verificando VBS"

Start-Sleep -Milliseconds 500
Write-Host "`r" -NoNewline
Write-Host ("  " + " " * 60) -NoNewline
Write-Host "`r" -NoNewline

if ($checks.Hypervisor.Status -eq "OK" -and $checks.HVCI.Status -eq "OK") {
    $checks.VBS.Status = "OK"
    Show-CheckItem -Name "VBS (Virtualization-Based Security)" -Status "OK" -Detail "Hypervisor + HVCI"
} else {
    $checks.VBS.Status = "ALERTA"
    Show-CheckItem -Name "VBS (Virtualization-Based Security)" -Status "ALERTA" -Detail "Incompleto"
}

if ($fixNeeded.Hypervisor -or $fixNeeded.HVCI) {
    Show-Section "APLICANDO CORRECOES AUTOMATICAS"
    
    Write-Host "  Problemas detectados:" -ForegroundColor Yellow
    if ($fixNeeded.Hypervisor) {
        Write-Host "    - Hypervisor desativado" -ForegroundColor Red
    }
    if ($fixNeeded.HVCI) {
        Write-Host "    - HVCI desativado" -ForegroundColor Red
    }
    Write-Host ""
    
    Write-Host "  Preparando correcoes" -NoNewline -ForegroundColor Cyan
    for ($i = 0; $i -lt 3; $i++) {
        Start-Sleep -Milliseconds 500
        Write-Host "." -NoNewline -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host ""
    
    if ($fixNeeded.Hypervisor) {
        $null = Show-Spinner -Text "Ativando Hypervisor (bcdedit)..." -Action {
            bcdedit /set hypervisorlaunchtype auto 2>$null | Out-Null
            return $true
        } -MinDuration 1500 -MaxDuration 2500
        
        Show-CheckItem -Name "Hypervisor" -Status "FIX" -Detail "Configurado para Auto"
    }
    
    if ($fixNeeded.HVCI) {
        $null = Show-Spinner -Text "Ativando HVCI (Memory Integrity)..." -Action {
            $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
            if (-not (Test-Path $hvciPath)) {
                New-Item -Path $hvciPath -Force | Out-Null
            }
            Set-ItemProperty -Path $hvciPath -Name Enabled -Value 1 -Type DWord -Force
            return $true
        } -MinDuration 1500 -MaxDuration 2500
        
        Show-CheckItem -Name "HVCI" -Status "FIX" -Detail "Ativado via registro"
    }
    
    Write-Host ""
    Write-Host "  Correcoes aplicadas com sucesso!" -ForegroundColor Green
}

Show-Section "RESUMO"

$okCount = ($checks.Values | Where-Object { $_.Status -eq "OK" }).Count
$errCount = ($checks.Values | Where-Object { $_.Status -eq "ERRO" }).Count
$alertCount = ($checks.Values | Where-Object { $_.Status -eq "ALERTA" }).Count

Write-Host "  Verificacoes: " -NoNewline -ForegroundColor White
Write-Host "$okCount OK" -NoNewline -ForegroundColor Green
Write-Host " | " -NoNewline -ForegroundColor DarkGray
Write-Host "$errCount ERRO" -NoNewline -ForegroundColor Red
Write-Host " | " -NoNewline -ForegroundColor DarkGray
Write-Host "$alertCount ALERTA" -ForegroundColor Yellow

Write-Host ""

$boxWidth = 50
$border = "=" * $boxWidth

Write-Host ""
Write-Host "  $border" -ForegroundColor DarkCyan

if ($fixNeeded.Hypervisor -or $fixNeeded.HVCI) {
    Write-Host ""
    Write-Host "     REINICIALIZACAO NECESSARIA" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "     As configuracoes de seguranca foram" -ForegroundColor White
    Write-Host "     aplicadas e entrarao em vigor apos" -ForegroundColor White
    Write-Host "     reiniciar o computador." -ForegroundColor White
    Write-Host ""
    Write-Host "  $border" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "  Deseja reiniciar agora? (S/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    
    if ($response -match "^[Ss]") {
        Write-Host ""
        Show-CountdownTimer -Seconds 5 -Message "Reiniciando"
        Restart-Computer -Force
    } else {
        Write-Host ""
        Write-Host "  Lembre-se de reiniciar manualmente!" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "     SISTEMA FUNCIONANDO" -ForegroundColor Green
    Write-Host ""
    Write-Host "     Todas as configuracoes necessarias" -ForegroundColor White
    Write-Host "     estao ativas e funcionando!" -ForegroundColor White
    Write-Host ""
    Write-Host "  $border" -ForegroundColor DarkCyan
}

Write-Host ""
Write-Host "  Pressione qualquer tecla para sair..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
