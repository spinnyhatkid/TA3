module SyslogInstall
	class ServerSyslog
		def initalize
		end
		def configSyslog
			if File.exist?('/etc/syslog.conf')
				`mv /etc/syslog.conf /etc/syslog.conf.old`
			end
			File.open('/etc/syslog.conf', 'a') { |file| 
				file.puts "# redirect logging to remote server\n*.*                                                     @10.2.3.224\n\n"
				file.puts "# Log anything (except mail) of level info or higher.\n# Don't log private authentication messages!\n*.info;mail.none;authpriv.none;cron.none		/var/log/messages\n\n# The authpriv file has restricted access.\nauthpriv.*						/var/log/secure\n\n# Log all the mail messages in one place.\nmail.*							-/var/log/maillog\n\n"
				file.puts "# Log cron stuff\ncron.*							/var/log/cron\n\n"
				file.puts "# Everybody gets emergency messages\n*.emerg							*\n\n"
				file.puts "# Save news errors of level crit and higher in a special file.\nuucp,news.crit						/var/log/spooler\n"
				file.puts "# Save boot messages also to boot.log\nlocal7.*						/var/log/boot.log\n"
				`chmod 700 /etc/syslog.conf`
			}
		end
		def restartSyslog
			`service syslog restart`
		end
	end
end
