#!/bin/bash
#should work for all skus
#set -x
#set -xeuo pipefail

#if [[ $(id -u) -ne 0 ]] ; then
#    echo "Must be run as root"
#   exit 1
#fi
echo $(date) " - Starting Script"

PASSWORD=$1
MASTERFQDN=$2
#FILEURI=$3
MASTERPRIVATEIP=$3
DTRFQDN=$7
NFQDN=$8

if [ ! -z "$4" ]; then
omsworkspaceid=$4

omsworkspacekey=$5

omslnxagentver=$6

echo "All are respectively " $1 $2 $3 $4 $5 $6
echo  "MASTER FQDN is" $MASTERFQDN
echo  "omsworkspaceid is" $omsworkspaceid
echo  "omsworkspacekey is" $omsworkspacekey
echo  "omslnxagentver is" $omslnxagentver
else
echo "All are respectively " $1 $2 $3
echo  "MASTER FQDN is" $MASTERFQDN
fi

install_license()
{
#copy license key to /opt/ucp/ucp
cat > /opt/ucp/docker_subscription.lic <<EOF
'$FILEURI'
EOF

# removing a special character from subscription.lic
sed -i -- "s/'//g" /opt/ucp/docker_subscription.lic
sed -i -- "s/{/{\"/g" /opt/ucp/docker_subscription.lic
sed -i -- "s/}/\"}/g" /opt/ucp/docker_subscription.lic
sed -i -- "s/:/\":/g" /opt/ucp/docker_subscription.lic
sed -i -- "s/,\ /,\ \"/g" /opt/ucp/docker_subscription.lic   
#wget "$FILEURI" -O /opt/ucp/docker_subscription.lic
}

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
if [ ! -z "$4" ]; then
sleep 45;
instrumentfluentd_docker;
sleep 30;
installomsagent;
fi

# Fix for Docker Daemon when cloning a base image
# rm  /etc/docker/key.json  
# service docker restart
# Load the downloaded Tar File
sleep 45;
echo  " - Loading docker install Tar"
#cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz
#cd /opt/ucp && wget https://s3.amazonaws.com/packages.docker.com/caas/ucp-2.0.0-beta3_dtr-2.1.0-beta3.tar.gz
cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta4_dtr-2.1.0-beta4.tar.gz
#cd /opt/ucp && wget https://packages.docker.com/caas/ucp-1.1.4_dtr-2.0.3.tar.gz
#docker load < /opt/ucp/ucp-1.1.2_dtr-2.0.2.tar.gz
#docker load < /opt/ucp/ucp-1.1.4_dtr-2.0.3.tar.gz
#docker load < ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz
docker load < ucp-2.0.0-beta4_dtr-2.1.0-beta4.tar.gz

# Start installation of UCP with master Controller

echo " - Loading complete.  Starting UCP Install"

#docker run --rm -i \
#    --name ucp \
#    -v /var/run/docker.sock:/var/run/docker.sock \
#    -v /opt/ucp/docker_subscription.lic:/docker_subscription.lic \
#    -e UCP_ADMIN_PASSWORD=$PASSWORD \
#    docker/ucp:2.0.0-beta1 \
#    install -D --host-address eth0
    
docker run --rm -i \
    --name ucp \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e UCP_ADMIN_PASSWORD=$PASSWORD \
    docker/ucp:2.0.0-beta4 \
    install -D --san $MASTERFQDN --san $DTRFQDN --san $NFQDN --host-address eth0
#docker run --rm -i \
#    --name ucp \
#    -v /var/run/docker.sock:/var/run/docker.sock \
#    -e UCP_ADMIN_PASSWORD=$PASSWORD \
#    docker/ucp:2.0.0-beta4 \
#    install -D --san $MASTERFQDN --san $DTRFQDN --san $NFQDN --host-address $MASTERFQDN
if [ $? -eq 0 ]
then
 echo  " - UCP installed and started on the master Controller"
else
 echo " -- UCP installation failed"
fi

