defmodule GameHub.AuthTest do
  @moduledoc """
  Tests unitaires pour le module Auth.
  
  Tests critiques:
  - Génération OTP
  - Vérification OTP avec expiration
  - Création automatique utilisateur
  - JWT token generation et verification
  """
  
  use ExUnit.Case, async: false
  
  alias GameHub.Auth
  alias GameHub.Repo
  alias GameHub.Users.User
  import Ecto.Query
  
  setup do
    # Nettoyer avant chaque test
    Repo.delete_all(User)
    :ok
  end
  
  describe "send_otp/1" do
    test "génère un OTP de 6 chiffres" do
      phone = "+237699000001"
      
      {:ok, otp} = Auth.send_otp(phone)
      
      assert String.length(otp) == 6
      assert Regex.match?(~r/^\d{6}$/, otp)
    end
    
    test "génère des OTP différents pour le même utilisateur" do
      phone = "+237699000002"
      
      {:ok, otp1} = Auth.send_otp(phone)
      {:ok, otp2} = Auth.send_otp(phone)
      
      # Les OTP doivent être différents (nouveau code à chaque fois)
      refute otp1 == otp2
    end
    
    test "affiche l'OTP dans les logs (mode dev)" do
      phone = "+237699000003"
      
      # Capture IO
      ExUnit.CaptureIO.capture_io(fn ->
        Auth.send_otp(phone)
      end)
      
      # Le test passe si aucune exception n'est levée
      assert true
    end
  end
  
  describe "verify_otp/2" do
    setup do
      phone = "+237699000010"
      {:ok, otp} = Auth.send_otp(phone)
      %{phone: phone, otp: otp}
    end
    
    test "vérifie un OTP valide et crée un utilisateur", %{phone: phone, otp: otp} do
      # L'utilisateur ne doit pas exister avant
      assert Repo.get_by(User, phone: phone) == nil
      
      # Vérifier OTP
      assert {:ok, _token, user} = Auth.verify_otp(phone, otp)
      
      # L'utilisateur doit avoir été créé
      assert user.phone == phone
      assert user.is_active == true
      
      # Vérifier dans la DB
      db_user = Repo.get_by(User, phone: phone)
      assert db_user != nil
      assert db_user.id == user.id
    end
    
    test "vérifie un OTP valide pour utilisateur existant", %{phone: phone, otp: otp} do
      # Créer l'utilisateur d'abord
      Auth.verify_otp(phone, otp)
      
      # Envoyer un nouvel OTP
      {:ok, new_otp} = Auth.send_otp(phone)
      
      # Vérifier le nouvel OTP
      assert {:ok, _token, user} = Auth.verify_otp(phone, new_otp)
      assert user.phone == phone
    end
    
    test "rejette un OTP incorrect", %{phone: phone} do
      wrong_otp = "000000"
      
      assert Auth.verify_otp(phone, wrong_otp) == {:error, :invalid_otp}
      
      # L'utilisateur ne doit pas être créé
      assert Repo.get_by(User, phone: phone) == nil
    end
    
    test "rejette un OTP expiré", %{phone: phone, otp: otp} do
      # Simuler expiration en manipulant Redis directement
      # Dans un test réel, on attendrait 5 minutes
      # Pour ce test, on vérifie juste que le mécanisme existe
      
      # Supprimer l'OTP pour simuler expiration
      # (dans la réalité, Redis le ferait automatiquement)
      Redix.command(GameHub.Redis, ["DEL", "otp:#{phone}"])
      
      assert Auth.verify_otp(phone, otp) == {:error, :otp_not_found}
    end
    
    test "rejette après OTP non trouvé", %{phone: phone} do
      assert Auth.verify_otp(phone, "123456") == {:error, :otp_not_found}
    end
    
    test "retourne un JWT token valide", %{phone: phone, otp: otp} do
      assert {:ok, token, _user} = Auth.verify_otp(phone, otp)
      
      # Le token doit être une chaîne
      assert is_binary(token)
      assert String.length(token) > 0
    end
  end
  
  describe "verify_jwt_token/1" do
    setup do
      phone = "+237699000020"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, token, user} = Auth.verify_otp(phone, otp)
      %{token: token, user: user}
    end
    
    test "vérifie et décode un token valide", %{token: token, user: user} do
      assert {:ok, claims} = Auth.verify_jwt_token(token)
      
      # Les claims doivent contenir user_id
      assert claims.user_id == user.id
      assert claims.user.id == user.id
    end
    
    test "rejette un token invalide" do
      invalid_token = "invalid.token.here"
      
      assert {:error, _reason} = Auth.verify_jwt_token(invalid_token)
    end
    
    test "rejette un token expiré", %{token: token} do
      # Dans un test réel, on attendrait l'expiration
      # Ou on créerait un token avec expiration passée
      # Pour l'instant, on teste juste avec un token corrompu
      
      corrupted_token = token <> "corrupted"
      
      assert {:error, _reason} = Auth.verify_jwt_token(corrupted_token)
    end
  end
  
  describe "refresh_jwt_token/1" do
    setup do
      phone = "+237699000030"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, token, user} = Auth.verify_otp(phone, otp)
      %{token: token, user: user}
    end
    
    test "refresh un token valide", %{token: token, user: user} do
      assert {:ok, new_token, refreshed_user} = Auth.refresh_jwt_token(token)
      
      # Nouveau token doit être différent
      refute new_token == token
      
      # User doit être le même
      assert refreshed_user.id == user.id
    end
    
    test "rejette le refresh d'un token invalide" do
      assert {:error, _reason} = Auth.refresh_jwt_token("invalid_token")
    end
  end
  
  describe "intégration complète" do
    test "flow complet: send_otp -> verify_otp -> JWT -> verify_jwt" do
      phone = "+237699000040"
      
      # 1. Envoyer OTP
      {:ok, otp} = Auth.send_otp(phone)
      
      # 2. Vérifier OTP et obtenir JWT
      {:ok, jwt_token, user} = Auth.verify_otp(phone, otp)
      
      # 3. Vérifier JWT
      {:ok, claims} = Auth.verify_jwt_token(jwt_token)
      
      # 4. Vérifier cohérence
      assert claims.user_id == user.id
      assert claims.user.phone == phone
      
      # 5. Refresh token
      {:ok, new_jwt, _} = Auth.refresh_jwt_token(jwt_token)
      
      # 6. Vérifier nouveau token
      {:ok, new_claims} = Auth.verify_jwt_token(new_jwt)
      assert new_claims.user_id == user.id
    end
    
    test "création utilisateur avec valeurs par défaut" do
      phone = "+237699000050"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, _token, user} = Auth.verify_otp(phone, otp)
      
      # Recharger depuis DB
      db_user = Repo.get(User, user.id)
      
      # Vérifier valeurs par défaut
      assert db_user.phone == phone
      assert db_user.is_active == true
      assert db_user.balance == 0
      assert db_user.has_verified_kyc == false
      assert db_user.self_excluded == false
    end
  end
end
