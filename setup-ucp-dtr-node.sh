#!/bin/bash
#should work for all skus
#set -x
#set -xeuo pipefail

#if [[ $(id -u) -ne 0 ]] ; then
#    echo "Must be run as root"
#    exit 1
#fi
# We need five params: (1) PASSWORD (2) MASTERFQDN (3) DTR_PUBLIC_IP (4) REPLICA_ID (5) MASTERPRIVATEIP (6) UCP_NODE_REP (7) COUNT (8) SLEEP

echo $(date) " - Starting Script"

USER=admin
PASSWORD=$1
MASTERFQDN=$2
UCP_URL=https://$2
UCP_NODE=$(hostname)
DTR_PUBLIC_IP=$3
REPLICA_ID=$4
MASTERPRIVATEIP=$5
UCP_NODE_REP=$6
UCP_NODE_SUF=-ucpdtrnode
COUNT=$7
SLEEP=$8
DTR_PUBLIC_URL=https://$3
omsworkspaceid=$( echo "$9" |cut -d\: -f1 )
omsworkspacekey=$( echo "$9" |cut -d\: -f2 )
omslnxagentver=$( echo "$9" |cut -d\: -f3 )
if [ ! -z "$omsworkspaceid" ]; then

echo  "omsworkspaceid is" $omsworkspaceid
else
echo "All are respectively " $1 $2 $3 $4
fi
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
echo 'deb https://packages.docker.com/1.12/apt/repo ubuntu-trusty testing' >> /etc/apt/sources.list.d/docker.list
apt-cache policy docker-engine
DEBIAN_FRONTEND=noninteractive apt-get -y update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
curl -L https://github.com/docker/compose/releases/download/1.9.0-rc4/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
curl -L https://github.com/docker/machine/releases/download/v0.8.2/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-compose
export PATH=$PATH:/usr/local/bin/
groupadd docker
usermod -aG docker ucpadmin
service docker restart
}
install_docker_tools;
if [ ! -z "$omsworkspaceid" ]; then
sleep 45;
instrumentfluentd_docker;
sleep 30;
installomsagent;
fi

installbundle ()
{

echo $(date) "Sleeping for $SLEEP"
sleep $SLEEP
echo $(date) " - Staring Swarm Join as worker UCP Controller"
apt-get -y update && apt-get install -y curl jq
# Create an environment variable with the user security token
AUTHTOKEN=$(curl -sk -d '{"username":"admin","password":"'"$PASSWORD"'"}' https://$MASTERPRIVATEIP/auth/login | jq -r .auth_token)
echo "$AUTHTOKEN"
# Download the client certificate bundle
curl -k -H "Authorization: Bearer ${AUTHTOKEN}" https://$MASTERPRIVATEIP/api/clientbundle -o bundle.zip
unzip -o bundle.zip && chmod +x env.sh && source env.sh
}
joinucp() {
installbundle;
#docker swarm join-token worker|sed '1d'|sed '1d'|sed '$ d'>swarmjoin.sh
docker swarm join-token worker|sed '1d'|sed '1d'|sed '$ d'> /usr/local/bin/docker-workerswarmjoin
unset DOCKER_TLS_VERIFY
unset DOCKER_CERT_PATH
unset DOCKER_HOST
#chmod 755 swarmjoin.sh
chmod +x /usr/local/bin/docker-workerswarmjoin
export PATH=$PATH:/usr/local/bin/
docker-workerswarmjoin
#source swarmjoin.sh
}
## Insecure TLS as self signed will fail -- Failed to get bootstrap client: Failed to get UCP CA: Get https://blahblah/ca: x509: certificate signed by unknown authority
installdtr() {
installbundle;
echo $(date) " - Loading docker install Tar"
#cd /opt/ucp && wget https://s3.amazonaws.com/packages.docker.com/caas/ucp-2.0.0-beta3_dtr-2.1.0-beta3.tar.gz
cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta4_dtr-2.1.0-beta4.tar.gz
docker load < ucp-2.0.0-beta4_dtr-2.1.0-beta4.tar.gz
# Implement delay timer to stagger load of the bits - docker.com CDN Dependent
sleep 45;
echo $(date) " - Loading complete.  Starting UCP Install"
# Start installation of UCP with master Controller
docker run --rm  \
  docker/dtr:2.1.0-beta4 install \
  --ucp-node $UCP_NODE \
  --ucp-insecure-tls \
  --dtr-external-url $DTR_PUBLIC_URL  \
  --ucp-url https://$MASTERFQDN \
  --ucp-username admin --ucp-password $PASSWORD
  }
joinucp;
# Implement delay timer to stagger joining of Agent Nodes to cluster
echo $(date) "Sleeping for 45"
sleep 60;
# Install DTR
installdtr;

 if [ $? -eq 0 ]
 then
 echo $(date) " - Completed DTR installation on master DTR node"
 else
  echo $(date) " - DTR installation on master DTR node failed"
 fi
 
 
 # Install DTR for replica placeholder
 #docker run -it --rm \
 #  dockerhubenterprise/dtr:2.1.0-beta1 install \
 #  --ucp-node $UCP_NODE \
 #  --ucp-insecure-tls \
 #  --dtr-external-url https://dlbpipddcdev01.westeurope.cloudapp.azure.com:443  \
 #  --ucp-url https://ucpclus0-ucpctrl \
 #  --ucp-username admin --ucp-password $PASSWORD \
 # --replica-id $REPLICA_ID"0"
  
  
  


 ###########################
 # WIP - TBC for BETA and/or GA (UCP 2.0.0 and DTR 2.10
 ###########################
 for ((loop=1; loop<=$COUNT; loop++))
 do
 
 echo $(date) " - Start DTR installation on replica DTR node"  
 #joinucp()
 # Install DTR Replica
docker run -it --rm \
docker/dtr:2.1.0-beta4 join \
 --ucp-url $UCP_URL \
 --ucp-node $UCP_NODE_REP$loop$UCP_NODE_SUF \
   --ucp-insecure-tls \
 --replica-id $REPLICA_ID$loop \
 --existing-replica-id $REPLICA_ID"0" \
 --ucp-username $USER --ucp-password $PASSWORD 
   
 if [ $? -eq 0 ]
 then
  echo $(date) " - Completed DTR installation on replica DTR node - $UCP_NODE_REP$loop$UCP_NODE_SUF"
 else
  echo $(date) " -- DTR installation on replica DTR node - $UCP_NODE_REP$loop$UCP_NODE_SUF failed"
 fi
  
 sleep 20
 
 done
 
echo $(date) " - Completed DTR installation on Master and all replica DTR nodes"

