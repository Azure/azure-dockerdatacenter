# We need four params: (1) PASSWORD (2) MASTERFQDN (3) MASTERPRIVATEIP (4) SLEEP

echo $(date) " - Starting Script"

PASSWORD=$1
MASTERFQDN=$2
MASTERPRIVATEIP=$3
SLEEP=$4

# Implement delay timer to stagger joining of Controller replicas to cluster

echo $(date) "Sleeping for $SLEEP"
sleep $SLEEP

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

# System Update and docker version update
DEBIAN_FRONTEND=noninteractive apt-get -y update
apt-get install -y apt-transport-https ca-certificates
#apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
#echo 'deb https://apt.dockerproject.org/repo ubuntu-trusty main' >> /etc/apt/sources.list.d/docker.list
curl -s 'https://sks-keyservers.net/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e' | apt-key add --import
echo 'deb https://packages.docker.com/1.12/apt/repo ubuntu-trusty main' >> /etc/apt/sources.list.d/docker.list
apt-cache policy docker-engine
DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

# Retrieve Fingerprint from Master Controller
#curl --insecure https://$MASTERFQDN/ca > ca.pem
#FPRINT=$(openssl x509 -in ca.pem -noout -sha256 -fingerprint | awk -F= '{ print $2 }' )
#echo $FPRINT

# Load the downloaded Tar File

#echo $(date) " - Loading docker install Tar"
#cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz
#docker load < ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz

# Start installation of UCP and join Controller replica to master Controller

#docker run --rm -i \
#    --name ucp \
#    -v /var/run/docker.sock:/var/run/docker.sock \
#    -e UCP_ADMIN_USER=admin \
#    -e UCP_ADMIN_PASSWORD=$PASSWORD \
#    docker/ucp:2.0.0-beta1 \
#    join --replica --san $MASTERFQDN --url https://${MASTERFQDN}:443 --fingerprint "${FPRINT}"

#if [ $? -eq 0 ]
#then
#echo $(date) " - UCP installed and started on the master(replica) Controller"
#else
# echo $(date) " -- UCP installation failed"
#fi


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
echo $(date) " - NginX and interlock config complete"
else
 echo $(date) " -- NginX and interlock config failed"
fi

echo $(date) " - Staring Swarm Join as Manager to Leader UCP Controller"
apt-get -y update && apt-get install -y curl jq
# Create an environment variable with the user security token
AUTHTOKEN=$(curl -sk -d '{"username":"admin","password":"'"$PASSWORD"'"}' https://ucpclus0-ucpctrl/auth/login | jq -r .auth_token)
echo "$AUTHTOKEN"
# Download the client certificate bundle
curl -k -H "Authorization: Bearer ${AUTHTOKEN}" https://ucpclus0-ucpctrl/api/clientbundle -o bundle.zip
unzip bundle.zip && chmod 755 env.sh && source env.sh
docker swarm join-token manager|sed '1d'|sed '1d'|sed '$ d'>swarmjoin.sh
unset DOCKER_TLS_VERIFY
unset DOCKER_CERT_PATH
unset DOCKER_HOST
chmod 755 swarmjoin.sh
source swarmjoin.sh
