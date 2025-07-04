# MATLAB MCP Bridge

Un bridge proxy che consente a Claude Code (Ubuntu) di accedere al server MATLAB MCP su Windows tramite SSH tunnel.

## Architettura

```
Claude Code (Ubuntu) → MCP Bridge Proxy (Ubuntu:8085) → SSH Tunnel → MATLAB MCP (Windows)
```

## Stato Attuale

✅ **Implementato:**
- Bridge proxy funzionante su porta 8085
- Supporto HTTP/SSE per MCP protocol
- Modalità simulazione per test
- Configurazione Claude Code aggiornata
- Script di test e avvio

⏳ **In sospeso:**
- Connessione SSH al Windows <IP_ADDRESS> (da configurare)
- Integrazione real-time con MATLAB server

## Setup Rapido

### 1. Avvio Bridge (Modalità Simulazione)

```bash
cd <PROJECT_PATH>
./start.sh
```

### 2. Test Funzionalità

```bash
npm test
```

### 3. Verifica Claude Code

Il bridge è già configurato in `.claude.json`:

```json
"matlab-server": {
  "type": "sse",
  "url": "http://localhost:8085/sse"
}
```

## Setup Windows MATLAB Server

### Prerequisiti Windows

1. **SSH Server** installato e configurato
2. **MATLAB** installato (esempio: `<MATLAB_DRIVE>:\MATLAB\bin\matlab.exe`)
3. **MATLAB MCP Server** installato in `C:\Users\%USERNAME%\matlab-mcp-server`
4. **Node.js** installato
5. **Firewall** configurato per permettere SSH

### Avvio MATLAB Server (Windows)

#### Script PowerShell Avanzato (Consigliato)

**⚠️ Richiede privilegi Amministratore**

```powershell
# Setup completo con installazione automatica e servizio Windows
# Esegui PowerShell come Amministratore
.\start-matlab-server.ps1 -InstallService

# Setup manuale (senza servizio)
.\start-matlab-server.ps1

# Reinstallazione forzata
.\start-matlab-server.ps1 -ForceReinstall -InstallService

# Con percorso MATLAB personalizzato
.\start-matlab-server.ps1 -MatlabPath "<MATLAB_PATH>" -InstallService

# Rimozione servizio
.\start-matlab-server.ps1 -UninstallService
```

**✨ Funzionalità Script Avanzato:**
- 🔄 **Auto-installazione** Git, Node.js, MATLAB MCP Server
- 🔧 **Windows Service** con avvio automatico al boot
- 🎯 **Rilevamento automatico** percorso MATLAB
- ✅ **Gestione completa** installazione, avvio, rimozione
- 🛡️ **Controlli sicurezza** privilegi amministratore

#### Gestione Servizio Windows

```powershell
# Comandi servizio Windows
Start-Service -Name "MatlabMCPServer"
Stop-Service -Name "MatlabMCPServer"  
Get-Service -Name "MatlabMCPServer"
```

#### Opzione Manuale
```cmd
# Imposta variabile ambiente
set MATLAB_PATH=<MATLAB_DRIVE>:\MATLAB\bin\matlab.exe

# Naviga alla directory del server
cd C:\Users\%USERNAME%\matlab-mcp-server

# Avvia il server
node build\index.js
```

### Configurazione SSH Windows

1. **Installa OpenSSH Server:**
   ```powershell
   Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
   ```

2. **Configura e avvia SSH:**
   ```powershell
   Start-Service sshd
   Set-Service -Name sshd -StartupType 'Automatic'
   ```

3. **Configura firewall:**
   ```powershell
   netsh advfirewall firewall add rule name="OpenSSH Port 22" dir=in action=allow protocol=TCP localport=22
   ```

4. **Configura chiavi SSH:**
   ```powershell
   # Crea directory .ssh
   mkdir C:\Users\%USERNAME%\.ssh
   
   # Per utenti amministratori, usa:
   mkdir C:\ProgramData\ssh
   # E copia la chiave pubblica in:
   # C:\ProgramData\ssh\administrators_authorized_keys
   ```

### Test Connettività (Ubuntu)

```bash
# Test connettività di base
./connect-matlab.sh

# Test SSH manuale
ssh -i ~/.ssh/matlab_key <USERNAME>@<WINDOWS_IP_ADDRESS> "echo 'Connected successfully'"

# Test tunnel SSH
ssh -L 8086:localhost:3000 <USERNAME>@<WINDOWS_IP_ADDRESS>
```

## Struttura Progetto

```
/<PROJECT_PATH>/
├── server.js              # Bridge proxy principale
├── package.json            # Dipendenze Node.js
├── test.js                # Suite di test
├── start.sh               # Script di avvio
├── connect-matlab.sh      # Script connessione SSH
├── .env.example           # Configurazione esempio
├── bridge.log             # Log operativo
└── README.md              # Documentazione
```

## Configurazione

### Variabili Ambiente (.env)

```bash
PORT=8085
MATLAB_HOST=<WINDOWS_IP_ADDRESS>
MATLAB_SSH_PORT=22
MATLAB_SSH_USER=<USERNAME>
MATLAB_SSH_PASSWORD=        # Optional
MATLAB_SSH_KEY_PATH=        # Preferito
```

### Tool MATLAB Disponibili

Il bridge espone i seguenti tool MATLAB:

1. **matlab_execute** - Esegue codice MATLAB
2. **matlab_script** - Genera script MATLAB
3. Altri tool specifici del server originale

## Troubleshooting

### Windows Non Raggiungibile

```bash
# Verifica connettività
ping <WINDOWS_IP_ADDRESS>

# Verifica porta SSH
nc -z <WINDOWS_IP_ADDRESS> 22
```

### Bridge Non Risponde

```bash
# Verifica processo
ps aux | grep "node server.js"

# Verifica porta
ss -tulpn | grep :8095

# Restart bridge
pkill -f "node server.js"
./start.sh
```

### Claude Code Non Riconosce

1. Riavvia Claude Code
2. Verifica configurazione `.claude.json`
3. Controlla log bridge

## Test

### Test Automatici

```bash
npm test
```

### Test Manuali

```bash
# Health check
curl http://localhost:8085/health

# SSE endpoint
curl -N http://localhost:8085/sse

# MCP request
curl -X POST http://localhost:8085/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":"test"}'
```

## Logging

I log sono disponibili in:
- `bridge.log` - Log bridge proxy
- Console output - Log real-time

## Prossimi Passi

1. Configurare SSH server su Windows
2. Testare connessione SSH tunnel
3. Modificare bridge per connessione real-time
4. Implementare error handling avanzato
5. Aggiungere monitoring e auto-restart

## Sicurezza

- Usare chiavi SSH invece di password
- Configurare firewall appropriatamente
- Validare input MCP
- Monitorare accessi

## Supporto

Per problemi o miglioramenti, verificare:
1. Log di sistema
2. Connettività di rete
3. Configurazione SSH
4. Stato processi MATLAB