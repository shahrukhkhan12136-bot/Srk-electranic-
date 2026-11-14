const CACHE='srk-electronic-v5';
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
  event.waitUntil((async()=>{
    let payload={};
    try{payload=event.data?event.data.json():{};}catch{payload={body:event.data?.text()||''};}
    const title=typeof payload.title==='string'&&payload.title?payload.title:'SRK ELECTRONIC';
    const body=typeof payload.body==='string'?payload.body:'आपके अकाउंट के लिए नई सूचना है।';
    const offerId=typeof payload.offerId==='string'?payload.offerId:'';
    const options={body,icon:'./icon.svg',badge:'./icon.svg',tag:offerId?'srk-offer-'+offerId:'srk-general',renotify:!!offerId,data:{url:typeof payload.url==='string'?payload.url:'./electrician.html',offerId,action:payload.action||'open'}};
    await self.registration.showNotification(title,options);
  })());
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const raw=event.notification.data?.url||'./electrician.html';
    let target=new URL('./electrician.html',self.location.origin);
    try{const candidate=new URL(raw,self.location.origin);if(candidate.origin===self.location.origin)target=candidate;}catch{}
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for(const client of windows){if(new URL(client.url).origin===self.location.origin){await client.navigate(target.href);return client.focus();}}
    return self.clients.openWindow(target.href);
  })());
});
