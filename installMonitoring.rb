#!/usr/bin/env ruby

require 'optparse'
require 'ipaddr'
require "#{Dir.pwd}/modules/nagios"
require "#{Dir.pwd}/modules/sendmail"
require "#{Dir.pwd}/modules/monit"
ORIG_STD_OUT = STDOUT.clone
ORIG_STD_ERR = STDERR.clone

class ConfigServerMonitoring
  include NagiosInstall
  include SendmailInstall
  
  def initialize(options)
    @ip = options[:ip]
    @mask = options[:mask]
    @hostnames = options[:names]
    @addonly = options[:addonly]
    STDOUT.reopen(File.open('Monitor.txt', 'a'))
    STDERR.reopen(File.open('Monitor.txt', 'a'))
  end
  
  #runs through the various modules to install the server
  def install
    begin
      nagios = `service nagios status 2>&1` != "nagios: unrecognized service\n"
      puts "Nagios service already installed, moving to add Nagios hosts only" if nagios
      if @addonly || nagios
	nserver = ServerNagios.new(@ip,@hostnames, @mask)
	nserver.addNagiosHosts
      else
	nserver = ServerNagios.new(@ip, @hostnames, @mask)
	nserver.installNagios
	nserver.addNagiosHosts
      end
      
      sip = `ifconfig $1 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}' | grep -v '127.0.0.1'`.chop
      if !File.open('/etc/mail/sendmail.cf').read().index('cit470.nku.edu')
        smserver = ServerSendmail.new(sip, @ip, @hostnames, @mask)
        smserver.installSendmail
      else
        smserver = ServerSendmail.new(sip, @ip, @hostnames, @mask)
        smserver.updateHosts
	smserver.updateAccessdb
      end
    rescue Exception => msg
      puts msg
      STDOUT.reopen(ORIG_STD_OUT)
      STDERR.reopen(ORIG_STD_ERR)
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
    STDOUT.reopen(File.open('Monitor.txt', 'a'))
    STDERR.reopen(File.open('Monitor.txt', 'a'))
  end
  
  #runs through the various modules to install the client
  def install
    begin
      nagios = File.exists?('/usr/local/nagios')
      if nagios
	puts "Nagios service already installed, nothing to do"
      else
	nclient = ClientNagios.new(@ip, @hostnames, @mask)
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
    rescue Exception => msg
      puts msg
      STDOUT.reopen(ORIG_STD_OUT)
      STDERR.reopen(ORIG_STD_ERR)
      puts "\e[31mSomething went wrong please check the logs.\e[0m"
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: install.rb [options] REQUIRED OPTIONS: -i -n."

  #only add clients to the server and dont install nagios
  options[:addonly] = nil
  opts.on('-a', '--addonly', 'Only add hosts to nagios server, Nothing else will be installed.') do |add|
    options[:addonly] = true
  end

  #given ip addresses used to configure connections between the client and server
  options[:ip] = nil
  opts.on('-i', '--ip ADDRESS', 'IPv4 client IP ADDRESS.  IP address points toward the server when used with -c.') do |ip|
    if ip =~ /^((\d{1,3}\.){3}\d{1,3}(,){0,1})*$/
      options[:ip] = ip.split(",")
    else
      puts "\e[31mInvalid IP address, Format: xxx.xxx.xxx.xxx,xxx.xxx.xxx.xxx...\e[0m"
      exit
    end
  end

  #install as client, the ip connection given is used as the servers ip
  options[:client] = nil
  opts.on('-c', '--client', 'Installs as client.  Only the first IP and HOSTNAME will be used to configure a connection with the server.') do |client|
    options[:client] = true
  end

  #accept a given subnet mask
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

  #reload the nagios server to pick up newly installed clients, doesn't do it by defaults since the clients need to be installed before the server can be restarted with them.
  opts.on('-r', '--reload', "Tests and restarts nagios, This may be required after installing all hosts since this will fail if the host is not installed at the time you are attempting to test and restart the Nagios service") do |restart|
    begin
      nr = ConfigServerMonitoring::ServerNagios.new(nil,nil,nil)
      nr.verifyStart
      exit
    rescue
      puts "\e[31mRestart failed.\e[0m"
    end
  end

  #client hostnames
  options[:names] = nil
  opts.on('-n', '--names HOSTNAMES', 
	"Installs client configurations for nagios or server configurations if used with -c --client. \n\t\t\t\t \
	Requires the use of -i --ip <server_ip> to properly configure the server/clients. \n\t\t\t\t \
	Syntax: <NAME>,<NAME>...  Number of hosts must match number of IP addresses supplied.") do |names|
      options[:names] = names.split(",")
  end

  #display help message
  opts.on_tail("-h", "--help", "Configures monitoring for chosen clients or a server.") do
    puts opts
    exit
  end
end.parse!

begin

#raise an error if the ip or hostnames are missing or don't have an equal number for configuration
raise OptionParser::MissingArgument if options[:ip].nil? || options[:names].nil? || options[:ip].length != options[:names].length

cm = options[:client] ? ConfigClientMonitoring.new(options) : ConfigServerMonitoring.new(options)
cm.install

rescue
  puts "\e[31mThe -p --ip ADDRESS and -n --names HOSTNAMES options are required.\nIf the amount of ADDRESSES and HOSTNAMES don't match this error will be thrown as well.\e[0m"
end
