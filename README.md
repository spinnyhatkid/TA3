TA3
===

Monitor server & client services

Usage: install.rb [options] REQUIRED OPTIONS: -i -n.
    -a, --addonly                    Only add hosts to nagios server, Nothing else will be installed.
    -i, --ip ADDRESS                 IPv4 client IP ADDRESS.  IP address points toward the server when used with -c.
    -c, --client                     Installs as client.  Only the first IP and HOSTNAME will be used to configure a connection with the server.
    -m, --mask MASK                  CIDR subnet mask for port access.  Assumes CIDR/8 if nothing given.
    -r, --reload                     Tests and restarts nagios, This may be required after installing all hosts since this will fail if the host is not installed at the time you are attempting to test and restart the Nagios service
    -n, --names HOSTNAMES            Installs client configurations for nagios or server configurations if used with -c --client. 
				 	Requires the use of -i --ip <server_ip> to properly configure the server/clients. 
				 	Syntax: <NAME>,<NAME>...  Number of hosts must match number of IP addresses supplied.
    -h, --help                       Configures monitoring for chosen clients or a server.

# Nagios Install
* Nagios server is installed via the -i ClientIp,Clientip... -n ClientName,ClientName... -m Subnetmask(optional) options.  Values for the -i and -n options are separated with commas alone, included spaces will cause issues.
* After installation of the client Nagios and server Nagios the -r option needs to be used on the server.  Failure to have all the clients installed will cause this to fail and the Nagios service will not run until all the clients are installed.
* Installing a nagios client is the same as installing the server except the -i options takes the server ip address alone and the -n option takes the name of the client you are on.  The -c option is also require as it tells the script it is installing a client.
* Using the -a option for the server will skip installation of Nagios all together.  The script will attempt to detect Nagios and skip installation if Nagios is already installed however the -a option will force Nagios to skip the installation step.

# Sendmail install
* Installing sendmail is the exact same command as installing Nagios on the server or the client

# Monit install
* Installed during client install
