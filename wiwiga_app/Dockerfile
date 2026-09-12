# ==================================
# WIWIGA - Dockerfile Frontend Flutter Web
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Stage 1: Build Flutter Web
# Stage 2: Serve with Nginx

# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copier les fichiers de dépendances
COPY pubspec.yaml ./

# Installer les dépendances
RUN flutter pub get

# Copier le reste du code
COPY . .

# Build pour le web en mode production
# FLUTTER_WEB_CANVASKIT_URL=canvaskit/ : CanvasKit servi par nginx (local)
# au lieu du CDN Google (www.gstatic.com), inaccessible derrière certains
# réseaux/VPN (ERR_QUIC_PROTOCOL_ERROR). Le dossier build/web/canvaskit/
# est fourni par le SDK (cible WebBuiltInAssets).
# Clés Firebase/VAPID : clientes PUBLIQUES (embarquées dans le bundle JS
# de toute façon), surchargeables via --build-arg.
ARG FIREBASE_API_KEY=AIzaSyCxPkfsemAaXeyHQ4FlclNn7OHfdVoCyRk
ARG FIREBASE_AUTH_DOMAIN=wiwiga-d9a7e.firebaseapp.com
ARG FIREBASE_PROJECT_ID=wiwiga-d9a7e
ARG FIREBASE_SENDER_ID=660834792043
ARG FIREBASE_APP_ID=1:660834792043:web:c2737e7e778f743333f72e
ARG FCM_VAPID_KEY=BEgSTIDMIisP3WrsNPY6GxCTiag_e5qcEZyZ3k6-j5ipo35TUUmjoBs7E8Xgh2T7V9hPLRRgDsLkSdVFTH3dmaE
ARG FLUTTER_WEB_CANVASKIT_URL=canvaskit/
RUN FIREBASE_API_KEY=${FIREBASE_API_KEY} \
    FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN} \
    FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
    FIREBASE_SENDER_ID=${FIREBASE_SENDER_ID} \
    FIREBASE_APP_ID=${FIREBASE_APP_ID} \
    ./tool/setup-fcm-web.sh
RUN flutter build web --release --dart2js-optimization=O4 \
  --dart-define=FLUTTER_WEB_CANVASKIT_URL=${FLUTTER_WEB_CANVASKIT_URL} \
  --dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY} \
  --dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN} \
  --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
  --dart-define=FIREBASE_SENDER_ID=${FIREBASE_SENDER_ID} \
  --dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID} \
  --dart-define=FCM_VAPID_KEY=${FCM_VAPID_KEY}

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Supprimer la config par défaut de nginx
RUN rm -rf /usr/share/nginx/html/*

# Copier les fichiers buildés
COPY --from=build /app/build/web /usr/share/nginx/html

# Copier la config nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exposer le port 80
EXPOSE 80

# Démarrer nginx
CMD ["nginx", "-g", "daemon off;"]
