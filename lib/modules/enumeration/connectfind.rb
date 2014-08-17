require 'poet'

class ConnectionFind < Poet::Scanner
	self.mod_name = "Connection Finder"
	self.description = "Locate interesting connections on target(s)."
	
	# List of interesting ports to check for that might lead to other interesting things
	# For times when finding that ONE IT guy who controls the *nix side is crucial ;)
	INTERESTING_PORTS = { \
		3389 => "rdp", \
		23 => "telnet", \
		22 => "ssh", \
		1337 => "backdoor", \
		31337 => "backdoor", \
		4444 => "default metasploit", \
		514 => "rlogin", \
		21 => "ftp", \
		115 => "sftp", \
		49 => "tacas-ds", \
		445 => "smb", \
		179 => "bgp", \
		1194 => "openvpn", \
		1241 => "nessus", \
		1433 => "mssql", \
		1812 => "radius", \
		2049 => "nfs", \
		3306 => "mysql", \
		3690 => "svn", \
		5432 => "postgresql", \
		6000 => "X11", \
		6001 => "X11", \
		6002 => "X11", \
		6003 => "X11", \
		6004 => "X11", \
		6005 => "X11", \
		6006 => "X11", \
		6007 => "X11", \
		9418 => "git"}
	@snapshot = false
	
	def setup
		# Print title
		puts 

		@timeout = 0
		@args = Array.new
		@dropfile = random_name
		@find_hosts = Array.new
		@find_ports = Array.new
		
		title = "Connection Finder"
		puts color_header(title)
		
		puts "Enter path to newline separated file containing ports or IP addresses to search for, or enter in comma separated ports, IP addresses or IP address ranges"
		puts "Example: %INTERESTING%,3232,53,123.21.123.21,192.168.7.0/24,65535\n"
		puts "#{color_banner('%INTERESTING%')} : Substitution for a few different interesting ports (#{INTERESTING_PORTS.keys.join(", ")}), can be combined with others (default: [#{color_banner('%INTERESTING%')}]):\n"
		ext = rgets
		if ext.empty?
			ext = "%INTERESTING%"
		# Get valid path
		elsif File.file? ext
			temp = []
			File.open(ext, "r").each_line {|line| temp << line}
			print_good("File #{ext} parsed, #{temp.length} items found")
			ext = temp.join(',')
			puts
		end
		
		# substitute our prefills
		subd = ''
		ext.split(',').each do |e|
			e = e.gsub(/%INTERESTING%/, INTERESTING_PORTS.keys.join(","))
			e.split(',').each {|ee| @args.push(ee.strip)}
		end
		
		@args.each do |findme|
			# TODO: This is crap, do this right 
			if findme.include? "."
				parse_addr(findme).each {|ip| @find_hosts.push(ip)}
			else
				# Assuming it's a port
				@find_ports.push(findme.to_i)
			end
		end

		create_folder("#{@log}/loot") unless folder_exists("#{@log}/loot")
		create_folder("#{@log}/loot/connectionfinder") unless folder_exists("#{@log}/loot/connectionfinder")
	
		puts
		
	end

	def run(username, password, host)
		smboptions = "//#{host}"
		hosts_found = Array.new
		ports_found = Array.new
		all_connections = ''
		host = ''
		port = ''
		
		# TODO: Show which process owns it
		find = winexe(smboptions, "CMD /C netstat -an|findstr ESTABLISHED")
		unless find.empty?
			@success = @success + 1
		else
			# TODO: Better clean up here needed
			return
		end
		find.each_line do |line|
			if line =~ /TCP\s+([0-9\.\:]+)\s+([0-9\:\.]+)/
				puts "Oi we got a connection: " + $2 # DEBUG
				(host, port) = $2.split(":")
				if @find_hosts.include? host
					hosts_found.push(host)
				end
				# record host:port combo for context
				if @find_ports.include? port.to_i
					ports_found.push([host,port])
				end
			else
				# we got bad input, do something about it!
				print_bad("#{host.ljust(15)} - Bad input received from netstat on target")
			end
		end

		if hosts_found.size > 0 or ports_found.size > 0
			if hosts_found.size > 1 and @find_hosts.size > 0
				print_good("#{host.ljust(15)} - #{hosts_found.size} Interesting connection(s) found to interesting addresses")
			elsif hosts_found.size > 0
				print_good("#{host.ljust(15)} - Interesting connection found to #{hosts_found.first}")
			else
				# maybe too verbose
				#print_bad("#{host.ljust(15)} - No interesting connections found to hosts")
			end
			if ports_found.size > 1 and @find_ports.size > 0
				print_good("#{host.ljust(15)} - #{ports_found.size} Interesting connection(s) found to interesting ports")
			elsif ports_found.size > 0
				print_good("#{host.ljust(15)} - #{ports_found.first.join(':')} - interesting connection to interesting port")
			else
				# maybe too verbose
				#print_bad("#{host.ljust(15)} - No interesting connections with interesting ports found")
			end
			
			@success += processes_found.size
			
			# Append newline because ugly otherwise
			processes_found[-1] = processes_found[-1] + "\n"
			write_file(processes_found.join(", "), "#{host}_proclist.txt", "#{@log}/loot/connectionfinder/")
		else
			# maybe too verbose
			print_bad("#{host.ljust(15)} - Nothing found")
		end
	end

	def finish
		# Put ending titles
		puts
		puts "Total files searched: #{@success}"
		puts "Interesting file lists are located in: #{@log}/loot/connectionfinder/<host>_proclist.txt"

		if @snapshot
			puts "Full filesystem snapshot located in: #{@log}/loot/connectionfinder/<host>_allprocs.txt"
		end
		puts

		# Return to menu
		print "Press enter to Return to Enumeration Menu"
		gets

		# Save to Menu class
		#Menu.update_banner(color_banner("DA found: #{@success}"), :shares)
		#Menu.opts[:shares] = @shares
	end
end