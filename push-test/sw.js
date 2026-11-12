const TEST_SCOPE_PATH = new URL(self.registration.scope).pathname;

function safeTestUrl(value) {
  try {
    const candidate = new URL(value || TEST_SCOPE_PATH, self.location.origin);
    if (candidate.origin === self.location.origin && candidate.pathname === TEST_SCOPE_PATH) {
      return candidate.href;
    }
  } catch (_) {}
  return new URL(TEST_SCOPE_PATH, self.location.origin).href;
}

self.addEventListener('push', event => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) {}

  const title = typeof data.title === 'string' && data.title ? data.title : 'SRK ELECTRONIC';
  const offerId = typeof data.offerId === 'string' ? data.offerId : null;

  event.waitUntil(self.registration.showNotification(title, {
    body: typeof data.body === 'string' ? data.body : 'आपके लिए नया काम आया है।',
    icon: '/icon.svg',
    badge: '/icon.svg',
    tag: offerId ? 'srk-offer-' + offerId : 'srk-test-notification',
    renotify: true,
    data: { url: safeTestUrl(data.url), offerId }
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = safeTestUrl(event.notification.data?.url);

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const testWindow = windows.find(client => {
      try {
        const url = new URL(client.url);
        return url.origin === self.location.origin && url.pathname === TEST_SCOPE_PATH;
      } catch (_) {
        return false;
      }
    });

    if (testWindow) {
      if ('navigate' in testWindow) await testWindow.navigate(target);
      return testWindow.focus();
    }
    return self.clients.openWindow(target);
  })());
});
