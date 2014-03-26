#!/usr/bin/env ruby
require 'utils'
module Shell
  PROMPT = "sqlite> "
  module InputCompletor
    CORE_WORDS = %w[ clear help show exit export]
    SHOW_ARGS = %w[ username clear_text_password
                    cached_hash lm_hash nt_hash host all ]
    EXPORT_ARGS = %w[ all ]
    ARGS_HASH = {'show' => SHOW_ARGS, 'export' => EXPORT_ARGS}
    COMPLETION_PROC = proc { |input|
      case input
      when /^(show|export) (.*)/
        command = $1
        receiver = $2
        options($1,$2)
      when /^(h|s|c|e.*)/
        receiver = $1
        CORE_WORDS.grep(/^#{Regexp.quote(receiver)}/)
      when /^\s*$/
        puts
        CORE_WORDS.map{|d| print "#{d}\t"}
        puts
        print PROMPT
      end
    }
    def self.options(command,receiver)
      args = ARGS_HASH[command]
      if args.grep(/^#{Regexp.quote(receiver)}/).length > 1
        args.grep(/^#{Regexp.quote(receiver)}/)
      elsif args.grep(/^#{Regexp.quote(receiver)}/).length == 1
        "#{command.to_s} #{args.grep(/^#{Regexp.quote(receiver)}/).join}"
      end
    end
  end
  class SQLiteCLI
    include Utils
    Readline.completion_append_character = ' '
    Readline.completer_word_break_characters = "\x00"
    Readline.completion_proc = Shell::InputCompletor::COMPLETION_PROC
    def initialize
      puts "Type exit to exit"
      @connection = SQLiteDatabase.new("#{Menu.opts[:database]}")
      while line = Readline.readline("#{PROMPT}",true)
        Readline::HISTORY.pop if /^\s*$/ =~ line
        begin
          if Readline::HISTORY[-2] == line
            Readline::HISTORY.pop
          end
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
          exit
        when /^(show|export) (.*)/
          execute($1,$2)
        when /^select (.*)/
          @connection.execute("select #{$1}")
        when /[^ ]/
          print_bad("command not found")
        end
      end
    end

    private

    def help
      puts "press tab to get a list of options available"
    end

    def execute(action,*args)
      if args.include?('all')
        res = @connect.execute("select * from users")
      else
        res = @connect.execute("select #{args.join(',')} from users")
      end
      if action == 'show'
        puts res.join("\s")
      else
        file_name = args[1]
        write_file(res.join("\s"), "#{file_name}_#{Time.now.strftime('%m-%d-%Y_%H-%M')}")
      end
    end
  end
end
