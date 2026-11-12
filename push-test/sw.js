self.addEventListener('push', event => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) {}

  const title = typeof data.title === 'string' && data.title ? data.title : 'SRK ELECTRONIC';
  const offerId = typeof data.offerId === 'string' ? data.offerId : null;
  let safeUrl = '/electrician.html';

  try {
    const candidate = new URL(data.url || safeUrl, self.location.origin);
    if (candidate.origin === self.location.origin && candidate.pathname === '/electrician.html') {
      safeUrl = candidate.pathname + candidate.search;
    }
  } catch (_) {}

  event.waitUntil(self.registration.showNotification(title, {
    body: typeof data.body === 'string' ? data.body : 'आपके लिए नया काम आया है।',
    icon: '/icon.svg',
    badge: '/icon.svg',
    tag: offerId ? 'srk-offer-' + offerId : 'srk-test-notification',
    renotify: true,
    data: { url: safeUrl, offerId }
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  let target = self.location.origin + '/electrician.html';

  try {
    const candidate = new URL(event.notification.data?.url || '/electrician.html', self.location.origin);
    if (candidate.origin === self.location.origin && candidate.pathname === '/electrician.html') {
      target = candidate.href;
    }
  } catch (_) {}

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const dashboard = windows.find(client => {
      try {
        const url = new URL(client.url);
        return url.origin === self.location.origin && url.pathname === '/electrician.html';
      } catch (_) {
        return false;
      }
    });

    if (dashboard) {
      if ('navigate' in dashboard) await dashboard.navigate(target);
      return dashboard.focus();
    }
    return self.clients.openWindow(target);
  })());
});
