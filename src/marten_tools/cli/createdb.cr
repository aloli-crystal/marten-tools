# Create PostgreSQL database from Marten settings.
# FR: Crée la base de données PostgreSQL définie dans les paramètres Marten.
class MartenTools::CreateDb < Marten::CLI::Command
  command_name :createdb
  help "Create the PostgreSQL database defined in Marten settings."

  def run
    db_config = fetch_db_config

    db_name = db_config.name.to_s
    db_host = db_config.host.to_s
    db_port = db_config.port || 5432
    db_user = db_config.user.to_s
    db_pass = db_config.password.to_s

    # FR: Création de la base de données...
    print(style("Creating database ", fore: :cyan) +
          style(db_name, fore: :white, mode: :bold) +
          style(" ...", fore: :cyan))

    # Connect to the system "postgres" database to create the target database.
    # FR: Se connecter à la base système "postgres" pour créer la base cible.
    conn_string = "postgres://#{URI.encode_path_segment(db_user)}:#{URI.encode_path_segment(db_pass)}@#{db_host}:#{db_port}/postgres"

    DB.open(conn_string) do |db|
      exists = db.query_one(
        "SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1)",
        db_name,
        as: Bool
      )

      if exists
        # FR: La base existe déjà.
        print(style("  Already exists: ", fore: :yellow) +
              style(db_name, fore: :white, mode: :bold))
      else
        db.exec("CREATE DATABASE \"#{db_name}\"")
        # FR: Base créée avec succès.
        print(style("  Created: ", fore: :green) +
              style(db_name, fore: :white, mode: :bold))
      end
    end
  rescue ex
    print_error_and_exit("Cannot create database: #{ex.message}")
  end

  private def fetch_db_config
    db_config = Marten.settings.databases.find { |d| d.id == "default" }
    unless db_config
      print_error_and_exit("No 'default' database connection found in Marten settings.")
    end
    db_config.not_nil!
  end
end
