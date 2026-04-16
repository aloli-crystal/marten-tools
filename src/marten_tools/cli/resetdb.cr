# Reset database: drop, create, and run migrations.
# FR: Réinitialise la base : suppression, création, et migrations.
class MartenTools::ResetDb < Marten::CLI::Command
  command_name :resetdb
  help "Drop, recreate, and migrate the PostgreSQL database (combines dropdb + createdb + migrate)."

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
      STDOUT.print(style("WARNING: You are about to RESET ", fore: :red, mode: :bold) +
                   style(db_name, fore: :white, mode: :bold) +
                   style(" in PRODUCTION. This will DESTROY ALL DATA. Type the database name to confirm: ", fore: :red, mode: :bold))
      confirmation = STDIN.gets.try(&.strip)
      unless confirmation == db_name
        print(style("  Aborted.", fore: :yellow))
        return
      end
    end

    conn_string = "postgres://#{URI.encode_path_segment(db_user)}:#{URI.encode_path_segment(db_pass)}@#{db_host}:#{db_port}/postgres"

    # Step 1: Drop the database if it exists.
    # FR: Étape 1 : Supprimer la base si elle existe.
    print(style("Step 1/3: Dropping database ", fore: :cyan) +
          style(db_name, fore: :white, mode: :bold) +
          style(" ...", fore: :cyan))

    DB.open(conn_string) do |db|
      exists = db.query_one(
        "SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1)",
        db_name,
        as: Bool
      )

      if exists
        db.exec(<<-SQL, db_name)
          SELECT pg_terminate_backend(pid)
          FROM pg_stat_activity
          WHERE datname = $1 AND pid <> pg_backend_pid()
        SQL

        db.exec("DROP DATABASE \"#{db_name}\"")
        print(style("  Dropped.", fore: :green))
      else
        print(style("  Database did not exist, skipping.", fore: :yellow))
      end
    end

    # Step 2: Create the database.
    # FR: Étape 2 : Créer la base.
    print(style("Step 2/3: Creating database ", fore: :cyan) +
          style(db_name, fore: :white, mode: :bold) +
          style(" ...", fore: :cyan))

    DB.open(conn_string) do |db|
      db.exec("CREATE DATABASE \"#{db_name}\"")
      print(style("  Created.", fore: :green))
    end

    # Step 3: Run migrations.
    # FR: Étape 3 : Exécuter les migrations.
    print(style("Step 3/3: Running migrations...", fore: :cyan))

    status = Process.run("marten migrate", shell: true, output: STDOUT, error: STDERR)
    unless status.success?
      print_error_and_exit("Migration failed (exit code #{status.exit_code}).")
    end

    print(style("  Database reset complete.", fore: :green, mode: :bold))
  rescue ex
    print_error_and_exit("Cannot reset database: #{ex.message}")
  end

  private def fetch_db_config
    db_config = Marten.settings.databases.find { |d| d.id == "default" }
    unless db_config
      print_error_and_exit("No 'default' database connection found in Marten settings.")
    end
    db_config.not_nil!
  end
end
