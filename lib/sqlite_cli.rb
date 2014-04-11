#!/usr/bin/env ruby
require 'utils'
module Shell
  PROMPT = 'sqlite> '
  module InputCompletor
    CORE_WORDS = %w( clear help show exit export )
    SHOW_ARGS = %w( username clear_text_password
                    cached_hash lm_hash nt_hash host all )
    EXPORT_ARGS = %w( all )
    ARGS_HASH = { 'show' => SHOW_ARGS, 'export' => EXPORT_ARGS }
    COMPLETION_PROC = proc do |input|
      case input
      when /^(show|export) (.*)/
        options($1,$2)
      when /^(h|s|c|e.*)/
        receiver = $1
        CORE_WORDS.grep(/^#{Regexp.quote(receiver)}/)
      when /^\s*$/
        puts
        CORE_WORDS.map { |d| print "#{d}\t" }
        puts
        print PROMPT
      end
    end
    def self.options(command, receiver)
      args = ARGS_HASH[command]
      if args.grep(/^#{Regexp.quote(receiver)}/).length > 1
        args.grep(/^#{Regexp.quote(receiver)}/)
      elsif args.grep(/^#{Regexp.quote(receiver)}/).length == 1
        "#{command} #{args.grep(/^#{Regexp.quote(receiver)}/).join}"
      end
    end
  end
  class SQLiteCLI
    include Utils
    Readline.completion_append_character = ' '
    Readline.completer_word_break_characters = "\x00"
    Readline.completion_proc = Shell::InputCompletor::COMPLETION_PROC
    def initialize
      puts 'Type exit to exit'
      @connection = SQLiteDatabase.new("#{Menu.opts[:database]}")
      while line = Readline.readline("#{PROMPT}", true)
        Readline::HISTORY.pop if /^\s*$/ =~ line
        begin
          Readline::HISTORY.pop if Readline::HISTORY[-2] == line
        rescue IndexError
        end
        cmd = line.chomp
        case cmd
        when /^clear/
          system('clear')
        when /^help/
          help
        when /^(show|export)\s$/
          puts 'missing args'
        when /^exit/
          return
        when /^(show|export) (.*)/
          exec($1,$2)
        when /^select (.*)/
          res = @connection.execute("select #{$1}")
          res.each { |row| puts row.join("\s") }
        when /[^ ]/
          print_bad('command not found')
        end
      end
    end

    private

    def help
      puts 'You can combine show options to display certain results'
      puts 'Example: show host,username,lm_hash'
      puts
      puts 'show'
      puts '   all                    Displays entire database'
      puts '   cached_hash            Displays domain cached hashes'
      puts '   clear_text_password    Displays clear text passwords'
      puts '   host                   Displays hosts where loot came from'
      puts '   lm_hash                Displays lm hash'
      puts '   nt_hash                Displays nt hash'
      puts '   username               Displays username'
      puts 'export'
      puts '   all                    Writes database to a log file'
      puts 'clear                     Clear screen'
      puts 'exit                      Exit'
      puts 'help                      This page'
    end

    def exec(action,*args)
      args = args.map(&:strip)
      if args.include?('all')
        res = @connection.execute('select * from users')
      else
        res = @connection.execute("select #{args.join(',')} from users")
      end
      if action == 'show'
        res.each { |row| puts row.join("\s") }
      else
        file_name = 'database_dump'
        location  = "#{file_name}_#{Time.now.strftime('%m-%d-%Y_%H-%M')}"
        print_status("Writing file to #{location}")
        content = ''
        res.map { |row| content << "#{row.join("\s")}\n" }
        begin
          write_file(content, location)
        rescue IOError => e
          print_bad("Error: #{e.message} could not write file")
        end
      end
    end
  end
end
