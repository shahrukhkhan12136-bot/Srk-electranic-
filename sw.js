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

self.addEventListener('push',event=>{
  let data={title:'SRK ELECTRONIC',body:'आपके लिए नई बुकिंग आई है।',action:'open'};
  try{if(event.data)data={...data,...event.data.json()};}catch(_e){}
  event.waitUntil((async()=>{
    if(data.action==='close'&&data.offerId){
      const notes=await self.registration.getNotifications({tag:'srk-offer-'+data.offerId});
      notes.forEach(note=>note.close());
      return;
    }
    await self.registration.showNotification(data.title||'SRK ELECTRONIC',{
      body:data.body||'आपके लिए नई बुकिंग आई है।',
      icon:'./icon.svg',
      badge:'./icon.svg',
      tag:data.offerId?'srk-offer-'+data.offerId:'srk-booking-alert',
      renotify:true,
      requireInteraction:true,
      vibrate:[500,250,500,250,900],
      data:{url:'./electrician.html',offerId:data.offerId||null}
    });
  })());
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  const target=new URL(event.notification.data?.url||'./electrician.html',self.location.origin).href;
  event.waitUntil((async()=>{
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for(const client of windows){
      if('focus' in client){await client.focus();if('navigate' in client)await client.navigate(target);return;}
    }
    if(self.clients.openWindow)await self.clients.openWindow(target);
  })());
});
