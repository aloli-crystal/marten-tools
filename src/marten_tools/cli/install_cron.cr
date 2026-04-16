# Install crontab from config/cron/crontab template (idempotent).
# FR: Installe le crontab depuis config/cron/crontab (idempotent).
#
# Supported template variables:
#   {{APP_HOME}}      — application root directory (env APP_HOME or cwd)
#   {{APP_FULL_NAME}} — application name (env APP_FULL_NAME or directory basename)
#   {{MARTEN_ENV}}    — current Marten environment (env MARTEN_ENV or "development")
class MartenTools::InstallCron < Marten::CLI::Manage::Command::Base
  command_name :install_cron
  help "Install crontab from config/cron/crontab template (idempotent)."

  def run
    cron_src = File.join(Dir.current, "config", "cron", "crontab")

    unless File.exists?(cron_src)
      # FR: Pas de fichier config/cron/crontab — rien à installer.
      print(style("No config/cron/crontab file found, nothing to install.", fore: :yellow))
      return
    end

    # Determine substitution variables.
    # FR: Déterminer les variables de substitution.
    app_home = ENV["APP_HOME"]? || Dir.current
    app_full_name = ENV["APP_FULL_NAME"]? || File.basename(Dir.current)
    marten_env = ENV["MARTEN_ENV"]? || "development"

    # Read and replace template variables.
    # FR: Lire et remplacer les variables.
    content = File.read(cron_src)
      .gsub("{{APP_HOME}}", app_home)
      .gsub("{{APP_FULL_NAME}}", app_full_name)
      .gsub("{{MARTEN_ENV}}", marten_env)

    # Compare with the current crontab.
    # FR: Comparer avec le crontab actuel.
    current = `crontab -l 2>/dev/null`.strip
    new_content = content.strip

    if current == new_content
      # FR: Crontab déjà à jour — rien à faire.
      print(style("Crontab is already up to date, nothing to do.", fore: :green))
      return
    end

    # Display variables and content.
    # FR: Afficher les variables et le contenu.
    print(style("Installing crontab:", fore: :cyan))
    print("  APP_HOME      = #{app_home}")
    print("  APP_FULL_NAME = #{app_full_name}")
    print("  MARTEN_ENV    = #{marten_env}")
    print("")
    print(style("Content:", fore: :cyan))
    new_content.each_line { |l| print("  #{l}") unless l.strip.empty? }

    # Write to a temp file and install.
    # FR: Écrire dans un fichier temporaire et installer.
    tmp = File.tempfile("crontab", ".tmp")
    begin
      tmp.print(content)
      tmp.flush
      tmp.close

      result = Process.run("crontab", [tmp.path], output: STDOUT, error: STDERR)
      if result.success?
        print("")
        # FR: Crontab installé.
        print(style("Crontab installed.", fore: :green))
      else
        print_error("Failed to install crontab (exit code #{result.exit_code}).")
      end
    ensure
      File.delete(tmp.path) rescue nil
    end
  end
end
