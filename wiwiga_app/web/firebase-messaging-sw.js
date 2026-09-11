/* ============================================================
 * WIWIGA — Service Worker Firebase Messaging (Web Push)
 * Généré par tool/setup-fcm-web.sh — ne pas éditer à la main.
 * Sans configuration réelle : l'initialisation échoue silencieusement
 * et l'inbox in_app + WebSocket prennent le relais.
 * Requiert au build : --dart-define=FCM_VAPID_KEY=<clé VAPID>
 * (Console Firebase → Cloud Messaging → Web Push certificates).
 * ============================================================ */
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js'
);

try {
  firebase.initializeApp({
    apiKey: 'FIREBASE_API_KEY',
    authDomain: 'wiwiga-d9a7e.firebaseapp.com',
    projectId: 'wiwiga-d9a7e',
    messagingSenderId: '660834792043',
    appId: 'FIREBASE_APP_ID',
  });

  const messaging = firebase.messaging();

  // Clic sur la notification → ouvre l'inbox
  self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(
      clients.openWindow('/#/notifications').catch(() => undefined)
    );
  });
} catch (_) {
  // Config absente : pas de push web, comportement normal
}
