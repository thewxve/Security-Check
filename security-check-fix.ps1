$Host.UI.RawUI.WindowTitle = "WINDOWS SECURITY TOOL"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

# ==================== FUNCOES DE UI ====================

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
    
    Write-Host "`r$(' ' * 80)`r" -NoNewline
    
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
        [string]$Status,
        [string]$Detail = ""
    )
    
    $icon = switch ($Status) {
        "OK"     { "[OK]"; break }
        "ERRO"   { "[X]"; break }
        "ALERTA" { "[!]"; break }
        "FIX"    { "[~]"; break }
        "INFO"   { "[i]"; break }
        default  { "[ ]" }
    }
    
    $color = switch ($Status) {
        "OK"     { "Green"; break }
        "ERRO"   { "Red"; break }
        "ALERTA" { "Yellow"; break }
        "FIX"    { "Magenta"; break }
        "INFO"   { "Cyan"; break }
        default  { "Gray" }
    }
    
    Write-Host "`r$(' ' * 80)`r" -NoNewline
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
    param([switch]$NoClear)
    
    $width = 60
    $border = "=" * $width
    
    if (-not $NoClear) { Clear-Host }
    Write-Host ""
    Write-Host "  $border" -ForegroundColor Cyan
    Write-Host ""
    
    $title = "WINDOWS SECURITY TOOL"
    $subtitle = "Developed by @bygreatness on Discord"
    $version = "v3.0 PHANTOM"
    
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

# ==================== FUNCOES DE VERIFICACAO ====================

function Get-NetworkInfo {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    $result = @{
        MACs = @()
        IPs = @()
    }
    
    foreach ($adapter in $adapters) {
        $result.MACs += "$($adapter.Name): $($adapter.MacAddress)"
        
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ipConfig) {
            $result.IPs += "$($adapter.Name): $($ipConfig.IPAddress)"
        }
    }
    
    return $result
}

function Get-TPMStatus {
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        if ($tpm.TpmPresent -and $tpm.TpmReady) {
            return @{ OK = $true; Detail = "TPM 2.0 Ready" }
        } else {
            return @{ OK = $false; Detail = "Ausente ou nao pronto" }
        }
    } catch {
        return @{ OK = $false; Detail = "Erro ao verificar" }
    }
}

function Get-HVCIStatus {
    $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    $hvci = Get-ItemProperty -Path $hvciPath -Name Enabled -ErrorAction SilentlyContinue
    
    if ($hvci.Enabled -eq 1) {
        return @{ OK = $true; Detail = "Ativado" }
    } else {
        return @{ OK = $false; Detail = "Desativado" }
    }
}

# ==================== VARIAVEIS GLOBAIS ====================

$script:initialState = @{
    MACs = @()
    IPs = @()
    TPM = ""
    HVCI = ""
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

# ==================== MENU PRINCIPAL ====================

function Show-Menu {
    $width = 50
    $border = "=" * $width
    
    Write-Host ""
    Write-Host "  $border" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "     MENU DE OPCOES" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "     [1] Verificar Spoof" -ForegroundColor White
    Write-Host "     [2] Sair" -ForegroundColor White
    Write-Host ""
    Write-Host "  $border" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Escolha uma opcao: " -NoNewline -ForegroundColor Cyan
}

function Show-SpoofWarning {
    Clear-Host
    $width = 60
    $border = "=" * $width
    
    Write-Host ""
    Write-Host "  $border" -ForegroundColor Red
    Write-Host ""
    Write-Host "     !! ATENCAO !!" -ForegroundColor Red
    Write-Host ""
    Write-Host "     Esta opcao deve ser executada SOMENTE apos" -ForegroundColor Yellow
    Write-Host "     o uso do programa de alteracao (spoof)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "     Execute essa verificacao apenas depois de" -ForegroundColor Yellow
    Write-Host "     concluir TODAS as alteracoes no sistema." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  $border" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Deseja continuar? (S/N): " -NoNewline -ForegroundColor Cyan
    
    $response = Read-Host
    return ($response -match "^[Ss]")
}

function Show-SpoofVerification {
    Clear-Host
    $width = 60
    $border = "=" * $width
    
    Write-Host ""
    Write-Host "  $border" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "     VERIFICACAO DE SPOOF" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  $border" -ForegroundColor Cyan
    
    Show-Section "ESTADO INICIAL (Antes do Spoof)"
    
    Write-Host "  MAC Address:" -ForegroundColor Yellow
    foreach ($mac in $script:initialState.MACs) {
        Write-Host "    $mac" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "  IP Address:" -ForegroundColor Yellow
    foreach ($ip in $script:initialState.IPs) {
        Write-Host "    $ip" -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "  TPM 2.0:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($script:initialState.TPM)" -ForegroundColor DarkGray
    
    Write-Host "  HVCI:       " -NoNewline -ForegroundColor Yellow
    Write-Host "$($script:initialState.HVCI)" -ForegroundColor DarkGray
    
    Show-Section "ESTADO ATUAL (Apos Spoof)"
    
    Write-Host "  Coletando dados atuais..." -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 1000
    
    $currentNetwork = Get-NetworkInfo
    $currentTPM = Get-TPMStatus
    $currentHVCI = Get-HVCIStatus
    
    Write-Host "`r$(' ' * 80)`r" -NoNewline
    
    Write-Host "  MAC Address:" -ForegroundColor Yellow
    foreach ($mac in $currentNetwork.MACs) {
        $macValue = $mac.Split(": ")[1]
        $originalMAC = ($script:initialState.MACs | Where-Object { $_ -match $mac.Split(":")[0] }) -replace ".*: ", ""
        
        if ($macValue -ne $originalMAC) {
            Write-Host "    $mac " -NoNewline -ForegroundColor Green
            Write-Host "[ALTERADO]" -ForegroundColor Green
        } else {
            Write-Host "    $mac " -NoNewline -ForegroundColor Red
            Write-Host "[IGUAL]" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "  IP Address:" -ForegroundColor Yellow
    foreach ($ip in $currentNetwork.IPs) {
        $ipValue = $ip.Split(": ")[1]
        $originalIP = ($script:initialState.IPs | Where-Object { $_ -match $ip.Split(":")[0] }) -replace ".*: ", ""
        
        if ($ipValue -ne $originalIP) {
            Write-Host "    $ip " -NoNewline -ForegroundColor Green
            Write-Host "[ALTERADO]" -ForegroundColor Green
        } else {
            Write-Host "    $ip " -NoNewline -ForegroundColor DarkGray
            Write-Host "[IGUAL]" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    Write-Host "  TPM 2.0:    " -NoNewline -ForegroundColor Yellow
    Write-Host "$($currentTPM.Detail) " -NoNewline -ForegroundColor DarkGray
    if ($currentTPM.Detail -eq $script:initialState.TPM) {
        Write-Host "[IGUAL]" -ForegroundColor DarkGray
    } else {
        Write-Host "[ALTERADO]" -ForegroundColor Yellow
    }
    
    Write-Host "  HVCI:       " -NoNewline -ForegroundColor Yellow
    Write-Host "$($currentHVCI.Detail) " -NoNewline -ForegroundColor DarkGray
    if ($currentHVCI.Detail -eq $script:initialState.HVCI) {
        Write-Host "[IGUAL]" -ForegroundColor DarkGray
    } else {
        Write-Host "[ALTERADO]" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "  $border" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "  Pressione qualquer tecla para voltar ao menu..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ==================== INICIO DO SCRIPT ====================

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

# ==================== INFORMACOES DO SISTEMA ====================

Show-Section "INFORMACOES DO SISTEMA"

$networkInfo = Show-Spinner -Text "Coletando informacoes de rede..." -Action {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    $result = @{ MACs = @(); IPs = @() }
    
    foreach ($adapter in $adapters) {
        $result.MACs += "$($adapter.Name): $($adapter.MacAddress)"
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($ipConfig) {
            $result.IPs += "$($adapter.Name): $($ipConfig.IPAddress)"
        }
    }
    return $result
} -MinDuration 1500 -MaxDuration 2500

$script:initialState.MACs = $networkInfo.MACs
$script:initialState.IPs = $networkInfo.IPs

foreach ($mac in $networkInfo.MACs) {
    Show-CheckItem -Name "MAC Address" -Status "INFO" -Detail $mac
}

foreach ($ip in $networkInfo.IPs) {
    Show-CheckItem -Name "IP Address" -Status "INFO" -Detail $ip
}

# ==================== VERIFICACAO DE SEGURANCA ====================

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

$script:initialState.TPM = $tpmResult.Detail

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

$script:initialState.HVCI = $hvciResult.Detail

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
Write-Host "`r$(' ' * 80)`r" -NoNewline

if ($checks.Hypervisor.Status -eq "OK" -and $checks.HVCI.Status -eq "OK") {
    $checks.VBS.Status = "OK"
    Show-CheckItem -Name "VBS (Virtualization-Based Security)" -Status "OK" -Detail "Hypervisor + HVCI"
} else {
    $checks.VBS.Status = "ALERTA"
    Show-CheckItem -Name "VBS (Virtualization-Based Security)" -Status "ALERTA" -Detail "Incompleto"
}

# ==================== FIX AUTOMATICO ====================

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

# ==================== RESUMO ====================

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

# ==================== LOOP DO MENU ====================

$continueMenu = $true

while ($continueMenu) {
    Show-Menu
    $choice = Read-Host
    
    switch ($choice) {
        "1" {
            if (Show-SpoofWarning) {
                Show-SpoofVerification
            }
        }
        "2" {
            $continueMenu = $false
            Write-Host ""
            Write-Host "  Saindo..." -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 500
        }
        default {
            Write-Host ""
            Write-Host "  Opcao invalida!" -ForegroundColor Red
            Start-Sleep -Milliseconds 1000
        }
    }
}

Write-Host ""
Write-Host "  Obrigado por usar o Windows Security Tool!" -ForegroundColor Cyan
Write-Host ""
