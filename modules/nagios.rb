module NagiosInstall
  class ServerNagios
    def initialize(ips, names)
      @ips = ips
      @names = names
    end
    
    def installNagios 
      `yum install -y wget httpd php gcc glibc glibc-common gd gd-devel make net-snmp openssl-devel`
      Dir.chdir("/tmp")
      getPackages
      Dir.chdir("nagios-4.0.4")
      `./configure --with-command-group=nagcmd`
      `make all`
      `make install`
      `make install-init`
      `make install-config`
      `make install-commandmode`
      `make install-webconf`
      `cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/`
      `chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers`
      verifyStart
      createNagiosPasswd
      installNagiosPlugins
      configureStartup
      Dir.chdir("/usr/local/nagios/etc/objects/")
      File.open('command.cfg', 'a') { |cmd|
	cmd.puts "\ndefine command{\n"
	cmd.puts "command_name check_nrpe\n"
	cmd.puts "command_line $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$\n"
	cmd.puts "}"
      }
    end

    def configureStartup
      `chkconfig --add nagios`
      `chkconfig --level 35 nagios on`
      `chkconfig --add httpd`
      `chkconfig --level 35 httpd on`
    end

    def createNagiosPasswd
      `touch /usr/local/nagios/etc/htpasswd.users`
      `echo nagiosadmin:uPODiTjNs5eaY >> /usr/local/nagios/etc/htpasswd.users` 
    end

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

    def verifyStart
      `/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg`
      `service nagios start`
      `service httpd start`
    end

    def getPackages
      `wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.0.4.tar.gz`
      `wget http://nagios-plugins.org/download/nagios-plugins-2.0.tar.gz`
      `wget http://garr.dl.sourceforge.net/project/nagios/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz`
      `tar zxf nagios-4.0.4.tar.gz`
      `tar zxf nagios-plugins-2.0.tar.gz`
      `tar zxf nrpe-2.15.tar.gz`
    end

    def configUsers
      `useradd nagios`
      `groupadd nagcmd`
      `usermod -a -G nagcmd nagios`
    end

    def addNagiosHosts
      Dir.chdir("/usr/local/nagios/etc/")
      `touch hosts.cfg` unless File.exists("hosts.cfg")
      `touch services.cfg` unless File.exists("services.cfg")

      configHost
    end

    def configHost
      File.open('hosts.cfg', 'a+') { |file|
	file.puts "define host{\nname\t\t\tlinux-box\nuse\t\t\tgeneric-host\ncheck_period\t\t24x7\ncheck_interval\t\t5\nretry_interval\t\t1\nmax_check_attempts\t10\ncheck_command\t\tcheck-host-alive\nnotification_period\t24x7\nnotification_interval\t30\nnotification_options\td,r\ncontact_groups\t\tadmins\nregister\t\t\t0\n}\n" unless file.each_line.detect{ |line| /name\t\t\tlinux-box/.match(line) }
	@names.length.times do |x|
	  file.puts "define host{\nuse\t\t\tlinux-box\nhost_name\t\t\t#{@names[x]}\nalias\t\t\t#{@names[x]}\naddress\t\t\t#{@ips[x]}\n}\n"
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
    def initialize(ip, name)
      @ip = ip
      @name = name
    end
    
    def installNagios
      `yum install -y gcc glibc glibc-common gd gd-devel make net-snmp openssl-devel xinetd`
      configUsers
      installPackages
      configNRPE
      `iptables -I INPUT -p tcp -m tcp --dport 5666 -j ACCEPT`
      `service iptables restart`
    end
    
    def configNRPE
      nrpe_file = File.read('/etc/xinetd.d/nrpe')
      nrpe_file.gsub(/only_from       = 127.0.0.1/, "only_from       = 127.0.0.1 localhost #{@ip.first}")
      File.open('/etc/xinetd.d/nrpe', 'w') { |file| file.puts nrpe_file}
      File.open('/etc/services', 'a') { |file| file.puts "nrpe\t\t5666/tcp\t\t\t# NRPE"}
      `service xinetd restart`
    end
    
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
    
    def configUsers
      `useradd nagios`
      `echo nagios | passwd nagios --stdin`
    end
  end
end
