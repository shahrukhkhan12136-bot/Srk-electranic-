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
  let payload={};
  try{payload=event.data?event.data.json():{};}catch(_){payload={body:event.data?event.data.text():'आपके लिए नया अपडेट उपलब्ध है।'};}
  const title=typeof payload.title==='string'&&payload.title.trim()?payload.title.trim():'SRK ELECTRONIC';
  const options={
    body:typeof payload.body==='string'?payload.body:'आपके लिए नया काम या अपडेट उपलब्ध है।',
    icon:'/icon.svg',
    badge:'/icon.svg',
    tag:typeof payload.tag==='string'?payload.tag:'srk-electrician-update',
    data:{url:typeof payload.url==='string'?payload.url:'/electrician.html'}
  };
  event.waitUntil(self.registration.showNotification(title,options));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  const requested=event.notification.data&&event.notification.data.url;
  let target='/electrician.html';
  try{const parsed=new URL(typeof requested==='string'?requested:'/electrician.html',self.location.origin);if(parsed.origin===self.location.origin)target=parsed.href;}catch(_){}
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(windows=>{
    for(const client of windows){if(new URL(client.url).origin===self.location.origin){if('focus'in client){client.navigate(target);return client.focus();}}}
    return clients.openWindow(target);
  }));
});
