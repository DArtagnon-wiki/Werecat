// Retires the old offline service worker.
//
// Earlier builds shipped Godot's PWA service worker, which serves the game
// cache-first and only updates once every tab of the site has closed. On
// Android Chrome tabs survive restarts, so players got stuck on an old build.
// Offline mode is now off. Browsers re-check this script on every visit, so
// any phone still running the old worker installs this one instead: it takes
// over immediately, deletes the cached copies, reloads the page from the
// network, and unregisters itself.
self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		await self.clients.claim();
		const keys = await caches.keys();
		await Promise.all(keys.map((k) => caches.delete(k)));
		const windows = await self.clients.matchAll({ type: 'window' });
		await self.registration.unregister();
		for (const w of windows) {
			try { w.navigate(w.url); } catch (e) { /* tab may be gone */ }
		}
	})());
});
