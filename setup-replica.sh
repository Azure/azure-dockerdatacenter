#!/bin/bash
#should work for all skus
#set -x
#set -xeuo pipefail

#if [[ $(id -u) -ne 0 ]] ; then
#    echo "Must be run as root"
#    exit 1
#fi
# We need four params: (1) PASSWORD (2) MASTERFQDN (3) MASTERPRIVATEIP (4) SLEEP

echo $(date) " - Starting Script"

PASSWORD=$1
MASTERFQDN=$2
MASTERPRIVATEIP=$3
SLEEP=$4
if [ ! -z "$5" ]; then
omsworkspaceid=$5
omsworkspacekey=$6
omslnxagentver=$7

echo "All are respectively " $1 $2 $3 $4 $5 $6 $7
echo  "omsworkspaceid is" $omsworkspaceid
echo  "omsworkspacekey is" $omsworkspacekey
echo  "omslnxagentver is" $omslnxagentver
else
echo "All are respectively " $1 $2 $3 $4
fi

# Implement delay timer to stagger joining of Controller replicas to cluster

installomsagent()
{
wget https://github.com/Microsoft/OMS-Agent-for-Linux/releases/download/OMSAgent_Ignite2016_v$omslnxagentver/omsagent-${omslnxagentver}.universal.x64.sh
chmod +x ./omsagent-${omslnxagentver}.universal.x64.sh
md5sum ./omsagent-${omslnxagentver}.universal.x64.sh
sudo sh ./omsagent-${omslnxagentver}.universal.x64.sh --upgrade -w $omsworkspaceid -s $omsworkspacekey
}

instrumentfluentd_docker()
{
cd /etc/systemd/system/multi-user.target.wants/ && sed -i.bak -e '12d' docker.service
cd /etc/systemd/system/multi-user.target.wants/ && sed -i '12iEnvironment="DOCKER_OPTS=--log-driver=fluentd --log-opt fluentd-address=localhost:25225"' docker.service
cd /etc/systemd/system/multi-user.target.wants/ && sed -i '13iExecStart=/usr/bin/dockerd -H fd:// $DOCKER_OPTS' docker.service
service docker restart
}
install_docker_tools()
{
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
curl -L https://github.com/docker/compose/releases/download/1.9.0-rc3/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
curl -L https://github.com/docker/machine/releases/download/v0.8.2/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-compose
export PATH=$PATH:/usr/local/bin/
groupadd docker
usermod -aG docker ucpadmin
service docker restart
}
install_docker_tools;
if [ ! -z "$5" ]; then
sleep 45;
instrumentfluentd_docker;
sleep 30;
installomsagent;
fi



echo $(date) "Sleeping for $SLEEP"
sleep $SLEEP
# Retrieve Fingerprint from Master Controller
curl --insecure https://$MASTERFQDN/ca > ca.pem
FPRINT=$(openssl x509 -in ca.pem -noout -sha256 -fingerprint | awk -F= '{ print $2 }' )
echo $FPRINT

# Load the downloaded Tar File

#cd /opt/ucp && wget https://s3.amazonaws.com/packages.docker.com/caas/ucp-2.0.0-beta3_dtr-2.1.0-beta3.tar.gz
cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta3_dtr-2.1.0-beta3.tar.gz
docker load < ucp-2.0.0-beta3_dtr-2.1.0-beta3.tar.gz

# Start installation of UCP and join Controller replica to master Controller

#docker run --rm -i \
#   --name ucp \
#    -v /var/run/docker.sock:/var/run/docker.sock \
#    -e UCP_ADMIN_USER=admin \
#    -e UCP_ADMIN_PASSWORD=$PASSWORD \
#    docker/ucp:2.0.0-beta1 \
#    join --replica --san $MASTERPRIVATEIP --url https://$MASTERPRIVATEIP --fingerprint "${FPRINT}"

docker run --rm -i \
   --name ucp \
   -v /var/run/docker.sock:/var/run/docker.sock \
   -e UCP_ADMIN_USER=admin \
   -e UCP_ADMIN_PASSWORD=$PASSWORD \
    docker/ucp:2.0.0-beta3 \
    join --replica --san $MASTERFQDN--url https://$MASTERFQDN --fingerprint "${FPRINT}"

if [ $? -eq 0 ]
then
echo $(date) " - UCP installed and started on the master(replica) Controller"
else
 echo $(date) " -- UCP installation failed"
fi

echo $(date) " - Staring Swarm Join as Manager to Leader UCP Controller"
apt-get -y update && apt-get install -y curl jq
# Create an environment variable with the user security token
AUTHTOKEN=$(curl -sk -d '{"username":"admin","password":"'"$PASSWORD"'"}' https://$MASTERPRIVATEIP/auth/login | jq -r .auth_token)
echo "$AUTHTOKEN"
# Download the client certificate bundle
curl -k -H "Authorization: Bearer ${AUTHTOKEN}" https://$MASTERPRIVATEIP/api/clientbundle -o bundle.zip
unzip bundle.zip && chmod +x env.sh && source env.sh
#docker swarm join-token manager|sed '1d'|sed '1d'|sed '$ d'>swarmjoin.sh
docker swarm join-token manager|sed '1d'|sed '1d'|sed '$ d'> /usr/local/bin/docker-managerswarmjoin
unset DOCKER_TLS_VERIFY
unset DOCKER_CERT_PATH
unset DOCKER_HOST
#chmod 755 swarmjoin.sh
chmod +x /usr/local/bin/docker-managerswarmjoin
export PATH=$PATH:/usr/local/bin/
docker-managerswarmjoin
#source swarmjoin.sh
