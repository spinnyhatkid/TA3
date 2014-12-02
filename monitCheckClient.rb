#!/usr/bin/env ruby

failures = 0

######################################
######## TEST SERVICE RESTART ########
######################################

#Services to be killed
services = ['sendmail', 'syslog', 'sshd']
services.length.times do |s|
  serviceName = services[s]
  numproc = `service #{serviceName} status 2>&1`.split("\n").length
  displaykill = true  
 
  #Looped incase multiple processes are involved in running a service, Ensures they are all killed
  numproc.times do
    service = `service #{serviceName} status 2>&1`.split
    service = service[2].chop
    `kill #{service}`

    #If the pid has been aquired wait for monit to restart the service else mark a failure
    if service =~ /^\d*$/
      puts "\e[31m#{serviceName} service killed.\e[0m" if displaykill
      displaykill = false
      sleep(55)
    else
      failures += 1
      puts "\e[31m#{serviceName} service not running.\e[0m"
    end

  end

  mail = `tail /var/log/maillog -n 1`.split
  time = mail[2].split(":").first(2)
  mail = true if mail.include?('relay=cit470.nku.edu.') && mail.include?('stat=Sent') && time.first == Time.now.hour && time.last == Time.now.min
 
  #Check for stopped service and mark a failure if the service has not been restarted
  after = `service #{serviceName} status 2>&1`.split.include?('stopped')
  failures += 1 if after || !mail
  puts `service #{serviceName} status 2>&1`
end

####################################################
##########  TEST EMAIL ON PARTITION FILLUP #########
####################################################

part = ["/", "/var/"]
part.length.times do |x|
  prenum = `cat /var/log/maillog`.split("\n").length
  `dd if=/dev/zero of=#{part[x]}zero.tmp.txt bs=512 count=10000000`
  sleep(30)
  `rm -rf #{part[x]}zero.tmp.txt`

  mail = `tail /var/log/maillog -n 1`.split
  postnum = `cat /var/log/maillog`.split("\n").length
  mail = true if mail.include?('relay=cit470.nku.edu.') && mail.include?('stat=Sent')
  failures += 1 if prenum == postnum && mail != true
end

#Displays number of failures
color = failures == 0 ? 32 : 31
puts "\e[#{color}mFailures found: #{failures}\e[0m"
