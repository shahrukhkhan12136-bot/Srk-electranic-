const CACHE='srk-electronic-v6';
const FILES=['./','./index.html','./manifest.webmanifest','./icon.svg'];

self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES)));
  self.skipWaiting();
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys().then(keys=>Promise.all(
      keys.filter(key=>key!==CACHE).map(key=>caches.delete(key))
    )).then(()=>self.clients.claim())
  );
});

self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET') return;
  const isPage=event.request.mode==='navigate' ||
    new URL(event.request.url).pathname.endsWith('/index.html');
  if(isPage){
    event.respondWith(
      fetch(event.request).then(response=>{
        if(response.ok){
          const copy=response.clone();
          caches.open(CACHE).then(cache=>cache.put(event.request,copy));
        }
        return response;
      }).catch(()=>caches.match(event.request).then(cached=>cached||caches.match('./index.html')))
    );
    return;
  }
  event.respondWith(
    caches.match(event.request).then(cached=>cached||fetch(event.request))
  );
});


self.addEventListener('push', event => {
  let data = {};
  try { data = event.data ? event.data.json() : {}; } catch (_) {}
  const title = data.title || 'SRK ELECTRONIC';
  let safeUrl = '/electrician.html';
  try {
    const candidate = new URL(data.url || '/electrician.html', self.location.origin);
    if (candidate.origin === self.location.origin &&
        candidate.pathname === '/electrician.html') {
      safeUrl = candidate.pathname + candidate.search;
    }
  } catch (_) {}
  const options = {
    body: data.body || 'आपके लिए नया काम आया है।',
    icon: '/icon.svg',
    badge: '/icon.svg',
    tag: data.offerId ? 'srk-offer-' + data.offerId : 'srk-notification',
    renotify: true,
    silent: false,
    vibrate: [400, 180, 400, 180, 700, 300, 400],
    requireInteraction: true,
    data: { url: safeUrl, offerId: data.offerId || null }
  };
  event.waitUntil((async()=>{
    await self.registration.showNotification(title, options);
    // If the electrician dashboard is already open, ask it to play its in-page alert tone.
    const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of clients) {
      try {
        const url = new URL(client.url);
        if (url.origin === self.location.origin && url.pathname.endsWith('/electrician.html')) {
          client.postMessage({ type: 'SRK_NEW_JOB_OFFER', title, body: options.body, offerId: data.offerId || null });
        }
      } catch (_) {}
    }
  })());
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  let target = self.location.origin + '/electrician.html';
  try {
    const candidate = new URL(event.notification.data?.url || '/electrician.html', self.location.origin);
    if (candidate.origin === self.location.origin &&
        candidate.pathname === '/electrician.html') target = candidate.href;
  } catch (_) {}
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    // Reuse only an electrician dashboard tab. Never redirect a customer page.
    const electricianWindow = windows.find(client => {
      try {
        const url = new URL(client.url);
        return url.origin === self.location.origin &&
          (url.pathname.endsWith('/electrician.html') || url.pathname === '/electrician.html');
      } catch (_) {
        return false;
      }
    });
    if (electricianWindow) {
      if ('navigate' in electricianWindow) await electricianWindow.navigate(target);
      return electricianWindow.focus();
    }
    return self.clients.openWindow(target);
  })());
});
