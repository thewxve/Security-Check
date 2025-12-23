# ==============================
# SECURITY CHECK & AUTO FIX
# Windows 10 22H2 / Windows 11 23H2
# ==============================

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CHECKLIST DE SEGURANÇA DO SISTEMA" -ForegroundColor Cyan
Write-Host "========================================`n"

# ==============================
# VERIFICA ADMIN
# ==============================
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "[ERRO] Execute este script como ADMINISTRADOR." -ForegroundColor Red
    Write-Host "Clique com o botão direito no PowerShell e selecione 'Executar como administrador'."
    Pause
    exit
}

Write-Host "[OK] Script executado como Administrador`n" -ForegroundColor Green

# ==============================
# DETECTA WINDOWS
# ==============================
$os = Get-CimInstance Win32_OperatingSystem
$version = $os.Version
$caption = $os.Caption

Write-Host "[INFO] Sistema detectado: $caption ($version)`n" -ForegroundColor Yellow

# ==============================
# TPM
# ==============================
try {
    $tpm = Get-Tpm
    if ($tpm.TpmPresent -and $tpm.TpmReady) {
        Write-Host "[OK] TPM presente e pronto" -ForegroundColor Green
    } else {
        Write-Host "[ERRO] TPM ausente ou não pronto" -ForegroundColor Red
    }
} catch {
    Write-Host "[ERRO] TPM não encontrado" -ForegroundColor Red
}

# ==============================
# SECURE BOOT / UEFI
# ==============================
try {
    if (Confirm-SecureBootUEFI) {
        Write-Host "[OK] Secure Boot ATIVADO" -ForegroundColor Green
    } else {
        Write-Host "[ERRO] Secure Boot DESATIVADO" -ForegroundColor Red
    }
} catch {
    Write-Host "[ERRO] Secure Boot não suportado (Legacy BIOS)" -ForegroundColor Red
}

$biosMode = (Get-ComputerInfo).BiosFirmwareType
if ($biosMode -eq "Uefi") {
    Write-Host "[OK] Sistema em UEFI" -ForegroundColor Green
} else {
    Write-Host "[ERRO] Sistema em Legacy / CSM" -ForegroundColor Red
}

# ==============================
# VIRTUALIZAÇÃO
# ==============================
$virt = (Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled
if ($virt) {
    Write-Host "[OK] Virtualização ATIVADA na BIOS" -ForegroundColor Green
} else {
    Write-Host "[ERRO] Virtualização DESATIVADA na BIOS" -ForegroundColor Red
}

# ==============================
# HYPERVISOR
# ==============================
$hypervisorAuto = $false
$bcd = bcdedit | Select-String "hypervisorlaunchtype"
if ($bcd -match "Auto") {
    $hypervisorAuto = $true
    Write-Host "[OK] Hypervisor configurado para AUTO" -ForegroundColor Green
} else {
    Write-Host "[ERRO] Hypervisor DESATIVADO" -ForegroundColor Red
}

# ==============================
# HVCI
# ==============================
$hvciKey = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
$hvciEnabled = $false

if (Test-Path $hvciKey) {
    $hvci = Get-ItemProperty $hvciKey
    if ($hvci.Enabled -eq 1) {
        $hvciEnabled = $true
        Write-Host "[OK] HVCI (Integridade da Memória) ATIVO" -ForegroundColor Green
    } else {
        Write-Host "[ERRO] HVCI DESATIVADO" -ForegroundColor Red
    }
} else {
    Write-Host "[ERRO] HVCI não configurado no sistema" -ForegroundColor Red
}

# ==============================
# VBS / DEVICE GUARD
# ==============================
$vbs = Get-CimInstance -ClassName Win32_DeviceGuard
if ($vbs.SecurityServicesRunning -contains 1) {
    Write-Host "[OK] VBS / Device Guard EM EXECUÇÃO" -ForegroundColor Green
} else {
    Write-Host "[ERRO] VBS / Device Guard DESATIVADO" -ForegroundColor Red
}

# ==============================
# AUTO FIX
# ==============================
if (-not $hvciEnabled -or -not $hypervisorAuto) {

    Write-Host "`n[FIX] Aplicando correções automaticamente..." -ForegroundColor Yellow

    # Ativa Hypervisor
    bcdedit /set hypervisorlaunchtype auto | Out-Null

    # Ativa HVCI
    if (-not (Test-Path $hvciKey)) {
        New-Item -Path $hvciKey -Force | Out-Null
    }

    Set-ItemProperty -Path $hvciKey -Name "Enabled" -Value 1 -Type DWord
    Set-ItemProperty -Path $hvciKey -Name "Locked" -Value 0 -Type DWord

    Write-Host "[OK] Hypervisor configurado" -ForegroundColor Green
    Write-Host "[OK] HVCI configurado" -ForegroundColor Green

    Write-Host "`n⚠️ É NECESSÁRIO REINICIAR O PC para concluir a ativação." -ForegroundColor Cyan
    Pause
    exit
}

# ==============================
# FINAL
# ==============================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " SISTEMA TOTALMENTE COMPATÍVEL" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Pause
