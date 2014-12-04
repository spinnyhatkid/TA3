module MonitInstall
  class ServerMonit
    def initialize
    end
	
    #Download appropriate packages and startup monit
    def installMonit
      `yum install pam-devel -y`
      `wget studenthome.nku.edu/~rileyt3/monit-5.8.1.tar.gz`
      `tar zxf monit-5.8.1.tar.gz`
      Dir.chdir("monit-5.8.1")
      `./configure`
      `make`
      `make install`
      configMonit
      `monit -v`
    end
    
    #creates the monitrc file and configures it to monitor ssh, sendmail, syslog, partitions, and other various client statistics
    def configMonit
      File.open ('/etc/monitrc','a'){ |file| 
    file.puts "set daemon 60\nset logfile syslog facility log_daemon\nset mailserver\n127.0.0.1\nset alert cit470.fa2014.team4@gmail.com\n\n"
    file.puts "# Run monit web server so \"monit status\" and other commands work\nset httpd port 2812 and use address localhost\n  allow localhost # Allow only localhost to connect\n  allow admin:monit # Allow Basic Auth\n\n"
    file.puts "# Monit ssh process and restart if it goes down\ncheck process sshd with pidfile /var/run/sshd.pid\n  start program = \"/etc/init.d/sshd start\"\n  stop program = \"/etc/init.d/sshd stop\"\n  if 5 restarts within 5 cycles then timeout\n\n"
    file.puts "# Monit syslog process and restart if it goes down\ncheck process syslogd with pidfile /var/run/syslogd.pid\n  start program = \"/etc/init.d/syslog start\"\n  stop program = \"/etc/init.d/syslog stop\"\n  if 5 restarts within 5 cycles then timeout\n\n"
    file.puts "# Monit sendmail process and restart if it goes down\ncheck process sendmail with pidfile /var/run/sendmail.pid\n  start program = \"/etc/init.d/sendmail start\"\n  stop program = \"/etc/init.d/sendmail stop\"\n  if 5 restarts within 5 cycles then timeout\n\n"
    file.puts "check device rootfs with path /\n  if SPACE usage > 80% then alert\n\n"
    file.puts "check device varfs with path /var\n  if SPACE usage > 80% then alert\n\n"
      file.puts "#Alerts for localhost load memory and cpu\ncheck system localhost\n  if loadavg (5min) > 2 then alert\n  if memory usage > 80% then alert\n  if cpu usage (user) > 80% then alert\n  if swap > 80% then alert"
    file.puts "# monitor NFS and restart if it goes down\n#check process nfs with pidfile /var/run/rpc.statd.pid\n #  start program = \"/etc/init.d/nfs start\"\n#  stop program = \"/etc/init.d/nfs stop\"\n#  if 3 restarts within 5 cycles then timeout\ncheck file nfsd with path /var/lock/subsys/nfsd\nif does not exist for 1 cycles then exec \"/etc/init.d/nfs start\"\nif 3 restarts within 5 cycles then timeout\n\n"
    file.puts "# monitor LDAP and restart if it goes down\ncheck process ldap with pidfile /var/run/openldap/slapd.pid\nstart program = \"/etc/init.d/ldap start\"\nstop program = \"/etc/init.d/ldap stop\"\nif failed port 389 then restart\nif 2 restarts within 3 cycles then timeout\n\n"
    file.puts "# monitor httpd (web server) and restart if it goes down\ncheck process httpd with pidfile /var/run/httpd.pid\nstart program = \"/etc/init.d/httpd start\"\nstop program = \"/etc/init.d/httpd stop\"\n\nif failed host 127.0.0.1 port 80 protocol http then restart\nif 5 restarts within 5 cycles then timeout\n\n"
    file.puts "# monitor the CPU usage and alert if cpu usage > 80%\ncheck system localhost\nif loadavg (1min) > 5 then alert\nif loadavg (5min) > 3 then alert\nif cpu usage (user) > 80% then alert\nif cpu usage (system) > 80% for 3 cycles then alert\n\n"
    file.puts "# monitor memory and alert if usage > 80% then alert\nif memory usage > 80% then alert\n\n"
    file.puts "# monitor HDD usage and alert if space > 90%\ncheck device rootfs with path /\nif space usage > 90% then alert\ncheck device varfs with path /var\nif space usage > 90% then alert\ncheck device tmpfs with path /dev/shm\nif space usage > 90% then alert\ncheck device homefs with path /home\nif space usage > 90% then alert\n\n"
    file.puts "include /etc/monitrc.hosts"
    `chmod 700 /etc/monitrc`
    }

    File.open ('/etc/monitrc.hosts', 'a') { |file|
      file.puts "# Client 1\ncheck host client1 with address 10.2.3.220\nif failed icmp type echo with timeout 30 seconds then alert\nif failed port 22 protocol ssh then alert\nif failed port 514 type udp then alert\nif failed port 25 type udp then alert\nif failed port 111 type tcp then alert\nif failed port 2049 type tcp then alert\n\n"
      file.puts "# Client 1\ncheck host client2 with address 10.2.3.221\nif failed icmp type echo with timeout 30 seconds then alert\nif failed port 22 protocol ssh then alert\nif failed port 514 type udp then alert\nif failed port 25 type udp then alert\nif failed port 111 type tcp then alert\nif failed port 2049 type tcp then alert\n\n"
      file.puts "# Client 1\ncheck host client3 with address 10.2.3.222\nif failed icmp type echo with timeout 30 seconds then alert\nif failed port 22 protocol ssh then alert\nif failed port 514 type udp then alert\nif failed port 25 type udp then alert\nif failed port 111 type tcp then alert\nif failed port 2049 type tcp then alert\n\n"
      file.puts "# Client 1\ncheck host client4 with address 10.2.3.223\nif failed icmp type echo with timeout 30 seconds then alert\nif failed port 22 protocol ssh then alert\nif failed port 514 type udp then alert\nif failed port 25 type udp then alert\nif failed port 111 type tcp then alert\nif failed port 2049 type tcp then alert\n\n"
      `chmod 700 /etc/monitrc.hosts`
    }
    end
  end
end
