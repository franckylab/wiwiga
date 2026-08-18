# Script pour réinitialiser les mots de passe
# Démarrer les applications nécessaires manuellement
{:ok, _} = Application.ensure_all_started(:ecto)
{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = GameHub.Repo.start_link()
{:ok, _} = Application.ensure_all_started(:pbkdf2_elixir)

require Ecto.Query
alias GameHub.Repo
alias GameHub.Users.User

hash = Pbkdf2.hash_pwd_salt("Admin123!")

# Reset tous les utilisateurs connus
for id <- [1, 3, 5, 6, 7] do
  query = Ecto.Query.from(u in User, where: u.id == ^id)
  Repo.update_all(query, set: [password_hash: hash])
  IO.puts("User #{id} password reset OK")
end

IO.puts("\nAll passwords reset to 'Admin123!'")
System.halt(0)
