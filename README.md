# 🔐 Security Checklist & Auto Fix (Windows)

Script de suporte para verificar e corrigir automaticamente
os requisitos de segurança necessários para funcionamento
dos softwares.

## ✅ Compatibilidade
- Windows 10 22H2
- Windows 11 23H2

## 🔍 O que o script verifica
- TPM
- Secure Boot
- UEFI / Legacy
- Virtualização (BIOS)
- Hypervisor
- HVCI (Integridade da Memória)
- VBS / Device Guard

## 🛠️ Auto Fix
Se o **Hypervisor** ou o **HVCI** estiverem desativados, o script:
- Ativa automaticamente
- Solicita reinicialização do PC

## ▶️ Como executar (1 linha)
Abra o **PowerShell como Administrador** e execute:

powershell -ep bypass -c "irm https://raw.githubusercontent.com/thewxve/Security-Check/main/security-check-fix.ps1 | iex"

# ⚠️ Importante

- O script não coleta dados
- Nenhuma informação é enviada para servidores
- Todas as alterações são locais
- Algumas correções exigem reinicialização
