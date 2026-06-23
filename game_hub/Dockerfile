FROM elixir:1.16-otp-26

# Installer dependencies système
RUN apt-get update && apt-get install -y \
    inotify-tools \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Working directory
WORKDIR /app

# Installer dependencies Hex
RUN mix local.hex --force && \
    mix local.rebar --force

# Copier fichiers de dépendances d'abord (pour le cache Docker)
COPY mix.exs mix.lock* ./
COPY apps/game_hub/mix.exs apps/game_hub/
COPY apps/game_hub_web/mix.exs apps/game_hub_web/
COPY apps/dice_game/mix.exs apps/dice_game/

# Télécharger et compiler les dépendances
RUN mix deps.get
RUN mix deps.compile

# Copier le reste du code
COPY config config/
COPY priv priv/
COPY apps apps/

# Compiler l'application
RUN mix compile

# Exposer ports
EXPOSE 4000

# Commande par défaut
CMD ["mix", "phx.server"]
