# Kill orphan Marten server processes.
# FR: Tue les processus orphelins de marten serve.
class MartenTools::Cleanup < Marten::CLI::Manage::Command::Base
  command_name :cleanup
  help "Kill orphan Marten server processes. Use --show to list without killing."

  @show_only = false
  @port = 3000

  def setup
    on_option("s", "show", "List processes without killing them") { @show_only = true }
    on_option_with_arg("p", "port", "port", "Port to check (default: 3000)") { |p| @port = p.to_i }
  end

  def run
    port = @port
    found = false

    # 1. Processes on the port.
    # FR: Processus sur le port.
    port_pids = find_pids_on_port(port)
    unless port_pids.empty?
      found = true
      print(style("Processes on port #{port}:", fore: :cyan))
      port_pids.each { |pid| print_pid(pid, "port:#{port}") }
      kill_pids(port_pids) unless @show_only
    end

    # 2. Orphan bin/manage processes.
    # FR: Processus bin/manage orphelins.
    manage_pids = find_pids_by_name("bin/manage") - port_pids
    unless manage_pids.empty?
      found = true
      print(style("Orphan bin/manage processes:", fore: :cyan))
      manage_pids.each { |pid| print_pid(pid, "manage") }
      kill_pids(manage_pids) unless @show_only
    end

    # 3. Orphan bin/server processes.
    # FR: Processus bin/server orphelins.
    server_pids = find_pids_by_name("bin/server") - port_pids - manage_pids
    unless server_pids.empty?
      found = true
      print(style("Orphan bin/server processes:", fore: :cyan))
      server_pids.each { |pid| print_pid(pid, "server") }
      kill_pids(server_pids) unless @show_only
    end

    unless found
      # FR: Aucun processus orphelin.
      print(style("No orphan processes found.", fore: :green))
      return
    end

    if @show_only
      # FR: Relancez sans --show pour les tuer.
      print(style("Run again without --show to kill them.", fore: :yellow))
      return
    end

    # Verify after kill.
    # FR: Vérifier après kill.
    sleep 1.second
    remaining = find_pids_on_port(port)
    if remaining.empty?
      print(style("Port #{port} is now free.", fore: :green))
    else
      # FR: Processus récalcitrants — SIGKILL.
      print(style("Stubborn processes remaining, sending SIGKILL...", fore: :yellow))
      remaining.each do |pid|
        begin
          Process.signal(Signal::KILL, pid)
        rescue
        end
      end
      sleep 500.milliseconds
      if find_pids_on_port(port).empty?
        print(style("Port #{port} is now free.", fore: :green))
      else
        print_error_and_exit("Cannot free port #{port}. Check manually: lsof -ti:#{port}")
      end
    end
  end

  private def find_pids_on_port(port : Int32) : Array(Int64)
    output = `lsof -ti:#{port} 2>/dev/null`.strip
    return [] of Int64 if output.empty?
    output.split("\n").compact_map(&.to_i64?)
  end

  private def find_pids_by_name(name : String) : Array(Int64)
    output = `pgrep -f "#{name}" 2>/dev/null`.strip
    return [] of Int64 if output.empty?
    output.split("\n").compact_map(&.to_i64?)
  end

  private def print_pid(pid : Int64, label : String)
    cmd = `ps -p #{pid} -o comm= 2>/dev/null`.strip
    print("  PID #{pid}  #{label}  #{cmd}")
  end

  private def kill_pids(pids : Array(Int64))
    pids.each do |pid|
      begin
        Process.signal(Signal::TERM, pid)
        print(style("  PID #{pid} — SIGTERM sent", fore: :green))
      rescue
        print(style("  PID #{pid} — could not signal", fore: :yellow))
      end
    end
  end
end
