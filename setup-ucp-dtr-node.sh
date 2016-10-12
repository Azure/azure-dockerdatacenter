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

curl --insecure https://$MASTERFQDN/ca > ca.pem

FPRINT=$(openssl x509 -in ca.pem -noout -sha256 -fingerprint | awk -F= '{ print $2 }' )

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
 echo $(date) " - UCP installed and started on the agent node"
else
 echo $(date) " -- UCP installation failed"
fi


echo $(date) " - Setting up UCP Client Bundle"

# Download the client certificate bundle

AUTHTOKEN=$(curl -sk -d '{"username":"'$USER'","password":"'$PASSWORD'"}' https://$MASTERPRIVATEIP/auth/login | jq -r .auth_token)
curl -k -H "Authorization: Bearer $AUTHTOKEN" https://$MASTERPRIVATEIP/api/clientbundle -o bundle.zip
unzip -q bundle.zip
source env.sh

# Implementing delay before installing DTR

echo $(date) "Sleeping for $SLEEP"
sleep $SLEEP

# Get the certificates used by UCP

echo $(date) " - Configuring DTR on master DTR node"

curl -k $UCP_URL/ca > ucp-ca.pem

# Install DTR
docker run -i --rm \
  docker/dtr:2.1.0-beta1 install \
  --ucp-url $UCP_URL \
  --ucp-node $UCP_NODE \
  --dtr-external-url $DTR_PUBLIC_IP \
  --ucp-username $USER --ucp-password $PASSWORD \
  --replica-id $REPLICA_ID"0" \
  --ucp-ca "$(cat ucp-ca.pem)"
  
if [ $? -eq 0 ]
then
echo $(date) " - Completed DTR installation on master DTR node"
else
 echo $(date) " - DTR installation on master DTR node failed"
fi


for ((loop=1; loop<=$COUNT; loop++))
do

echo $(date) " - Start DTR installation on replica DTR node"  

# Install DTR Replica
docker run -i --rm \
docker/dtr:2.1.0-beta1 join \
--ucp-url $UCP_URL \
--ucp-node $UCP_NODE_REP$loop$UCP_NODE_SUF \
--replica-id $REPLICA_ID$loop \
--existing-replica-id $REPLICA_ID"0" \
--ucp-username $USER --ucp-password $PASSWORD \
--ucp-ca "$(cat ucp-ca.pem)"
  
if [ $? -eq 0 ]
then
 echo $(date) " - Completed DTR installation on replica DTR node - $UCP_NODE_REP$loop$UCP_NODE_SUF"
else
 echo $(date) " -- DTR installation on replica DTR node - $UCP_NODE_REP$loop$UCP_NODE_SUF failed"
fi


sleep 20

done

echo $(date) " - Completed DTR installation on Master and all replica DTR nodes"
