# We need four params: (1) PASSWORD (2) MASTERFQDN (3) REPLICA_ID (4) MASTERPRIVATEIP (5) DTRNODE (6) SLEEP

echo $(date) " - Starting Script"

USER=admin
PASSWORD=$1
MASTERFQDN=$2
UCP_URL=https://$4
UCP_NODE=$(hostname)
REPLICA_ID=$3
MASTERPRIVATEIP=$4
DTRNODE=$5
SLEEP= $6

# System Update and docker version update
DEBIAN_FRONTEND=noninteractiv apt-get update -y
apt-get install -y apt-transport-https ca-certificates
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo ubuntu-trusty main' >> /etc/apt/sources.list.d/docker.list
apt-cache -y policy docker-engine
DEBIAN_FRONTEND=noninteractiv apt-get update -y


# Implement delay timer to stagger joining of Agent Nodes to cluster

echo $(date) "Sleeping for $SLEEP"
sleep $SLEEP

# Retrieve Fingerprint from Master Controller

curl --insecure https://$MASTERFQDN/ca > ca.pem

FPRINT=$(openssl x509 -in ca.pem -noout -sha256 -fingerprint | awk -F= '{ print $2 }' )

echo $FPRINT

# Load the downloaded Tar File

echo $(date) " - Loading docker install Tar"
cd /opt/ucp && wget https://packages.docker.com/caas/ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz
#cd /opt/ucp && wget https://packages.docker.com/caas/ucp-1.1.4_dtr-2.0.3.tar.gz
#docker load < /opt/ucp/ucp-1.1.2_dtr-2.0.2.tar.gz
#docker load < /opt/ucp/ucp-1.1.4_dtr-2.0.3.tar.gz
docker load < ucp-2.0.0-beta1_dtr-2.1.0-beta1.tar.gz

# Start installation of UCP and join agent Nodes to cluster

echo $(date) " - Loading complete.  Starting UCP Install of agent node"

docker run --rm -i \
    --name ucp \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e UCP_ADMIN_USER=admin \
    -e UCP_ADMIN_PASSWORD=$PASSWORD \
    docker/ucp:2.0.0-beta1 \
    join --san $MASTERFQDN --fresh-install --url https://${MASTERFQDN}:443 --fingerprint "${FPRINT}"

if [ $? -eq 0 ]
then
 echo $(date) " - UCP installed and started on the agent node to be used for DTR replica"
else
 echo $(date) " -- UCP installation failed on DTR node"
fi
