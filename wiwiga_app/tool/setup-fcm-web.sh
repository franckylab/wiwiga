#!/usr/bin/env bash
# ============================================================
# WIWIGA — Génère web/firebase-messaging-sw.js depuis l'env
# Usage: FIREBASE_API_KEY=... FIREBASE_AUTH_DOMAIN=... \
#        FIREBASE_PROJECT_ID=... FIREBASE_SENDER_ID=... \
#        FIREBASE_APP_ID=... ./tool/setup-fcm-web.sh
# Sans variables : placeholders conservés (push web désactivé,
# inbox in_app + WebSocket en repli). Idempotent.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
SW_FILE="$APP_DIR/web/firebase-messaging-sw.js"

API_KEY="${FIREBASE_API_KEY:-FIREBASE_API_KEY}"
AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-FIREBASE_AUTH_DOMAIN}"
PROJECT_ID="${FIREBASE_PROJECT_ID:-FIREBASE_PROJECT_ID}"
SENDER_ID="${FIREBASE_SENDER_ID:-FIREBASE_SENDER_ID}"
APP_ID="${FIREBASE_APP_ID:-FIREBASE_APP_ID}"
# Version du SDK JS Firebase : DOIT correspondre à celle injectée par les
# packages Dart (firebase_core_web.supportedFirebaseJsSdkVersion, ex.
# 12.18.0 pour firebase_messaging 16.6.0). Un écart majeur casse le
# protocole page <-> Service Worker (getToken échoue).
JS_SDK_VERSION="${FIREBASE_JS_SDK_VERSION:-12.18.0}"

cat > "$SW_FILE" <<EOF
/* ============================================================
 * WIWIGA — Service Worker Firebase Messaging (Web Push)
 * Généré par tool/setup-fcm-web.sh — ne pas éditer à la main.
 * Sans configuration réelle : l'initialisation échoue silencieusement
 * et l'inbox in_app + WebSocket prennent le relais.
 * Requiert au build : --dart-define=FCM_VAPID_KEY=<clé VAPID>
 * (Console Firebase → Cloud Messaging → Web Push certificates).
 * ============================================================ */
importScripts(
  'https://www.gstatic.com/firebasejs/${JS_SDK_VERSION}/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/${JS_SDK_VERSION}/firebase-messaging-compat.js'
);

try {
  firebase.initializeApp({
    apiKey: '${API_KEY}',
    authDomain: '${AUTH_DOMAIN}',
    projectId: '${PROJECT_ID}',
    messagingSenderId: '${SENDER_ID}',
    appId: '${APP_ID}',
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
EOF

echo "[WIWIGA] Service worker FCM généré : $SW_FILE (project=$PROJECT_ID)"
