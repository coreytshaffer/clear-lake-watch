const STATIC_CACHE = "clear-lake-watch-static-v2";
const DATA_CACHE = "clear-lake-watch-data-v2";
const STATIC_ASSETS = [
  "./",
  "./index.html",
  "./project.html",
  "./methodology.html",
  "./styles.css",
  "./app.js",
  "./manifest.webmanifest",
  "./assets/clear-lake-watch.ico",
  "./assets/clear-lake-watch-icon-192.png",
  "./assets/clear-lake-watch-icon-512.png",
  "./assets/apple-touch-icon.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(STATIC_ASSETS)),
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => ![STATIC_CACHE, DATA_CACHE].includes(key))
          .map((key) => caches.delete(key)),
      ),
    ),
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const { request } = event;

  if (request.method !== "GET") {
    return;
  }

  const url = new URL(request.url);

  if (url.origin !== self.location.origin) {
    return;
  }

  const isDataRequest =
    url.pathname.includes("/data/") || url.pathname.endsWith(".json");
  const cacheName = isDataRequest ? DATA_CACHE : STATIC_CACHE;

  event.respondWith(
    (async () => {
      try {
        const response = await fetch(request);

        if (response?.ok) {
          const cache = await caches.open(cacheName);
          cache.put(request, response.clone());
        }

        return response;
      } catch (error) {
        const cachedResponse = await caches.match(request);

        if (cachedResponse) {
          return cachedResponse;
        }

        if (request.mode === "navigate") {
          const fallbackDocument = await caches.match("./index.html");

          if (fallbackDocument) {
            return fallbackDocument;
          }
        }

        throw error;
      }
    })(),
  );
});
