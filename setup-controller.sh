
echo $(date) " - Starting Script"

PASSWORD=$1
MASTERFQDN=$2
# Key not FILEURI - to be changed
FILEURI=$3
MASTERPRIVATEIP=$4

INTERLOCK_CONFIG='
ListenAddr = ":8080"
DockerURL = "'$MASTERPRIVATEIP':2376"
TLSCACert = "/certs/ca.pem"
TLSCert = "/certs/cert.pem"
TLSKey = "/certs/key.pem"
PollInterval = "2s"
[[Extensions]]
Name = "nginx"
ConfigPath = "/etc/nginx/nginx.conf"
PidPath = "/etc/nginx/nginx.pid"
MaxConn = 1024
Port = 80
SSLCertPath = ""
SSLCert = ""
SSLPort = 443
SSLOpts = ""
User = "www-data"
WorkerProcesses = 2
RLimitNoFile = 65535
ProxyConnectTimeout = 600
ProxySendTimeout = 600
ProxyReadTimeout = 600
SendTimeout = 600
SSLCiphers = "HIGH:!aNULL:!MD5"
SSLProtocols = "SSLv3 TLSv1 TLSv1.1 TLSv1.2"'

#copy license key to /opt/ucp/ucp
cat > /opt/ucp/docker_subscription.lic <<EOF
'$FILEURI'
EOF
     
#wget "$FILEURI" -O /opt/ucp/docker_subscription.lic

# Fix for Docker Daemon when cloning a base image
# rm  /etc/docker/key.json  
# service docker restart

# Load the downloaded Tar File

echo $(date) " - Loading docker install Tar"
cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz
#cd /opt/ucp && wget https://packages.docker.com/caas/ucp-1.1.4_dtr-2.0.3.tar.gz
#docker load < /opt/ucp/ucp-1.1.2_dtr-2.0.2.tar.gz
#docker load < /opt/ucp/ucp-1.1.4_dtr-2.0.3.tar.gz
docker load < ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz

# Start installation of UCP with master Controller

echo $(date) " - Loading complete.  Starting UCP Install"

docker run --rm -i \
    --name ucp \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /opt/ucp/docker_subscription.lic:/docker_subscription.lic \
    -e UCP_ADMIN_PASSWORD=$PASSWORD \
    docker/ucp:2.0.0-beta1 \
    install -D --fresh-install --san $MASTERFQDN

if [ $? -eq 0 ]
then
 echo $(date) " - UCP installed and started on the master Controller"
else
 echo $(date) " -- UCP installation failed"
fi

# Configure NginX for Interlock  

echo $(date) " - Initiating NginX and interlock configuration on the master"

docker run -d \
 -e INTERLOCK_CONFIG="$INTERLOCK_CONFIG" \
 -v ucp-node-certs:/certs \
 -p 8080:8080 \
 --restart=always \
 ehazlett/interlock:1.2.0 \
 -D run

if [ $? -eq 0 ]
then
 echo $(date) " -- NginX and interlock config complete"
else
 echo $(date) " -- NEP om installation failed"
fi
