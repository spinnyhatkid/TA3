require 'optparse'
require 'ipaddr'
require "#{Dir.pwd}/modules/nagios"
require "#{Dir.pwd}/modules/sendmail"
require "#{Dir.pwd}/modules/monit"

class ConfigServerMonitoring
  include NagiosInstall
  include SendmailInstall
  
  def initialize(options)
    @ip = options[:ip]
    @mask = options[:mask]
    @hostnames = options[:names]
    @addonly = options[:addonly]
  end
  
  def install
    begin
      nagios = `service nagios status 2>&1` != "nagios: unrecognized service\n"
      puts "Nagios service already installed, moving to add Nagios hosts only" if nagios
      if @addonly || nagios
	nserver = ServerNagios.new(@ip,@hostnames)
	nserver.addNagiosHosts
      else
	nserver = ServerNagios.new(@ip, @hostnames)
	nserver.installNagios
	nserver.addNagiosHosts
      end
      
      sip = `ifconfig $1 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1'`.chop
      if !File.open('/etc/mail/sendmail.cf').read().index('cit470.nku.edu')
        smserver = ServerSendmail.new(sip, @ip, @hostnames)
        smserver.installSendmail
      else
        smserver = ServerSendmail.new(sip, @ip, @hostnames)
        smserver.updateHosts
	smserver.updateAccessdb
      end
    rescue
      puts "\e[31mSomething went wrong please check the logs.\e[0m"
    end
  end
end

class ConfigClientMonitoring
  include NagiosInstall
  include SendmailInstall
  include MonitInstall

  def initialize(options)
    @ip = options[:ip]
    @mask = options[:mask]
    @hostnames = options[:names]
  end
  
  def install
    begin
      nagios = `service nagios status 2>&1` != "nagios: unrecognized service\n"
      if nagios
	puts "Nagios service already installed, nothing to do"
      else
	nclient = ClientNagios.new(@ip, @hostnames)
	nclient.installNagios
      end
      
      if !File.open('/etc/mail/sendmail.cf').read().index('cit470.nku.edu')
        sip = `ifconfig $1 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1'`.chop
        smclient = ClientSendmail.new(sip, @ip, @hostnames)
        smclient.installSendmail
      end

      if !File.exists?('/etc/monitrc')
        monitclient = ClientMonit.new
        monitclient.installMonit
      end
    rescue
      puts "\e[31mSomething went wrong please check the logs.\e[0m"
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: install.rb [options] REQUIRED OPTIONS: -i -n."

  options[:addonly] = nil
  opts.on('-a', '--addonly', 'Only add hosts to nagios server, Nothing else will be installed.') do |add|
    options[:addonly] = true
  end

  options[:ip] = nil
  opts.on('-i', '--ip ADDRESS', 'IPv4 client IP ADDRESS.  IP address points toward the server when used with -c.') do |ip|
    if ip =~ /^((\d{1,3}\.){3}\d{1,3}(,){0,1})*$/
      options[:ip] = ip.split(",")
    else
      puts "\e[31mInvalid IP address, Format: xxx.xxx.xxx.xxx,xxx.xxx.xxx.xxx...\e[0m"
      exit
    end
  end

  options[:client] = nil
  opts.on('-c', '--client', 'Installs as client.  Only the first IP and HOSTNAME will be used to configure a connection with the server.') do |client|
    options[:client] = true
  end

  options[:mask] = "255.0.0.0"
  opts.on('-m', '--mask MASK', 'CIDR subnet mask for port access.  Assumes CIDR/8 if nothing given.') do |mask|
    begin
      if mask.to_i.between? 0, 32
        options[:mask] = IPAddr.new('255.255.255.255').mask(mask).to_s
      else
        puts "\e[31mInvalid mask, Please be sure that the CIDR mask is a number between 0 and 32\e[0m"
        exit
      end
    rescue 
      puts "\e[31mInvalid mask, Please be sure that the CIDR mask is a number between 0 and 32\e[0m"
      exit
    end
  end

  options[:names] = nil
  opts.on('-n', '--names HOSTNAMES', 
	"Installs client configurations for nagios or server configurations if used with -c --client. \n\t\t\t\t \
	Requires the use of -i --ip <server_ip> to properly configure the server/clients. \n\t\t\t\t \
	Syntax: <NAME>,<NAME>...  Number of hosts must match number of IP addresses supplied.") do |names|
      options[:names] = names.split(",")
  end

  opts.on_tail("-h", "--help", "Configures monitoring for chosen clients or a server.") do
    puts opts
    exit
  end
end.parse!

begin

raise OptionParser::MissingArgument if options[:ip].nil? || options[:names].nil? || options[:ip].length != options[:names].length

cm = options[:client] ? ConfigClientMonitoring.new(options) : ConfigServerMonitoring.new(options)
cm.install

rescue
  puts "\e[31mThe -p --ip ADDRESS and -n --names HOSTNAMES options are required.\nIf the amount of ADDRESSES and HOSTNAMES don't match this error will be thrown as well.\e[0m"
end
