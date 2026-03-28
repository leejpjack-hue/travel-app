console.log('Current working directory:', process.cwd());
console.log('__dirname:', __dirname);
console.log('Data directory path:', __dirname + '/data');

const fs = require('fs');
const path = require('path');

const dataDir = path.join(__dirname, 'data');
console.log('Data directory exists:', fs.existsSync(dataDir));

if (!fs.existsSync(dataDir)) {
  console.log('Creating data directory...');
  fs.mkdirSync(dataDir, { recursive: true });
}

const dbPath = path.join(dataDir, 'travel.db');
console.log('Database path:', dbPath);
console.log('Database file exists:', fs.existsSync(dbPath));