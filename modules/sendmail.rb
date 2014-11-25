module SendmailInstall
  class ServerSendmail
    def initialize(serverip, clientips, names)
      @serverip = serverip
      @clientips = clientips
      @names = names
    end
    
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
    
    def updateAccessdb
      access = File.read('/etc/mail/access')
      @clientips.length.times do |x|
        access = access.gsub(/\.\.\./, "...\n#{@names[x]}.nku.edu\t\t\t\tRELAY")
      end
      File.open('/etc/mail/access', 'w') { |file| file.puts access }
      `makemap hash /etc/mail/access < /etc/mail/access`
      `service sendmail restart`
    end
    
    def updateIpTables
      `iptables -I INPUT 1 -p tcp -m tcp --dport 25 -j ACCEPT`
      `iptables -I INPUT 1 -p udp -m udp --dport 25 -j ACCEPT`
      `service iptables save`
      `service iptables restart`
    end
    
    def replaceSendmailCf
      `mv cf/cit470.cf /etc/mail/sendmail.cf`
      `service sendmail start`
    end
    
    def updateHosts
      hosts = File.read('/etc/hosts')
      hosts = hosts.gsub(/fail\./, "fail.\n#{@serverip}\t\tcit470.nku.edu") unless File.open('/etc/hosts').read() =~ /cit470.nku.edu/
      @clientips.length.times do |x|
	hosts = hosts.gsub(/fail\./, "fail.\n#{@clientips[x]}\t\t#{@names[x]}.nku.edu")
      end
      File.open('/etc/hosts', 'w') { |file| file.puts hosts }
    end
    
    def buildMCFile
      File.open('cf/cit470.mc', 'a') { |file| file.puts "divert(-1)\ndivert(0)dnl\nOSTYPE(linux)dnl\nDOMAIN(cit470.nku.edu)\nFEATURE(access_db)dnl\nMAILER(local)dnl\nMAILER(smtp)dnl" }
      Dir.chdir("cf")
      `./Build cit470.cf`
      Dir.chdir("..")
    end
    
    def buildDomainFile
      File.open('domain/cit470.nku.edu.m4', 'a') { |file| file.puts "divert(-1)\ndivert(0)\ndefine(`confCW_FILE', `/etc/mail/local-host-names')dnl\ndefine(`confDOMAIN_NAME', `cit470.nku.edu')dnl\ndefine(`confFORWARD_PATH', `$z/.forward.$w+$h:$z/.forward+$h:$z/.forward.$w:$z/.forward')dnl\ndefine(`confMAX_HEADERS_LENGTH', `32768')dnl\nFEATURE(`redirect')dnl\nFEATURE(`use_cw_file')dnl"}
    end
    
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
    
    def installSendmail
      `yum install sendmail-cf sendmail-doc -y`
      createConfigDir
      buildMCFile
      updateHosts
      `service sendmail restart`
    end
    
    def updateHosts
      hosts = File.read('/etc/hosts')
      hosts = hosts.gsub(/fail\./, "fail.\n#{@clientip}\t\t#{@name}.nku.edu")
      hosts = hosts.gsub(/fail\./, "fail.\n#{@serverip}\t\tcit470.nku.edu") unless File.open('/etc/hosts').read() =~ /cit470.nku.edu/
      File.open('/etc/hosts', 'w') { |file| file.puts hosts }
    end
    
    def buildMCFile
      File.open('cf/client.mc', 'a') { |file| file.puts "divert(-1)\ndivert(0)dnl\nOSTYPE(linux)dnl\nFEATURE(nullclient, cit470.nku.edu)dnl" }
      Dir.chdir("cf")
      `./Build client.cf`
      Dir.chdir("..")
      `mv cf/client.cf /etc/mail/sendmail.cf`
    end
    
    def createConfigDir
      Dir.chdir("/usr/share/sendmail-cf")
      `mv cf cf.ex`
      `mkdir cf`
      `cp -p cf.ex/Build cf`
      `cp -p cf.ex/Makefile cf`
    end
  end
end
