# ==================================
# WIWIGA - Module Avatars
# ==================================
# Module: GameHub.Users.Avatars
# Description: Gestion des avatars prédéfinis WIWIGA

defmodule GameHub.Users.Avatars do
  @moduledoc """
  Module de gestion des avatars prédéfinis WIWIGA.
  
  Les avatars sont des SVG stockés dans priv/static/avatars/.
  Chaque avatar a un thème gaming/néon unique.
  
  ## Avatars disponibles
  
  - `default` — Avatar par défaut (cercle avec initiales)
  - `wiwiga_1` — Casque Gaming
  - `wiwiga_2` — Manette Néon
  - `wiwiga_3` — Dé Chanceux
  - `wiwiga_4` — Champion
  - `wiwiga_5` — Robot
  - `wiwiga_6` — Dragon
  - `wiwiga_7` — Phoenix
  - `wiwiga_8` — Étoile
  """
  
  @avatar_dir "priv/static/avatars"
  
  @avatars [
    %{
      type: "default",
      name: "Avatar par défaut",
      description: "Avatar standard WIWIGA",
      color: "#00FF88",
      file: "default.svg"
    },
    %{
      type: "wiwiga_1",
      name: "Casque Gaming",
      description: "Casque gaming néon avec micro",
      color: "#FF00FF",
      file: "wiwiga_1.svg"
    },
    %{
      type: "wiwiga_2",
      name: "Manette Néon",
      description: "Manette de jeu lumineuse",
      color: "#00FFFF",
      file: "wiwiga_2.svg"
    },
    %{
      type: "wiwiga_3",
      name: "Dé Chanceux",
      description: "Dé à jouer stylisé",
      color: "#FFFF00",
      file: "wiwiga_3.svg"
    },
    %{
      type: "wiwiga_4",
      name: "Champion",
      description: "Couronne de champion",
      color: "#FFD700",
      file: "wiwiga_4.svg"
    },
    %{
      type: "wiwiga_5",
      name: "Robot",
      description: "Robot futuriste",
      color: "#00FF00",
      file: "wiwiga_5.svg"
    },
    %{
      type: "wiwiga_6",
      name: "Dragon",
      description: "Dragon gaming",
      color: "#FF4400",
      file: "wiwiga_6.svg"
    },
    %{
      type: "wiwiga_7",
      name: "Phoenix",
      description: "Phenix de feu",
      color: "#FF6600",
      file: "wiwiga_7.svg"
    },
    %{
      type: "wiwiga_8",
      name: "Étoile",
      description: "Étoile brillante",
      color: "#AA00FF",
      file: "wiwiga_8.svg"
    }
  ]
  
  @doc """
  Retourne la liste de tous les avatars disponibles.
  """
  def list do
    @avatars
  end
  
  @doc """
  Retourne les informations d'un avatar par son type.
  """
  def get(type) do
    Enum.find(@avatars, fn a -> a.type == type end)
  end
  
  @doc """
  Retourne le type d'avatar par défaut.
  """
  def default_type, do: "default"
  
  @doc """
  Vérifie si un type d'avatar est valide.
  """
  def valid?(type) do
    Enum.any?(@avatars, fn a -> a.type == type end)
  end
  
  @doc """
  Retourne l'URL publique d'un avatar.
  """
  def url(type) do
    case get(type) do
      nil -> "/avatars/default.svg"
      avatar -> "/avatars/#{avatar.file}"
    end
  end
  
  @doc """
  Retourne la couleur associée à un avatar.
  """
  def color(type) do
    case get(type) do
      nil -> "#00FF88"
      avatar -> avatar.color
    end
  end
  
  @doc """
  Génère les initiales d'un utilisateur pour l'avatar par défaut.
  """
  def initials(%{username: username}) when is_binary(username) and username != "" do
    username
    |> String.replace(~r/[^a-zA-Z0-9]/, "")
    |> String.upcase()
    |> String.slice(0, 2)
  end
  
  def initials(%{name: name}) when is_binary(name) and name != "" do
    name
    |> String.split()
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
    |> String.slice(0, 2)
  end
  
  def initials(_), do: "??"
end
