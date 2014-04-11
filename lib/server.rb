#!/usr/bin/env ruby
require 'thread'
require 'openssl'
require 'utils'
class Server
	include Utils
	module Info

		def get_url
			url =	rgets("Enter the web url [#{color_banner("http(s)://#{local_ip}:8080")}] :", "https://#{local_ip}:8080")
			unless url[0..6] == 'http://' or url[0..7] == 'https://'
				print_bad('Missing http(s)://')
				get_url
			end
			return url
		end

		def get_host(url)
			case url.count(':')
				when 1
					host = url.split('//')[1]
				when 2
					url = url.split('//')[1]
					host = url.split(':')[0]
			end
			return host
		end

		def get_port(url)
			case url.count(':')
				when 1
					if url[0..4] == 'https'
						port = 443
					else
						port = 80
					end
				when 2
					port = url.split(':')[2]
			end
			return port
		end

	end

	def ssl_setup(host,port)

    tcp_server = TCPServer.new(host,port)
		ctx = OpenSSL::SSL::SSLContext.new
		ctx.cert = OpenSSL::X509::Certificate.new(File.open(Menu.extbin[:crt]))
		ctx.key = OpenSSL::PKey::RSA.new(File.open(Menu.extbin[:key]))
		server = OpenSSL::SSL::SSLServer.new tcp_server, ctx
		return server

	end

  def start_server(host,port,ssl)

    if ssl
      print_status("Started SSL Server")
      @server = ssl_setup(host,port.to_i)
    else
      print_status("Started Server")
      @server = TCPServer.open(port.to_i)
    end

  rescue  Errno::EADDRINUSE
    print_status("re-opening socket")
    @server.closed
    @server = TCPServer.open(port.to_i)

  return @server

  end

  def print_client(client)
    print_status("#{client.peeraddr[3]} Connected")
  end

	def raw_web(host,port,body,ssl=nil)
		time = Time.now.localtime.strftime("%a %d %b %Y %H:%M:%S %Z")
    server = start_server(host,port,ssl)
		loop {
			Thread.start(server.accept) do |client|
        print_client(client)
				headers = ["HTTP/1.1 200 OK",
									 "Date: #{time}",
									 "Server: Ruby",
									 "Content-Type: text/html; charset=iso-8859-1",
									 "Content-Length: #{body.length}\r\n\r\n"].join("\r\n")
				client.print headers
				client.print "#{body}\n"
				client.close
			end
		}

	end

	def raw_upload(host,port,ssl=nil)
    server = start_server(host,port,ssl)
		loop{
			Thread.start(server.accept) do |client|
        print_client(client)
        file_name = client.gets
				vprint_good("Got #{file_name.strip} file")
				vprint_status("Getting Data")
				out_put = client.gets
				vprint_status("Writing to File")
				write_file(out_put, "results_#{self.class}_#{file_name.strip}_#{Time.now.strftime('%m-%d-%Y_%H-%M')}")
        vprint_status("File Done Uploading")
				print_good("Output can be found in #{Menu.opts[:log]}/results_#{self.class}_#{file_name.strip}_#{Time.now.strftime('%m-%d-%Y_%H-%M')}")
			end
		}
  end

  def base64_upload(host,port,ssl=nil)
    @server = start_server(host,port,ssl)
    loop{
      Thread.start(@server.accept) do |client|
        print_client(client)
        file_name = client.gets
        vprint_good("Got #{file_name.strip} file")
        vprint_status("Getting Data")
        out_put = client.gets
        vprint_status("Writing to File")
        write_file(Base64.decode64(out_put), "results_#{self.class}_#{file_name.strip}_#{Time.now.strftime('%m-%d-%Y_%H-%M')}")
        vprint_status("File Done Uploading")
        print_good("Output can be found in #{Menu.opts[:log]}/results_#{self.class}_#{file_name.strip}_#{Time.now.strftime('%m-%d-%Y_%H-%M')}")
      end
    }
  end

end
