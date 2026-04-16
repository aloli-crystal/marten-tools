# Show database statistics: connections, cache hit ratio, age, row counts.
# FR: Affiche les statistiques de la base : connexions, ratio de cache, âge, nombre de lignes.
class MartenTools::DbStats < Marten::CLI::Manage::Command::Base
  command_name :dbstats
  help "Show database statistics (connections, cache hit ratio, age, table row counts)."

  def run
    db_config = fetch_db_config

    db_name = db_config.name.to_s
    db_host = db_config.host.to_s
    db_port = db_config.port || 5432
    db_user = db_config.user.to_s
    db_pass = db_config.password.to_s

    conn_string = "postgres://#{URI.encode_path_segment(db_user)}:#{URI.encode_path_segment(db_pass)}@#{db_host}:#{db_port}/#{URI.encode_path_segment(db_name)}"

    DB.open(conn_string) do |db|
      print(style("Database: ", fore: :cyan) +
            style(db_name, fore: :white, mode: :bold))
      print("")

      # Active connections.
      # FR: Connexions actives.
      active_connections = db.query_one(
        "SELECT count(*) FROM pg_stat_activity WHERE datname = $1",
        db_name,
        as: Int64
      )
      print(style("Active connections: ", fore: :cyan) +
            style(active_connections.to_s, fore: :white, mode: :bold))

      # Cache hit ratio.
      # FR: Ratio de cache.
      cache_hit = db.query_one(<<-SQL, as: Float64?)
        SELECT
          CASE WHEN blks_hit + blks_read = 0 THEN NULL
          ELSE round(blks_hit::numeric / (blks_hit + blks_read) * 100, 2)
          END
        FROM pg_stat_database
        WHERE datname = current_database()
      SQL

      if cache_hit
        color = cache_hit >= 99.0 ? :green : (cache_hit >= 95.0 ? :yellow : :red)
        print(style("Cache hit ratio:   ", fore: :cyan) +
              style("#{cache_hit}%", fore: color, mode: :bold))
      else
        print(style("Cache hit ratio:   ", fore: :cyan) +
              style("N/A (no data yet)", fore: :yellow))
      end

      # Database age.
      # FR: Âge de la base.
      db_age = db.query_one(
        "SELECT age(datfrozenxid) FROM pg_database WHERE datname = current_database()",
        as: Int32
      )
      print(style("Database age (xid): ", fore: :cyan) +
            style(db_age.to_s, fore: :white, mode: :bold))

      # Database size.
      # FR: Taille de la base.
      db_size = db.query_one(
        "SELECT pg_size_pretty(pg_database_size(current_database()))",
        as: String
      )
      print(style("Database size:     ", fore: :cyan) +
            style(db_size, fore: :white, mode: :bold))

      print("")

      # Table row counts (estimated).
      # FR: Nombre de lignes par table (estimation).
      print(style("Table row counts (estimated):", fore: :cyan))
      print(style("  #{"Table".ljust(40)} #{"Rows".rjust(12)}", fore: :white, mode: :bold))
      print("  #{"-" * 52}")

      db.query(<<-SQL) do |rs|
        SELECT
          schemaname || '.' || relname AS full_name,
          n_live_tup AS row_count
        FROM pg_stat_user_tables
        ORDER BY n_live_tup DESC
      SQL
        rs.each do
          full_name = rs.read(String)
          row_count = rs.read(Int64)
          print("  #{full_name.ljust(40)} #{row_count.to_s.rjust(12)}")
        end
      end
    end
  rescue ex
    print_error_and_exit("Cannot query database stats: #{ex.message}")
  end

  private def fetch_db_config
    db_config = Marten.settings.databases.find { |d| d.id == "default" }
    unless db_config
      print_error_and_exit("No 'default' database connection found in Marten settings.")
    end
    db_config.not_nil!
  end
end
