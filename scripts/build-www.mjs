// 把网页文件复制到 www/，供 Capacitor 打进 iOS 应用。网页本身仍以仓库根目录为准（GitHub Pages 也用它）。
import { rmSync, mkdirSync, cpSync } from 'node:fs';
rmSync('www', { recursive: true, force: true });
mkdirSync('www');
for (const f of ['index.html', 'manifest.webmanifest']) cpSync(f, `www/${f}`);
cpSync('icons', 'www/icons', { recursive: true });
console.log('www/ ready');
