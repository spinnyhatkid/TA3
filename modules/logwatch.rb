module LogwatchInstall
	class InstallLogwatchClient
		def initalialize
		end
		def install
			puts "Installing logwatch...."
			`yum install logwatch -y`
			puts "Installing logwatch....Done"
		end
		def configure
			`mv /usr/share/logwatch/default.conf/logwatch.conf /usr/share/logwatch/default.conf/logwatch.conf.old`
			`cp client_logwatch /usr/share/logwatch/default.conf/logwatch.conf`
		end
	end
	class InstallLogwatchServer
		def initalialize
		end
		def install
			puts "Installing logwatch...."
			`yum install logwatch -y`
			puts "Installing logwatch....Done"
		end
		def configure
			`mv /usr/share/logwatch/default.conf/logwatch.conf /usr/share/logwatch/default.conf/logwatch.conf.old`
			`cp server_logwatch /usr/share/logwatch/default.conf/logwatch.conf`
		end
	end
end


