'use strict';

// Service worker de mise en cache de l'app shell (PWA hors-ligne).
//
// Depuis Flutter 3.x, le service worker généré automatiquement
// (flutter_service_worker.js) est un stub qui se désinscrit lui-même — la
// mise en cache "app shell" n'est plus fournie par l'outillage Flutter
// (voir https://github.com/flutter/flutter/issues/156910). Ce fichier la
// réimplémente : au premier chargement, il met en cache le shell (HTML, JS,
// polices, manifeste, icônes) puis sert tout depuis le cache en priorité —
// l'app démarre instantanément même sans réseau, avant que Drift ne prenne
// le relais pour les données.
//
// Remplacé automatiquement par le SHA du commit à chaque déploiement CI (voir
// .github/workflows/deploy.yml) pour invalider le cache de l'app shell à
// chaque nouvelle version — jusqu'ici resté figé sur 'dev' sur tous les
// déploiements précédents, ce qui pouvait servir une version périmée aux
// visiteurs déjà passés sur le site.
const CACHE_VERSION = 'dev';
const CACHE_NAME = `vertical-app-shell-${CACHE_VERSION}`;

const APP_SHELL = [
  './',
  'index.html',
  'main.dart.js',
  'flutter.js',
  'flutter_bootstrap.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  );
});

// Cache d'abord (démarrage instantané / hors-ligne), avec rafraîchissement en
// tâche de fond (stale-while-revalidate) pour rester à jour sur les visites
// suivantes. Les appels à l'API backend (autre origine) ne sont jamais mis en
// cache : seule la couche Drift gère le hors-ligne pour les données.
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;

  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(request);
      const network = fetch(request)
        .then((response) => {
          if (response.ok) cache.put(request, response.clone());
          return response;
        })
        .catch(() => cached);
      return cached || network;
    }),
  );
});
