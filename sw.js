/* Zetoro service worker: halaman utama selalu diambil dari jaringan dulu (supaya update langsung masuk),
   cadangan dari cache kalau offline. Permintaan ke Supabase tidak pernah di-cache. */
const CACHE = 'zetoro-v3';
// Semua path relatif terhadap folder service worker, jadi jalan di root (Netlify) maupun di subfolder (GitHub Pages /Zetoro/)
const BASE = self.registration.scope;
const u = p => new URL(p, BASE).href;
const SHELL = ['./', './index.html', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png', './icons/maskable-512.png', './icons/apple-touch-icon.png'].map(u);

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin && !url.hostname.endsWith('jsdelivr.net')) return; // Supabase dll: langsung ke jaringan
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).then(res => { const copy = res.clone(); caches.open(CACHE).then(c => c.put(u('./index.html'), copy)); return res; })
      .catch(() => caches.match(u('./index.html'))));
    return;
  }
  e.respondWith(caches.match(req).then(hit => {
    const net = fetch(req).then(res => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); } return res; }).catch(() => hit);
    return hit || net;
  }));
});
