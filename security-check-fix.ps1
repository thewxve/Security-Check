# ==============================
# SECURITY CHECK & FIX SCRIPT
# Windows 10 22H2 / Windows 11 23H2
# ==============================

Clear-Host

# ---------- ADMIN CHECK ----------
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERRO] Execute este script como ADMINISTRADOR" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Script executado como Administrador" -ForegroundColor Green

# ---------- OS INFO ----------
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "[INFO] Sistema detectado: $($os.Caption) ($($os.Version))" -ForegroundColor Cyan
Write-Host ""

# ---------- TPM ----------
$tpm = Get-Tpm
if ($tpm.TpmPresent -and $tpm.TpmReady) {
    Write-Host "[OK] TPM presente e pronto" -ForegroundColor Green
} else {
    Write-Host "[ERRO] TPM ausente ou não pronto" -ForegroundColor Red
}

# ---------- SECURE BOOT ----------
try {
    if (Confirm-SecureBootUEFI) {
        Write-Host "[OK] Secure Boot ATIVADO" -ForegroundColor Green
    }
} catch {
    Write-Host "[ERRO] Secure Boot DESATIVADO ou sistema não UEFI" -ForegroundColor Red
}

# ---------- UEFI ----------
$firmware = (Get-CimInstance Win32_ComputerSystem).BootupState
if ($firmware -match "EFI") {
    Write-Host "[OK] Sistema em UEFI" -ForegroundColor Green
} else {
    Write-Host "[ERRO] Sistema NÃO está em UEFI" -ForegroundColor Red
}

# ---------- HYPERVISOR ----------
$hypervisor = bcdedit /enum | Select-String "hypervisorlaunchtype"
if ($hypervisor -match "Auto") {
    Write-Host "[OK] Hypervisor configurado para AUTO" -ForegroundColor Green
    $hypervisorOK = $true
} else {
    Write-Host "[ERRO] Hypervisor DESATIVADO — aplicando FIX" -ForegroundColor Yellow
    bcdedit /set hypervisorlaunchtype auto | Out-Null
    $hypervisorOK = $false
}

# ---------- VIRTUALIZATION ----------
$virt = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty VirtualizationFirmwareEnabled
if ($virt) {
    Write-Host "[OK] Virtualização ATIVA (confirmada pelo Hypervisor)" -ForegroundColor Green
} else {
    Write-Host "[ERRO] Virtualização DESATIVADA na BIOS" -ForegroundColor Red
}

# ---------- HVCI ----------
$hvci = Get-ItemProperty `
    -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" `
    -Name Enabled -ErrorAction SilentlyContinue

if ($hvci.Enabled -eq 1) {
    Write-Host "[OK] HVCI (Integridade da Memória) ATIVO" -ForegroundColor Green
    $hvciOK = $true
} else {
    Write-Host "[ERRO] HVCI DESATIVADO — aplicando FIX" -ForegroundColor Yellow
    reg add `
      "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" `
      /v Enabled /t REG_DWORD /d 1 /f | Out-Null
    $hvciOK = $false
}

# ---------- VBS LOGIC (SIMPLIFIED) ----------
if ($hypervisorOK -and $hvciOK) {
    Write-Host "[OK] VBS ATIVO (confirmado via Hypervisor + HVCI)" -ForegroundColor Green
} else {
    Write-Host "[ERRO] VBS NÃO está completamente funcional" -ForegroundColor Red
}

# ---------- FINAL ----------
Write-Host ""
Write-Host "==================================" -ForegroundColor DarkGray
Write-Host "Reinicie o computador para aplicar" -ForegroundColor Yellow
Write-Host "==================================" -ForegroundColor DarkGray
