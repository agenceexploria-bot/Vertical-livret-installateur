// Script ponctuel : rasterise assets/images/Vertical.svg en PNG haute
// résolution, puis génère src/lib/verticalLogoPng.ts (bytes encodés en
// base64) pour que le logo soit embarqué dans le bundle serverless sans
// dépendre du file-tracing de Vercel sur un fichier binaire externe.
// Usage : npm install --no-save sharp && node scripts/render-logo.mjs
import sharp from 'sharp';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const svgPath = path.join(__dirname, '../../assets/images/Vertical.svg');
const pngOutPath = path.join(__dirname, '../assets/vertical-logo.png');
const tsOutPath = path.join(__dirname, '../src/lib/verticalLogoPng.ts');

const svg = readFileSync(svgPath);
const png = await sharp(svg, { density: 288 }).resize(1000, 700, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toBuffer();

mkdirSync(path.dirname(pngOutPath), { recursive: true });
writeFileSync(pngOutPath, png);

const base64 = png.toString('base64');
writeFileSync(
  tsOutPath,
  `// Généré par backend/scripts/render-logo.mjs à partir de assets/images/Vertical.svg\n` +
    `// (pdf-lib ne sait embarquer que PNG/JPEG, jamais SVG) — pour régénérer après une\n` +
    `// mise à jour du logo, relancer le script. Voir backend/assets/vertical-logo.png\n` +
    `// pour la version fichier, utilisée seulement comme référence visuelle.\n` +
    `export const VERTICAL_LOGO_PNG_BASE64 =\n  '${base64}';\n`,
);

console.log(`PNG: ${png.byteLength} bytes -> ${pngOutPath}`);
console.log(`TS module -> ${tsOutPath}`);
