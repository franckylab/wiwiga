# WIWIGA - Dépendances Externes

Ce projet nécessite les dépendances suivantes pour fonctionner :

## Requises

- **PostgreSQL 15+** - Base de données principale
- **Redis 7+** - Cache et matchmaking
- **Elixir 1.15+** - Langage de programmation
- **Erlang/OTP 26+** - Runtime Elixir

## Optionnelles (Docker)

- **Docker 20.10+** - Containerisation
- **Docker Compose V2** - Orchestration multi-container

## Installation

### Via Docker (Recommandé)

```bash
./run-docker.sh
```

### Installation Directe

```bash
# Ubuntu/Debian
sudo bash install-elixir.sh

# Installer PostgreSQL
sudo apt install postgresql

# Installer Redis
sudo apt install redis-server
```

## Vérification

```bash
# Elixir
elixir --version

# Erlang
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

# PostgreSQL
psql --version

# Redis
redis-cli ping

# Docker
docker --version
docker compose version
```

## Configuration

Voir `EXECUTION_GUIDE.md` pour instructions détaillées.
