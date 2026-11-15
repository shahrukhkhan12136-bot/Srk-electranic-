const CACHE='srk-electronic-v10';
const FILES=['./','./index.html','./welcome.html','./customer-login.html','./booking.html','./electrician.html','./admin.html','./manifest.webmanifest','./icon.svg','./assets/srk-founder.jpg'];

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
    const rawOfferId=typeof payload.offerId==='string'?payload.offerId:'';
    const offerId=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(rawOfferId)?rawOfferId:'';
    const target=new URL('./electrician.html',self.registration.scope);
    if(offerId)target.searchParams.set('offerId',offerId);
    const options={body,icon:'./icon.svg',badge:'./icon.svg',tag:offerId?'srk-offer-'+offerId:'srk-general',renotify:!!offerId,data:{url:target.href,offerId,action:'open'}};
    await self.registration.showNotification(title,options);
  })());
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const target=new URL('./electrician.html',self.registration.scope);
    const offerId=event.notification.data?.offerId;
    if(typeof offerId==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(offerId)){
      target.searchParams.set('offerId',offerId);
    }
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for(const client of windows){if(new URL(client.url).origin===self.location.origin){await client.navigate(target.href);return client.focus();}}
    return self.clients.openWindow(target.href);
  })());
});
