require 'poet'

class Processfind < Poet::Scanner
	self.mod_name = "Process Finder"
	self.description = "Locate sensitive processes on target(s)."
	
	# formats and extensions 
	# TODO: add a ton more.
	# These are case insensitive as we use the /i switch for findstr
	# ie: %OFFICE%, %PASSWORD%, %KEYFILES%  
	#OFFICE_PROC = ".*\\.xls$, .*\\.csv$, .*\\.doc$, .*\\.docx$, .*\\.pdf$"
	SSH_PROC = "putty\\.exe, ssh\\.exe, winscp\\.exe"
	PASSWORD_PROC = "keepass\\.exe, lastpass\\.exe, TrueCrypt\\.exe"
	VNC_PROC = "tvnviewer\\.exe"
	RDP_PROC = "mstsc\\.exe"
	SECURITY_PROC = "wireshark\\.exe, tcpdump\\.exe"
	SYSINTERNALS_PROC = "procmon\\.exe, procexp\\.exe, portmon\\.exe, tcpconv\\.exe, autoruns\\.exe, autorunsc\\.exe"
	# ANTIVIRUS_PROC --- not to be included in %ALL%?, go find a good list from some other piece of malware's detection capabilities, might not even be worth it
	
	# easy mode
	ALL_PROC = PASSWORD_PROC + "," + SSH_PROC
	@snapshot = false
	
	def setup
		# Print title
		puts 

		@timeout = 0
		@regexes = Array.new
		@dropfile = random_name
		
		searches = "#{color_banner('%SSH%')} : #{SSH_PROC}\n"
		searches = "#{color_banner('%VNC%')} : #{VNC_PROC}\n"
		searches = "#{color_banner('%RDP%')} : #{RDP_PROC}\n"
		searches = "#{color_banner('%SECURITY%')} : #{SECURITY_PROC}\n"
		searches = "#{color_banner('%SYSINTERNALS%')} : #{SYSINTERNALS_PROC}\n"
		searches << "#{color_banner('%PASSWORD%')} : #{PASSWORD_PROC}\n\n"
		searches  << "#{color_banner('%ALL%')} : Combination of all of the above (default: [#{color_banner('%ALL%')}]):\n"
		
		print "Enter path to newline separated file containing process names to search for, or enter in comma separated files in the form of regular expressions. (Substitutions exist for commonly useful filetypes and extensions:\n#{searches}"
		ext = rgets
		if ext.empty?
			ext = "%ALL%"
		# Get valid path
		elsif File.file? ext
			temp = []
			File.open(ext, "r").each_line {|line| temp << line}
			print_good("File #{ext} parsed, #{temp.length} items found")
			ext = temp.join(',')
			puts
		end
		until @snapshot =~ /^(y|n)$/
			print "Would you like to save a snapshot list of the file system (likely huge)? [#{color_banner('y')}|#{color_banner('n')}]"
			@snapshot = rgets.downcase
		end
		@snapshot = @snapshot.eql? 'y'
		
		# Perhaps make a check for TEMP files that are writeable - do a write check and confirm.
		@command = ''
		@command << "tasklist /v > C:\\#{@dropfile} "
		
		# substitute our prefills
		subd = ''
		ext.split(',').each do |e|
			e = e.gsub /%ALL%/, ALL_PROC
			e = e.gsub /%SSH%/, SSH_PROC
			e = e.gsub /%VNC%/, VNC_PROC
			e = e.gsub /%SECURITY%/, SECURITY_PROC
			e = e.gsub /%RDP%/, RDP_PROC
			e = e.gsub /%SYSINTERNALS%/, SYSINTERNALS_PROC
			e = e.gsub /%PASSWORD%/, PASSWORD_PROC
			e.split(',').each {|ee| @regexes.push(ee.strip)}
		end

		@regexes.each {|process| @command = @command + " & findstr /i #{process} C:\\#{@dropfile}"}

		create_folder("#{@log}/loot") unless folder_exists("#{@log}/loot")
		create_folder("#{@log}/loot/processfinder") unless folder_exists("#{@log}/loot/processfinder")
	
		puts
		title = "Process Finder"
		puts color_header(title)
	end

	def run(username, password, host)
		smboptions = "//#{host}"
		processes_found = Array.new
		all_processes = ''
		
		# Should pipe to C:\randomizedfilename and type C:\randomizedfilename | [all our findstr here] to give us our list
		# This again reduces the amount of network traffic, which is valuable for stealth as the filtering happens on the targets
		find = winexe(smboptions, "CMD /C #{@command}")
		
		# Split by multiple spaces, because tasklist is ugly.
		# In windows 7+ this will also give you the window titles you can search through :-O
		find.each_line {|line| processes_found.push(line.split("   ").first.chomp)}
		
		# Process lists are already filtered us on the host through piping findstr
		# This is done to reduce network overhead and distribute the regex processing to all targets
		if processes_found.empty? 
			print_bad("#{host.ljust(15)} - Process(es) not found")
		else
			if processes_found.size > 1
				print_good("#{host.ljust(15)} - #{processes_found.size} Interesting process(es) found")
			else
				print_good("#{host.ljust(15)} - #{processes_found.join(', ')} found")
			end
			@success += processes_found.size
			
			# Append newline because ugly otherwise
			processes_found[-1] = processes_found[-1] + "\n"
			write_file(processes_found.join(", "), "#{host}_proclist.txt", "#{@log}/loot/processfinder/")
		end

		if @snapshot
			# retrieve the full contents of the tasklist output and delete our file, (saves one call to winexe() by deleting file)
			all_processes = winexe(smboptions, "CMD /c type C:\\#{@dropfile} && del C:\\#{@dropfile}")
			if all_processes.empty?
				print_bad("#{host.ljust(15)} - No processes found at all on target system??")
			else
				if all_processes.lines.count > 2
					print_good("#{host.ljust(15)} - Process list snapshot retrieved")
				else
					files_print = Array.new
					all_processes.each_line {|line| files_print << line.chomp}
					print_good("#{host.ljust(15)} - #{files_print.join(', ')} found")
				end
				@success += all_processes.lines.count
				
				write_file(all_processes, "#{host}_allproc.txt", "#{@log}/loot/processfinder/")
			end
		# delete our temporary file
		else
			winexe(smboptions, "CMD /c del C:\\#{@dropfile}")
		end
	end

	def finish
		# Put ending titles
		puts
		puts "Total files searched: #{@success}"
		puts "Interesting file lists are located in: #{@log}/loot/processfinder/<host>_proclist.txt"

		if @snapshot
			puts "Full filesystem snapshot located in: #{@log}/loot/processfinder/<host>_allprocs.txt"
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