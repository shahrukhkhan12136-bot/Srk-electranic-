/* Dedicated service worker for the isolated SRK ELECTRONIC push-test page. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));
self.addEventListener('push', (event) => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; }
  catch (_) { data = { body: event.data ? event.data.text() : '' }; }
  const title = data.title || 'SRK ELECTRONIC — TEST';
  const options = {
    body: data.body || data.message || 'यह TEST Push Notification है।',
    icon: '../icon.svg',
    badge: '../icon.svg',
    tag: data.tag || 'srk-electronic-push-test',
    data: { url: data.url || (data.offerId ? './offer.html?offerId=' + encodeURIComponent(data.offerId) : './') },
    requireInteraction: true
  };
  event.waitUntil(self.registration.showNotification(title, options));
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || './', self.location.href).href;
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      if ('focus' in client) {
        await client.focus();
        if ('navigate' in client && client.url !== target) await client.navigate(target);
        return;
      }
    }
    if (self.clients.openWindow) await self.clients.openWindow(target);
  })());
});
