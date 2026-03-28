import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = 6006;

app.use(cors());
app.use(express.json());

// API routes placeholder
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', app: 'ZenVoyage' });
});

// Serve Flutter Web static files
const flutterBuildPath = path.join(__dirname, '../../app/build/web');
app.use(express.static(flutterBuildPath));

// Fallback to Flutter index.html
app.get('*', (_req, res) => {
  res.sendFile(path.join(flutterBuildPath, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`🚀 ZenVoyage server running on http://localhost:${PORT}`);
});
