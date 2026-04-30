'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {
  "version.json": "1",
  "index.html": "1",
  "/": "1"
};

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(cacheName) {
      return Promise.all(
        cacheName.map(function(name) {
          return caches.delete(name);
        })
      );
    })
  );
});

self.addEventListener('fetch', function(event) {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    caches.match(event.request).then(function(response) {
      return response || fetch(event.request);
    })
  );
});
