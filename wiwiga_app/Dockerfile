# ==================================
# WIWIGA - Dockerfile Frontend Flutter Web
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Stage 1: Build Flutter Web
# Stage 2: Serve with Nginx

# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:3.27.0 AS build

WORKDIR /app

# Copier les fichiers de dépendances
COPY pubspec.yaml ./

# Installer les dépendances
RUN flutter pub get

# Copier le reste du code
COPY . .

# Build pour le web en mode debug (plus rapide pour le dev)
RUN flutter build web --release

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
# ==================================
# WIWIGA - Dockerfile Frontend Flutter Web
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Stage 1: Build Flutter Web
# Stage 2: Serve with Nginx

# Stage 1: Build
FROM ghcr.io/cirruslabs/flutter:3.27.0 AS build

WORKDIR /app

# Copier les fichiers de dépendances
COPY pubspec.yaml ./

# Installer les dépendances
RUN flutter pub get

# Copier le reste du code
COPY . .

# Build pour le web en mode production
RUN flutter build web --release --dart2js-optimization=O4

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
