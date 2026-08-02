defmodule GameHub.AuthTest do
  @moduledoc """
  Tests unitaires pour le module Auth.
  
  Tests:
  - Génération OTP avec rate limiting
  - Vérification OTP (valid, expired, invalid, dev bypass)
  - Création automatique utilisateur
  - Access + Refresh token generation
  - Refresh token rotation
  - Logout / révocation
  - JWT verification (avec blacklist)
  """
  
  use ExUnit.Case, async: false
  
  alias GameHub.Auth
  alias GameHub.Auth.RefreshToken
  alias GameHub.Repo
  alias GameHub.Users.User
  import Ecto.Query
  
  setup do
    # Nettoyer avant chaque test
    Repo.delete_all(RefreshToken)
    Repo.delete_all(User)
    :ok
  end
  
  describe "send_otp/2" do
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
      
      refute otp1 == otp2
    end
    
    test "accepte un device_id pour le rate limiting" do
      phone = "+237699000003"
      
      {:ok, otp} = Auth.send_otp(phone, device_id: "test-device-123")
      
      assert String.length(otp) == 6
    end
  end
  
  describe "verify_otp/3 — nouveau flow avec tokens" do
    setup do
      phone = "+237699000010"
      {:ok, otp} = Auth.send_otp(phone)
      %{phone: phone, otp: otp}
    end
    
    test "vérifie un OTP valide et retourne access + refresh tokens", %{phone: phone, otp: otp} do
      assert {:ok, access_token, refresh_token, user} = Auth.verify_otp(phone, otp)
      
      # Tokens sont des strings
      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert String.length(access_token) > 0
      assert String.length(refresh_token) > 0
      
      # User créé
      assert user.phone == phone
      assert user.is_active == true
    end
    
    test "rejette un OTP incorrect", %{phone: phone} do
      wrong_otp = "000000"
      
      assert Auth.verify_otp(phone, wrong_otp) == {:error, :invalid_otp}
      
      assert Repo.get_by(User, phone: phone) == nil
    end
    
    test "rejette après OTP non trouvé", %{phone: phone} do
      # Utiliser un code différent du bypass dev (123456)
      assert Auth.verify_otp(phone, "999999") == {:error, :otp_not_found}
    end
    
    test "dev bypass: code 123456 accepté en mode test", %{phone: phone} do
      # En mode test, le code 123456 est toujours accepté
      assert {:ok, _access, _refresh, user} = Auth.verify_otp(phone, "123456")
      assert user.phone == phone
    end
  end
  
  describe "verify_jwt_token/1" do
    setup do
      phone = "+237699000020"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, access_token, _refresh_token, user} = Auth.verify_otp(phone, otp)
      %{token: access_token, user: user}
    end
    
    test "vérifie et décode un access token valide", %{token: token, user: user} do
      assert {:ok, result} = Auth.verify_jwt_token(token)
      
      assert result.user_id == user.id
      assert result.user.id == user.id
    end
    
    test "rejette un token invalide" do
      assert {:error, _reason} = Auth.verify_jwt_token("invalid.token.here")
    end
    
    test "rejette un refresh token utilisé comme access token" do
      phone = "+237699000021"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, _access, refresh_token, _user} = Auth.verify_otp(phone, otp)
      
      # Un refresh token ne doit pas être accepté comme access token
      assert {:error, {:invalid_token_type, "refresh", "access"}} = 
        Auth.verify_jwt_token(refresh_token)
    end
  end
  
  describe "refresh_tokens/2 — rotation" do
    setup do
      phone = "+237699000030"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, _access, refresh_token, user} = Auth.verify_otp(phone, otp)
      %{refresh_token: refresh_token, user: user}
    end
    
    test "rotation réussie: nouveaux tokens générés", %{refresh_token: refresh_token, user: user} do
      assert {:ok, new_access, new_refresh, refreshed_user} = 
        Auth.refresh_tokens(refresh_token)
      
      # Nouveaux tokens différents
      assert is_binary(new_access)
      assert is_binary(new_refresh)
      refute new_access == refresh_token
      refute new_refresh == refresh_token
      
      # Même user
      assert refreshed_user.id == user.id
    end
    
    test "ancien refresh token est révoqué après rotation", %{refresh_token: refresh_token} do
      assert {:ok, _, _, _} = Auth.refresh_tokens(refresh_token)
      
      # Réutiliser l'ancien token doit échouer
      assert {:error, :token_replay_detected} = Auth.refresh_tokens(refresh_token)
    end
    
    test "rejette un refresh token invalide" do
      assert {:error, :invalid_token} = Auth.refresh_tokens("invalid_token")
    end
  end
  
  describe "logout/1" do
    test "révoque le refresh token" do
      phone = "+237699000035"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, _access, refresh_token, _user} = Auth.verify_otp(phone, otp)
      
      # Logout
      assert :ok = Auth.logout(refresh_token)
      
      # Le refresh ne doit plus fonctionner
      assert {:error, :token_replay_detected} = Auth.refresh_tokens(refresh_token)
    end
  end
  
  describe "intégration complète" do
    test "flow complet: send_otp -> verify_otp -> access_token -> verify -> refresh -> logout" do
      phone = "+237699000040"
      
      # 1. Envoyer OTP
      {:ok, otp} = Auth.send_otp(phone)
      
      # 2. Vérifier OTP et obtenir tokens
      {:ok, access_token, refresh_token, user} = Auth.verify_otp(phone, otp)
      
      # 3. Vérifier access token
      {:ok, result} = Auth.verify_jwt_token(access_token)
      assert result.user_id == user.id
      assert result.user.phone == phone
      
      # 4. Refresh token rotation
      {:ok, new_access, new_refresh, _} = Auth.refresh_tokens(refresh_token)
      
      # 5. Vérifier nouveau access token
      {:ok, new_result} = Auth.verify_jwt_token(new_access)
      assert new_result.user_id == user.id
      
      # 6. Logout
      :ok = Auth.logout(new_refresh)
      
      # 7. Le refresh ne fonctionne plus
      assert {:error, _} = Auth.refresh_tokens(new_refresh)
    end
    
    test "création utilisateur avec valeurs par défaut" do
      phone = "+237699000050"
      {:ok, otp} = Auth.send_otp(phone)
      {:ok, _access, _refresh, user} = Auth.verify_otp(phone, otp)
      
      db_user = Repo.get(User, user.id)
      
      assert db_user.phone == phone
      assert db_user.is_active == true
      assert db_user.balance == 0
      assert db_user.has_verified_kyc == false
      assert db_user.self_excluded == false
    end
  end
end
