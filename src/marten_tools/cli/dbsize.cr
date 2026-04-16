# Show the size of the current database and its biggest tables.
# FR: Affiche la taille de la base de données courante et de ses plus grosses tables.
class MartenTools::DbSize < Marten::CLI::Manage::Command::Base
  command_name :dbsize
  help "Show the size of the current database and its top 10 biggest tables."

  def run
    db_config = fetch_db_config

    db_name = db_config.name.to_s
    db_host = db_config.host.to_s
    db_port = db_config.port || 5432
    db_user = db_config.user.to_s
    db_pass = db_config.password.to_s

    conn_string = "postgres://#{URI.encode_path_segment(db_user)}:#{URI.encode_path_segment(db_pass)}@#{db_host}:#{db_port}/#{URI.encode_path_segment(db_name)}"

    DB.open(conn_string) do |db|
      # Total database size.
      # FR: Taille totale de la base.
      db_size = db.query_one(
        "SELECT pg_size_pretty(pg_database_size(current_database()))",
        as: String
      )

      print(style("Database: ", fore: :cyan) +
            style(db_name, fore: :white, mode: :bold))
      print(style("Total size: ", fore: :cyan) +
            style(db_size, fore: :white, mode: :bold))
      print("")

      # Top 10 biggest tables.
      # FR: Les 10 plus grosses tables.
      print(style("Top 10 tables by size:", fore: :cyan))
      print(style("  #{"Table".ljust(40)} #{"Size".rjust(12)} #{"Rows (est.)".rjust(12)}", fore: :white, mode: :bold))
      print("  #{"-" * 64}")

      db.query(<<-SQL) do |rs|
        SELECT
          schemaname || '.' || tablename AS full_name,
          pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS size,
          pg_total_relation_size(schemaname || '.' || tablename) AS raw_size,
          (SELECT reltuples::bigint FROM pg_class WHERE oid = (schemaname || '.' || tablename)::regclass) AS row_estimate
        FROM pg_tables
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
        ORDER BY raw_size DESC
        LIMIT 10
      SQL
        rs.each do
          full_name = rs.read(String)
          size = rs.read(String)
          _raw_size = rs.read(Int64)
          row_estimate = rs.read(Int64)
          print("  #{full_name.ljust(40)} #{size.rjust(12)} #{row_estimate.to_s.rjust(12)}")
        end
      end
    end
  rescue ex
    print_error_and_exit("Cannot query database size: #{ex.message}")
  end

  private def fetch_db_config
    db_config = Marten.settings.databases.find { |d| d.id == "default" }
    unless db_config
      print_error_and_exit("No 'default' database connection found in Marten settings.")
    end
    db_config.not_nil!
  end
end
