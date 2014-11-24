module MonitInstall
  class ClientMonit
    def initialize
    end
	
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
    
    def configMonit
      File.open('/etc/monitrc', 'a') { |file| 
	file.puts "set daemon 60\nset logfile syslog facility log_daemon\nset mailserver\n127.0.0.1\nset alert cit470.fa2014.team4@gmail.com\n\n"
	file.puts "# Run monit web server so \"monit status\" and other commands work\nset httpd port 2812 and use address localhost\n  allow localhost # Allow only localhost to connect\n  allow admin:monit # Allow Basic Auth\n\n"
	file.puts "# Monit ssh process and restart if it goes down\ncheck process sshd with pidfile /var/run/sshd.pid\n  start program = \"/etc/init.d/sshd start\"\n  stop program = \"/etc/init.d/sshd stop\"\n  if 5 restarts within 5 cycles then timeout\n\n"
	file.puts "# Monit syslog process and restart if it goes down\ncheck process syslogd with pidfile /var/run/syslogd.pid\n  start program = \"/etc/init.d/syslog start\"\n  stop program = \"/etc/init.d/syslog stop\"\n  if 5 restarts within 5 cycles then timeout\n\n"
	file.puts "# Monit sendmail process and restart if it goes down\ncheck process sendmail with pidfile /var/run/sendmail.pid\n  start program = \"/etc/init.d/sendmail start\"\n  stop program = \"/etc/init.d/sendmail stop\"\n  if 5 restarts within 5 cycles then timeout\n\n"
	file.puts "check device rootfs with path /\n  if SPACE usage > 80% then alert\n\n"
	file.puts "check device varfs with path /var\n  if SPACE usage > 80% then alert\n\n"
        file.puts "#Alerts for localhost load memory and cpu\ncheck system localhost\n  if loadavg (5min) > 2 then alert\n  if memory usage > 80% then alert\n  if cpu usage (user) > 80% then alert\n  if swap > 80% then alert"
      }
    end
  end
end