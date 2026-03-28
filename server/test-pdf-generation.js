const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

// Create temporary directory
const tempDir = path.join(__dirname, 'temp');
if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir, { recursive: true });
}

const pdfPath = path.join(tempDir, `test-pdf-${Date.now()}.pdf`);
const doc = new PDFDocument({
  size: 'A4',
  margin: 50,
  bufferPages: true
});

// Create write stream
const stream = fs.createWriteStream(pdfPath);
doc.pipe(stream);

// Add content
doc.fontSize(28).fillColor('#e74c3c').text('ZenVoyage', 0, 30, { align: 'center' });
doc.fontSize(20).fillColor('#2c3e50').text('旅遊手冊', 0, 60, { align: 'center' });
doc.fontSize(16).fillColor('#7f8c8d').text(`生成時間: ${new Date().toLocaleString('zh-TW')}`, 0, 90, { align: 'center' });
doc.addPage();

doc.fontSize(18).fillColor('#2c3e50').text('測試行程', 0, 50);
doc.fontSize(12).fillColor('#7f8c8d').text('這是一個測試PDF文件', 0, 80);

// Finalize PDF
doc.end();

// Wait for PDF to be created
stream.on('finish', () => {
  console.log(`PDF created successfully: ${pdfPath}`);
  console.log(`File size: ${fs.statSync(pdfPath).size} bytes`);
  
  // Clean up
  fs.unlink(pdfPath, (err) => {
    if (err) {
      console.error('Failed to delete temporary PDF:', err);
    } else {
      console.log('Temporary PDF cleaned up');
    }
  });
});

stream.on('error', (err) => {
  console.error('PDF generation error:', err);
});