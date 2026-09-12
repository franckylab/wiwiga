/* ============================================================
 * WIWIGA — Service Worker Firebase Messaging (Web Push)
 * Généré par tool/setup-fcm-web.sh — ne pas éditer à la main.
 * Sans configuration réelle : l'initialisation échoue silencieusement
 * et l'inbox in_app + WebSocket prennent le relais.
 * Requiert au build : --dart-define=FCM_VAPID_KEY=<clé VAPID>
 * (Console Firebase → Cloud Messaging → Web Push certificates).
 * ============================================================ */
importScripts(
  'https://www.gstatic.com/firebasejs/12.18.0/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/12.18.0/firebase-messaging-compat.js'
);

try {
  firebase.initializeApp({
    apiKey: 'AIzaSyCxPkfsemAaXeyHQ4FlclNn7OHfdVoCyRk',
    authDomain: 'wiwiga-d9a7e.firebaseapp.com',
    projectId: 'wiwiga-d9a7e',
    messagingSenderId: '660834792043',
    appId: '1:660834792043:web:c2737e7e778f743333f72e',
  });

  const messaging = firebase.messaging();

  // Mise à jour immédiate : sans skipWaiting, un SW mis à jour reste en
  // "waiting" tant qu'un onglet est ouvert (l'utilisateur croit avoir
  // rechargé la nouvelle version, mais l'ancien SW tourne encore).
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (event) => {
    event.waitUntil(self.clients.claim());
  });

  // Background / onglet fermé : affichage EXPLICITE (ne pas compter sur
  // l'auto-display du SDK). Tag anti-doublon (notification_id backend),
  // data conservée pour le tap → inbox. Les icônes DOIVENT exister
  // (404 => Chrome abandonne la notification en silence).
  messaging.onBackgroundMessage((payload) => {
    const notification = payload.notification || {};
    const data = payload.data || {};
    const title = notification.title || data.title || 'WIWIGA';
    console.log('[FCM-SW] background:', title, JSON.stringify(data));
    const options = {
      body: notification.body || data.body || '',
      icon: '/android-chrome-192x192.png',
      badge: '/favicon-32x32.png',
      tag: data.notification_id || ('wiwiga-' + Date.now()),
      renotify: true,
      data: data,
    };
    return self.registration.showNotification(title, options);
  });

  // Tap : focus la fenêtre existante (évite les doublons d'onglets),
  // sinon ouvre l'inbox.
  self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const target =
      (event.notification.data && event.notification.data.url) ||
      '/#/notifications';
    event.waitUntil(
      clients
        .matchAll({ type: 'window', includeUncontrolled: true })
        .then((wins) => {
          for (const win of wins) {
            if ('focus' in win) {
              try {
                win.navigate(target);
              } catch (_) {}
              return win.focus();
            }
          }
          if (clients.openWindow) return clients.openWindow(target);
        })
        .catch(() => undefined)
    );
  });
} catch (_) {
  // Config absente : pas de push web, comportement normal
}
