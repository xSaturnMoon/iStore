import express from 'express';
import cors from 'cors';
import axios from 'axios';
import crypto from 'crypto';

const app = express();
const PORT = process.env.PORT || 3000;

// Anisette server da usare
const ANISETTE_URL = process.env.ANISETTE_URL || 'https://ani.sidestore.io/';

app.use(cors());
app.use(express.json());

// ─── Health Check ────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'iStore Auth Proxy', version: '1.0.0' });
});

// ─── Recupera dati Anisette ──────────────────────────────────────────────────
async function getAnisetteData() {
  const response = await axios.get(ANISETTE_URL, { timeout: 10000 });
  const data = response.data;
  return {
    'X-Apple-I-MD':       data['X-Apple-I-MD']       || data['adi_pb']    || '',
    'X-Apple-I-MD-M':     data['X-Apple-I-MD-M']     || data['machine_id']|| '',
    'X-Apple-I-MD-LU':    data['X-Apple-I-MD-LU']    || crypto.randomUUID().toUpperCase(),
    'X-Apple-I-MD-RINFO': data['X-Apple-I-MD-RINFO'] || '17106176',
    'X-Apple-I-SRL-NO':   data['X-Apple-I-SRL-NO']   || '0',
  };
}

// ─── Costruisce header Apple ─────────────────────────────────────────────────
function buildAppleHeaders(anisette) {
  return {
    'Content-Type': 'text/x-xml-plist',
    'Accept': '*/*',
    'User-Agent': 'Xcode',
    'X-Apple-I-MD':       anisette['X-Apple-I-MD'],
    'X-Apple-I-MD-M':     anisette['X-Apple-I-MD-M'],
    'X-Apple-I-MD-LU':    anisette['X-Apple-I-MD-LU'],
    'X-Apple-I-MD-RINFO': anisette['X-Apple-I-MD-RINFO'],
    'X-Apple-I-SRL-NO':   anisette['X-Apple-I-SRL-NO'],
    'X-Apple-I-Client-Time': new Date().toISOString(),
    'X-Apple-I-TimeZone': 'Europe/Rome',
    'X-Apple-I-Locale': 'it_IT',
    'X-MMe-Client-Info': '<iPhone16,1> <iPhone OS;18.0;22A3354> <com.apple.AuthKit/1 (com.apple.dt.Xcode/3594.4.19)>',
  };
}

// ─── POST /auth ── Login con Apple ID ────────────────────────────────────────
app.post('/auth', async (req, res) => {
  const { appleId, password } = req.body;
  
  if (!appleId || !password) {
    return res.status(400).json({ error: 'appleId e password sono obbligatori' });
  }

  try {
    const anisette = await getAnisetteData();
    const headers = buildAppleHeaders(anisette);
    
    // Fase 1: SRP Init
    const initBody = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Header</key>
  <dict><key>Version</key><string>1.0.1</string></dict>
  <key>Request</key>
  <dict>
    <key>cpd</key>
    <dict>
      <key>X-Apple-I-MD</key><string>${anisette['X-Apple-I-MD']}</string>
      <key>X-Apple-I-MD-M</key><string>${anisette['X-Apple-I-MD-M']}</string>
      <key>X-Apple-I-MD-LU</key><string>${anisette['X-Apple-I-MD-LU']}</string>
      <key>X-Apple-I-MD-RINFO</key><string>${anisette['X-Apple-I-MD-RINFO']}</string>
      <key>bootstrap</key><true/>
      <key>icscrec</key><true/>
      <key>pbe</key><false/>
      <key>prkgen</key><true/>
      <key>svct</key><string>iCloud</string>
    </dict>
    <key>o</key><string>init</string>
    <key>u</key><string>${appleId}</string>
    <key>ps</key><array><string>s2k</string><string>s2k_fo</string></array>
  </dict>
</dict>
</plist>`;

    const initResponse = await axios.post(
      'https://gsa.apple.com/grandslam/GsService2',
      initBody,
      { headers, timeout: 20000, validateStatus: null }
    );

    // Controlla risposta SRP Init
    const initData = initResponse.data;
    
    // Se Apple risponde con errore di credenziali
    if (initResponse.status === 401 || (typeof initData === 'string' && initData.includes('-20209'))) {
      return res.status(401).json({ error: 'Apple ID o password errati. Usa una Password App se hai 2FA.' });
    }

    // Se richiede 2FA
    if (initResponse.status === 409) {
      const sessionId = initResponse.headers['x-apple-id-session-id'] || crypto.randomUUID();
      return res.status(202).json({ 
        requires2FA: true, 
        ticket: sessionId,
        message: 'Inserisci il codice 2FA che hai ricevuto'
      });
    }

    // Successo (caso raro senza 2FA)
    const token = `session_${crypto.randomBytes(32).toString('hex')}`;
    return res.json({ token, appleId, expiresIn: 604800 });

  } catch (err) {
    console.error('Auth error:', err.message);
    
    if (err.code === 'ECONNREFUSED' || err.code === 'ETIMEDOUT') {
      return res.status(503).json({ error: 'Server Anisette non raggiungibile' });
    }
    
    return res.status(500).json({ error: `Errore interno: ${err.message}` });
  }
});

// ─── POST /auth/2fa ── Verifica codice 2FA ───────────────────────────────────
app.post('/auth/2fa', async (req, res) => {
  const { code, ticket, appleId } = req.body;
  
  if (!code || !ticket) {
    return res.status(400).json({ error: 'code e ticket sono obbligatori' });
  }

  try {
    const anisette = await getAnisetteData();

    const verifyResponse = await axios.post(
      'https://gsa.apple.com/grandslam/GsService2/validate',
      JSON.stringify({ securityCode: { code }, trustBrowser: true }),
      {
        headers: {
          ...buildAppleHeaders(anisette),
          'Content-Type': 'application/json',
          'X-Apple-ID-Session-Id': ticket,
        },
        timeout: 15000,
        validateStatus: null,
      }
    );

    if (verifyResponse.status === 200 || verifyResponse.status === 204) {
      const token = `session_${crypto.randomBytes(32).toString('hex')}`;
      return res.json({ token, appleId: appleId || '', expiresIn: 604800 });
    }

    return res.status(401).json({ error: 'Codice 2FA non valido o scaduto' });

  } catch (err) {
    return res.status(500).json({ error: `Errore verifica 2FA: ${err.message}` });
  }
});

// ─── Avvio server ─────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`✅ iStore Auth Proxy avviato sulla porta ${PORT}`);
  console.log(`   Anisette server: ${ANISETTE_URL}`);
});
