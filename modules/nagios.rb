module NagiosInstall
  class ServerNagios
    def initialize(ips, names, mask)
      @ips = ips
      @names = names
      @mask = mask
    end
    
    #main server install controller
    def installNagios 
      `yum install -y wget httpd php gcc glibc glibc-common gd gd-devel make net-snmp openssl-devel`
      Dir.chdir("/tmp")
      getPackages
      configUsers
      configureInstall
      `cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/`
      `chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers`
      verifyStart
      createNagiosPasswd
      installNagiosPlugins
      configureStartup
      Dir.chdir("/usr/local/nagios/etc/objects/")
      File.open('commands.cfg', 'a') { |cmd|
	cmd.puts "\ndefine command{\n\t"
	cmd.puts "command_name check_nrpe\n\t"
	cmd.puts "command_line $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$\n\t"
	cmd.puts "}"
      }
    end
    
    #configures and installs nagios
    def configureInstall
      Dir.chdir("nagios-4.0.4")
      `./configure --with-command-group=nagcmd`
      `make all`
      `make install`
      `make install-init`
      `make install-config`
      `make install-commandmode`
      `make install-webconf`
    end

    #configures nagios and httpd to start on startup and opens port 80 for nagios access
    def configureStartup
      `chkconfig --add nagios`
      `chkconfig --level 35 nagios on`
      `chkconfig --add httpd`
      `chkconfig --level 35 httpd on`
      `iptables -I INPUT 1 -s #{@ips[0]}/#{@mask} -p tcp -m tcp --dport 80 -j ACCEPT`
      `iptables -I INPUT 1 -s #{@ips[0]}/#{@mask} -p udp -m udp --dport 80 -j ACCEPT`
      `service iptables save`
      `service iptables restart`
    end

    #Creates the nagiosadmin user password entry for nagios login
    def createNagiosPasswd
      `touch /usr/local/nagios/etc/htpasswd.users`
      `echo nagiosadmin:uPODiTjNs5eaY >> /usr/local/nagios/etc/htpasswd.users` 
    end

    #Install nagios plugins for functionality and connections to client hosts
    def installNagiosPlugins
      Dir.chdir("/tmp/nagios-plugins-2.0")
      `./configure --with-nagios-user=nagios --with-nagios-group=nagios`
      `make`
      `make install`
      Dir.chdir("/tmp/nrpe-2.15")
      `./configure`
      `make all`
      `make install-plugin`
      `make install-daemon`
    end

    #verifys the nagios config file and restarts the nagios and httpd services
    def verifyStart
      `/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg`
      `service nagios restart`
      `service httpd restart`
    end

    #fetches and unpackages required archives
    def getPackages
      `wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.0.4.tar.gz`
      `wget http://nagios-plugins.org/download/nagios-plugins-2.0.tar.gz`
      `wget http://garr.dl.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz`
      `tar zxf nagios-4.0.4.tar.gz`
      `tar zxf nagios-plugins-2.0.tar.gz`
      `tar zxf nrpe-2.15.tar.gz`
    end

    #add the nagios and nagcmd users for services and directory control
    def configUsers
      `useradd nagios`
      `groupadd nagcmd`
      `usermod -a -G nagcmd nagios`
    end

    #creates the hosts and services files required to monitor client hosts
    def addNagiosHosts
      Dir.chdir("/usr/local/nagios/etc/")
      `touch hosts.cfg` unless File.exists?("hosts.cfg")
      `touch services.cfg` unless File.exists?("services.cfg")

      configHost
    end

    #configures the hosts and services that the nagios server will monitor
    def configHost
      unless File.open('nagios.cfg').read() =~ /hosts.cfg/ && File.open('nagios.cfg').read() =~ /services.cfg/
	cfg = File.read('nagios.cfg')
	cfg = cfg.gsub(/templates.cfg/, "templates.cfg\ncfg_file=/usr/local/nagios/etc/hosts.cfg\ncfg_file=/usr/local/nagios/etc/services.cfg")
	File.open('nagios.cfg', 'w') { |file| file.puts cfg }
      end
      File.open('hosts.cfg', 'a+') { |file|
	file.puts "define host{\nname\t\t\tlinux-box\nuse\t\t\tgeneric-host\ncheck_period\t\t24x7\ncheck_interval\t\t5\nretry_interval\t\t1\nmax_check_attempts\t10\ncheck_command\t\tcheck-host-alive\nnotification_period\t24x7\nnotification_interval\t30\nnotification_options\td,r\ncontact_groups\t\tadmins\nregister\t\t\t0\n}\n" unless File.open('hosts.cfg').read() =~ /name\t\t\tlinux-box/
	@names.length.times do |x|
	  file.puts "define host{\nuse\t\t\tlinux-box\nhost_name\t\t#{@names[x]}\nalias\t\t\t#{@names[x]}\naddress\t\t\t#{@ips[x]}\n}\n\n"
	end
      }
      File.open('services.cfg', 'a') { |file| 
        @names.length.times do |x|
          file.puts "define service{\n\tuse\t\t\tgeneric-service\n\thost_name\t\t#{@names[x]}\n\tservice_description\tCPU Load\n\tcheck_command\t\tcheck_nrpe!check_load\n}\n\ndefine service{\n\tuse\t\t\tgeneric-service\n\thost_name\t\t#{@names[x]}\n\tservice_description\tTotal Processes\n\tcheck_command\t\tcheck_nrpe!check_total_procs\n}\n\ndefine service{\n\tuse\t\t\tgeneric-service\n\thost_name\t\t#{@names[x]}\n\tservice_description\tCurrent Users\n\tcheck_command\t\tcheck_nrpe!check_users\n}\n\ndefine service{\n\tuse\t\t\tgeneric-service\n\thost_name\t\t#{@names[x]}\n\tservice_description\tSSH\n\tcheck_command\t\tcheck_ssh\n}\n\ndefine service{\n\tuse\t\t\tgeneric-service\n\thost_name\t\t#{@names[x]}\n\tservice_description\tPING\n\tcheck_command\t\tcheck_ping!100.0,20%!500.0,60%\n}\n\n"                      
        end
      }
    end
  end

  class ClientNagios
    def initialize(ip, name, mask)
      @ip = ip
      @name = name
      @mask = mask
    end
    
    #client nagios controller, installs requirements and opens port 5666 for server access
    def installNagios
      `yum install -y gcc glibc glibc-common gd gd-devel make net-snmp openssl-devel xinetd`
      configUsers
      installPackages
      configNRPE
      `iptables -I INPUT 1 -s #{@ip}/#{@mask} -p tcp -m tcp --dport 5666 -j ACCEPT`
      `service iptables save`
      `service iptables restart`
    end
    
    #configures the connections program for server client communications
    def configNRPE
      nrpe_file = File.read('/etc/xinetd.d/nrpe')
      nrpe_file = nrpe_file.gsub(/127\.0\.0\.1/, "127.0.0.1 localhost #{@ip.first}")
      File.open('/etc/xinetd.d/nrpe', 'w') { |file| file.puts nrpe_file}
      File.open('/etc/services', 'a') { |file| file.puts "nrpe\t\t5666/tcp\t\t\t# NRPE"}
      `service xinetd restart`
    end
    
    #fetch and install required packages for server client communications
    def installPackages
      Dir.chdir("/tmp")
      `wget http://www.nagios-plugins.org/download/nagios-plugins-1.5.tar.gz`
      `wget http://garr.dl.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz`
      `tar -zxf nagios-plugins-1.5.tar.gz`
      `tar -zxf nrpe-2.15.tar.gz`
      Dir.chdir("nagios-plugins-1.5")
      `./configure`
      `make`
      `make install`
      `chown nagios.nagios /usr/local/nagios`
      `chown -R nagios.nagios /usr/local/nagios/libexec`
      Dir.chdir("../nrpe-2.15")
      `./configure`
      `make all`
      `make install-plugin`
      `make install-daemon`
      `make install-daemon-config`
      `make install-xinetd`
    end
    
    #creates and and configures the nagios user
    def configUsers
      `useradd nagios`
      `echo nagios | passwd nagios --stdin`
    end
  end
end
