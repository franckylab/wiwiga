#!/bin/bash
# ==================================
# WIWIGA - Script Installation Elixir/Phoenix
# ==================================
# Description: Installe automatiquement Elixir, Erlang et dépendances
# Utilisation: sudo bash install-elixir.sh

set -e

echo "🚀 ==========================================="
echo "   WIWIGA - Installation Elixir/Phoenix"
echo "==========================================="
echo ""

# Détecter OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ Impossible de détecter l'OS"
    exit 1
fi

echo "📊 OS détecté: $OS"
echo ""

# Installation selon OS
case $OS in
    ubuntu|debian)
        echo "📦 Installation pour Ubuntu/Debian..."
        
        # Installer Erlang
        echo "🔧 1. Installation Erlang..."
        sudo apt update
        sudo apt install -y erlang-dev erlang-parsetools erlang-xmerl
        
        # Installer Elixir
        echo "🔧 2. Installation Elixir..."
        sudo apt install -y elixir
        
        # Installer outils supplémentaires
        echo "🔧 3. Installation outils..."
        sudo apt install -y inotify-tools
        ;;
    
    arch|manjaro)
        echo "📦 Installation pour Arch Linux/Manjaro..."
        
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm elixir erlang inotify-tools
        ;;
    
    fedora)
        echo "📦 Installation pour Fedora..."
        
        sudo dnf install -y erlang elixir inotify-tools
        ;;
    
    *)
        echo "❌ OS non supporté: $OS"
        echo "   Veuillez installer Elixir manuellement:"
        echo "   https://elixir-lang.org/install.html"
        exit 1
        ;;
esac

# Vérifier installation
echo ""
echo "✅ Vérification installation..."

if command -v elixir &> /dev/null; then
    ELIXIR_VERSION=$(elixir --version | head -1)
    echo "✅ Elixir: $ELIXIR_VERSION"
else
    echo "❌ Elixir non installé"
    exit 1
fi

if command -v erl &> /dev/null; then
    ERLANG_VERSION=$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)
    echo "✅ Erlang/OTP: $ERLANG_VERSION"
else
    echo "❌ Erlang non installé"
    exit 1
fi

if command -v mix &> /dev/null; then
    echo "✅ Mix: Installé"
else
    echo "❌ Mix non installé"
    exit 1
fi

# Installer Hex et Rebar
echo ""
echo "📦 Installation Hex et Rebar..."
mix local.hex --force
mix local.rebar --force

# Installer dépendances projet
echo ""
echo "📦 Installation dépendances projet..."
cd game_hub
mix deps.get

echo ""
echo "✅ ==========================================="
echo "   Installation terminée!"
echo "==========================================="
echo ""
echo "🚀 Prochaines étapes:"
echo "   1. cd game_hub"
echo "   2. mix compile"
echo "   3. mix ecto.create"
echo "   4. mix ecto.migrate"
echo "   5. mix run priv/repo/seeds.exs"
echo "   6. mix phx.server"
echo ""
