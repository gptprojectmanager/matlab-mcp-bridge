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
- Connessione SSH al Windows 192.168.1.111 (non raggiungibile)
- Integrazione real-time con MATLAB server

## Setup Rapido

### 1. Avvio Bridge (Modalità Simulazione)

```bash
cd /home/sam/matlab-mcp-bridge
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

## Connessione al MATLAB Server Windows

### Prerequisiti Windows

1. **SSH Server** installato e configurato
2. **MATLAB MCP Server** in esecuzione:
   ```cmd
   node C:/Users/samue/matlab-mcp-server/build/index.js
   ```
3. **Firewall** configurato per permettere SSH

### Comando di Connessione

```bash
# Test connettività
./connect-matlab.sh

# Connessione SSH manuale
ssh -L 8086:localhost:3000 samue@192.168.1.111
```

## Struttura Progetto

```
/home/sam/matlab-mcp-bridge/
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
MATLAB_HOST=192.168.1.111
MATLAB_SSH_PORT=22
MATLAB_SSH_USER=samue
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
ping 192.168.1.111

# Verifica porta SSH
nc -z 192.168.1.111 22
```

### Bridge Non Risponde

```bash
# Verifica processo
ps aux | grep "node server.js"

# Verifica porta
ss -tulpn | grep :8085

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