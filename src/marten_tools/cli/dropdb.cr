# Drop PostgreSQL database defined in Marten settings.
# FR: Supprime la base de données PostgreSQL définie dans les paramètres Marten.
class MartenTools::DropDb < Marten::CLI::Command
  command_name :dropdb
  help "Drop the PostgreSQL database defined in Marten settings."

  def run
    db_config = fetch_db_config

    db_name = db_config.name.to_s
    db_host = db_config.host.to_s
    db_port = db_config.port || 5432
    db_user = db_config.user.to_s
    db_pass = db_config.password.to_s

    # Safety check in production.
    # FR: Vérification de sécurité en production.
    if Marten.env == "production"
      STDOUT.print(style("WARNING: You are about to drop ", fore: :red, mode: :bold) +
                   style(db_name, fore: :white, mode: :bold) +
                   style(" in PRODUCTION. Type the database name to confirm: ", fore: :red, mode: :bold))
      confirmation = STDIN.gets.try(&.strip)
      unless confirmation == db_name
        print(style("  Aborted.", fore: :yellow))
        return
      end
    end

    # FR: Suppression de la base de données...
    print(style("Dropping database ", fore: :cyan) +
          style(db_name, fore: :white, mode: :bold) +
          style(" ...", fore: :cyan))

    conn_string = "postgres://#{URI.encode_path_segment(db_user)}:#{URI.encode_path_segment(db_pass)}@#{db_host}:#{db_port}/postgres"

    DB.open(conn_string) do |db|
      exists = db.query_one(
        "SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1)",
        db_name,
        as: Bool
      )

      unless exists
        # FR: La base n'existe pas.
        print(style("  Database ", fore: :yellow) +
              style(db_name, fore: :white, mode: :bold) +
              style(" does not exist.", fore: :yellow))
        return
      end

      # Terminate active connections before dropping.
      # FR: Fermer les connexions actives avant de supprimer.
      db.exec(<<-SQL, db_name)
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = $1 AND pid <> pg_backend_pid()
      SQL

      db.exec("DROP DATABASE \"#{db_name}\"")
      # FR: Base supprimée.
      print(style("  Dropped: ", fore: :green) +
            style(db_name, fore: :white, mode: :bold))
    end
  rescue ex
    print_error_and_exit("Cannot drop database: #{ex.message}")
  end

  private def fetch_db_config
    db_config = Marten.settings.databases.find { |d| d.id == "default" }
    unless db_config
      print_error_and_exit("No 'default' database connection found in Marten settings.")
    end
    db_config.not_nil!
  end
end
