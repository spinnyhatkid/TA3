module SendmailInstall
  class ServerSendmail
    def initialize(serverip, clientips, names, mask)
      @serverip = serverip
      @clientips = clientips
      @names = names
      @mask = mask
    end
    
    #main server sendmail controller
    def installSendmail
      `yum install sendmail-cf sendmail-doc -y`
      createConfigDir
      buildDomainFile
      buildMCFile
      updateHosts
      replaceSendmailCf
      updateIpTables
      updateAccessdb
    end
    
    #updates the access database to allow client hosts to forward mail through the server
    def updateAccessdb
      access = File.read('/etc/mail/access')
      @clientips.length.times do |x|
        access = access.gsub(/\.\.\./, "...\n#{@names[x]}.nku.edu\t\t\t\tRELAY")
      end
      File.open('/etc/mail/access', 'w') { |file| file.puts access }
      `makemap hash /etc/mail/access < /etc/mail/access`
      `service sendmail restart`
    end
    
    #updates and restarts the iptables
    def updateIpTables
      `iptables -I INPUT 1 -s #{@clientips[0]}/#{@mask} -p tcp -m tcp --dport 25 -j ACCEPT`
      `iptables -I INPUT 1 -s #{@clientips[0]}/#{@mask} -p udp -m udp --dport 25 -j ACCEPT`
      `service iptables save`
      `service iptables restart`
    end
    
    #replaces the sendmail control file with the configured cit470 cf file
    def replaceSendmailCf
      `mv cf/cit470.cf /etc/mail/sendmail.cf`
      `service sendmail start`
    end
    
    #updates the hosts file to allow comunications between the clients and server
    def updateHosts
      hosts = File.read('/etc/hosts')
      hosts = hosts.gsub(/fail\./, "fail.\n#{@serverip}\t\tcit470.nku.edu") unless File.open('/etc/hosts').read() =~ /cit470.nku.edu/
      @clientips.length.times do |x|
	hosts = hosts.gsub(/fail\./, "fail.\n#{@clientips[x]}\t\t#{@names[x]}.nku.edu")
      end
      File.open('/etc/hosts', 'w') { |file| file.puts hosts }
    end
    
    #creates the new cf file that will replace sendmail.cf
    def buildMCFile
      File.open('cf/cit470.mc', 'a') { |file| file.puts "divert(-1)\ndivert(0)dnl\nOSTYPE(linux)dnl\nDOMAIN(cit470.nku.edu)\nFEATURE(access_db)dnl\nMAILER(local)dnl\nMAILER(smtp)dnl" }
      Dir.chdir("cf")
      `./Build cit470.cf`
      Dir.chdir("..")
    end
    
    #creates a domain file for cit470.nku.edu for proper cf configuration
    def buildDomainFile
      File.open('domain/cit470.nku.edu.m4', 'a') { |file| file.puts "divert(-1)\ndivert(0)\ndefine(`confCW_FILE', `/etc/mail/local-host-names')dnl\ndefine(`confDOMAIN_NAME', `cit470.nku.edu')dnl\ndefine(`confFORWARD_PATH', `$z/.forward.$w+$h:$z/.forward+$h:$z/.forward.$w:$z/.forward')dnl\ndefine(`confMAX_HEADERS_LENGTH', `32768')dnl\nFEATURE(`redirect')dnl\nFEATURE(`use_cw_file')dnl"}
    end
    
    #creates a new directory to create the replacement cf file
    def createConfigDir
      Dir.chdir("/usr/share/sendmail-cf")
      `mv cf cf.ex`
      `mkdir cf`
      `cp -p cf.ex/Build cf`
      `cp -p cf.ex/Makefile cf`
    end
  end
  
  class ClientSendmail
    def initialize(clientip, serverip, name)
      @clientip = clientip
      @serverip = serverip
      @name = name
    end
    
    #main client sendmail controller
    def installSendmail
      `yum install sendmail-cf sendmail-doc -y`
      createConfigDir
      buildMCFile
      updateHosts
      `service sendmail restart`
    end
    
    #update the hosts file for client server communications
    def updateHosts
      hosts = File.read('/etc/hosts')
      hosts = hosts.gsub(/fail\./, "fail.\n#{@clientip}\t\t#{@name}.nku.edu")
      hosts = hosts.gsub(/fail\./, "fail.\n#{@serverip}\t\tcit470.nku.edu") unless File.open('/etc/hosts').read() =~ /cit470.nku.edu/
      File.open('/etc/hosts', 'w') { |file| file.puts hosts }
    end
    
    #builds the clients mc and cf file to replace the sendmail.cf file on the client
    def buildMCFile
      File.open('cf/client.mc', 'a') { |file| file.puts "divert(-1)\ndivert(0)dnl\nOSTYPE(linux)dnl\nFEATURE(nullclient, cit470.nku.edu)dnl" }
      Dir.chdir("cf")
      `./Build client.cf`
      Dir.chdir("..")
      `mv cf/client.cf /etc/mail/sendmail.cf`
    end
    
    #creates a directory to contstruct the clients cf file
    def createConfigDir
      Dir.chdir("/usr/share/sendmail-cf")
      `mv cf cf.ex`
      `mkdir cf`
      `cp -p cf.ex/Build cf`
      `cp -p cf.ex/Makefile cf`
    end
  end
end
