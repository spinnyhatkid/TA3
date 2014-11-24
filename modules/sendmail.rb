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
      `service sendmail restart`
    end
    
    def updateAccessdb
      File.open('/etc/mail/access', 'r+') { |file|
        @clientips.length.times do |x|
          file.puts "#{@names[x]}.nku.edu\t\t\t\tRELAY"         
        end
      }
    end
    
    def updateIpTables
      `iptables -I INPUT -p tcp -m tcp --dport 25 -j ACCEPT`
      `iptables -I INPUT -p udp -m udp --dport 25 -j ACCEPT`
      `service iptables restart`
    end
    
    def replaceSendmailCf
      `mv cf/cit470.cf /etc/mail/sendmail.cf`
      `service sendmail start`
    end
    
    def updateHosts
      File.open('/etc/hosts', 'r+') { |file| 
        file.puts "#{@serverip}\t\tcit470.nku.edu" unless file.each_line.detect{ |line| /cit470.nku.edu/.match(line) }
        @clientips.length.times do |x|
          file.puts "#{@clientips[x]}\t\t#{@names[x]}.nku.edu"                            
        end
      }
    end
    
    def buildMCFile
      File.open('cf/cit470.mc', 'a') { |file| file.puts "divert(-1)\ndivert(0)dnl\nOSTYPE(linux)dnl\nDOMAIN(cit470.nku.edu)\nFEATURE(access_db)dnl\nMAILER(local)dnl\nMAILER(smtp)dnl" }
      `cf/Build cit470.cf`
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
      File.open('/etc/hosts', 'r+') { |file| 
        file.puts "#{@clientip}\t\t#{@name}.nku.edu" unless file.each_line.detect{ |line| /cit470.nku.edu/.match(line) }
        file.puts "#{@serverip}\t\tcit470.nku.edu"                            
      }
    end
    
    def buildMCFile
      File.open('cf/client.mc', 'a') { |file| file.puts "divert(-1)\ndivert(0)dnl\nOSTYPE(linux)dnl\nFEATURE(nullclient, cit470.nku.edu)dnl" }
      `cf/Build client.cf`
      `mv cf/client.cf /etc/sendmail.cf`
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
