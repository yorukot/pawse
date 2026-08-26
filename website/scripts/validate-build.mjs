import { access, readFile, readdir } from 'node:fs/promises';
import { dirname, extname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const websiteDirectory = dirname(dirname(fileURLToPath(import.meta.url)));
const outputDirectory = join(websiteDirectory, 'dist');
const siteOrigin = 'https://pawse.local';

async function collectFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map((entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory() ? collectFiles(path) : path;
    }),
  );
  return files.flat();
}

async function exists(path) {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

function outputCandidates(pathname) {
  const cleanPath = decodeURIComponent(pathname).replace(/^\/+/, '');
  if (cleanPath === '') return [join(outputDirectory, 'index.html')];
  if (pathname.endsWith('/')) return [join(outputDirectory, cleanPath, 'index.html')];
  if (extname(cleanPath)) return [join(outputDirectory, cleanPath)];
  return [join(outputDirectory, cleanPath), join(outputDirectory, cleanPath, 'index.html')];
}

const files = await collectFiles(outputDirectory);
const htmlFiles = files.filter((file) => file.endsWith('.html'));
const failures = [];

for (const htmlFile of htmlFiles) {
  const html = await readFile(htmlFile, 'utf8');
  const publicPath = `/${relative(outputDirectory, htmlFile).replaceAll('\\', '/')}`;
  const pageURL = new URL(publicPath, siteOrigin);

  for (const match of html.matchAll(/\b(?:href|src)=["']([^"'<>]+)["']/g)) {
    const target = match[1];
    if (
      target.startsWith('#') ||
      target.startsWith('data:') ||
      target.startsWith('mailto:') ||
      target.startsWith('tel:')
    ) {
      continue;
    }

    const targetURL = new URL(target, pageURL);
    if (targetURL.origin !== siteOrigin) continue;

    const candidates = outputCandidates(targetURL.pathname);
    if (!(await Promise.any(candidates.map(async (candidate) => ((await exists(candidate)) ? candidate : Promise.reject()))).catch(() => false))) {
      failures.push(`${publicPath} → ${targetURL.pathname}`);
    }
  }
}

for (const requiredPath of ['release.json', 'sitemap-index.xml', 'robots.txt', 'CNAME']) {
  if (!(await exists(join(outputDirectory, requiredPath)))) failures.push(`missing ${requiredPath}`);
}

if (failures.length > 0) {
  console.error(`Build validation failed:\n${failures.map((failure) => `- ${failure}`).join('\n')}`);
  process.exitCode = 1;
} else {
  console.log(`Validated ${htmlFiles.length} HTML pages and their local links/assets.`);
}
