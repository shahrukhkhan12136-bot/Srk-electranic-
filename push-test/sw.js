self.addEventListener('install', event => { self.skipWaiting(); });
self.addEventListener('activate', event => { event.waitUntil(self.clients.claim()); });
self.addEventListener('push', event => {
  let data = {title:'SRK ELECTRONIC TEST', body:'यह TEST बुकिंग अलर्ट है।', offerId:'test'};
  try { if (event.data) data = {...data, ...event.data.json()}; } catch (_) {}
  event.waitUntil((async () => {
    if (data.action === 'close' && data.offerId) {
      const items = await self.registration.getNotifications({tag:'srk-offer-' + data.offerId});
      items.forEach(item => item.close());
      return;
    }
    await self.registration.showNotification(data.title, {
      body:data.body, tag:'srk-offer-' + (data.offerId || 'test'),
      renotify:true, requireInteraction:true, vibrate:[500,250,500,250,900],
      icon:'../icon.svg', badge:'../icon.svg',
      data:{url:'./'}
    });
  })());
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({type:'window', includeUncontrolled:true});
    for (const client of windows) { if ('focus' in client) { await client.focus(); return; } }
    if (self.clients.openWindow) await self.clients.openWindow('./');
  })());
});