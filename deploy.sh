# ELK
.PHONY: docker linux-pakcages build run

# Install docker
docker:
    @rpm -ivh docker*/*.rpm
    @systemctl enable --now docker

# Install linux packages
linux-packages:
    @rpm -ivh {htop*,nettools*,telnet*}.rpm

# set envs in .env file ********************************
# export vars
while IFS= read -r variable; do export "${variable?}"; done < <(grep -vE '^#|^$' .env)

# Configure docker daemon
if ! [[ -f /etc/docker/daemon.json ]]; then
    systemctl stop docker containerd.service docker.socket

    DOCKER_DIR_SIZE=$(du -ms /var/lib/docker/ | cut -f1)
    if [[ $DOCKER_DIR_SIZE -gt 200 ]]; then
        scp -rp /var/lib/docker "${DATA_DIR}/" && mv "${DATA_DIR}"/{docker,var.lib.docker} && \
        echo "Copied /var/lib/docker to ${DATA_DIR}"
    fi

    cat <<EOF >/etc/docker/daemon. json
    {
        "data-root": "${ALTERNATIVE_DOCKER_ROOT_DIR}"
    }
EOF
    systemctl restart docker containerd && \
    echo "It seems everything was OK, DUBLE CHECK and delete /var/lib/docker manually..."

else
    echo "ERROR - /etc/docker/daemon.json exists and cannot be overwriten!"
fi

# Setup NFS on the third master server manually************************
## 1. Install nfs-kernel-server packages
## 2. add master nodes IPs to to exports file
cat <<EOF >> /etc/exports && systemctl restart nfs-server
# Elastic snapshot
/app/elasticsearch/snapshot ${KIBANA_NODE_IP}/30(rw,sync,no_subtree_check,no_root_squash)
EOF

# Load docker images
for IMAGE in "${ELK_DIR}"/*.tar; do sudo docker image load -i "${IMAGE};"; done

# Create mountpoints
mkdir -p "${DATA_DIR}"/logs/{elasticsearch,logstash,kibana} "${DATA_DIR}"/{elasticsearch/{data,snapshot},kibana/data,logstash/data,filebeat/data,metricbeat/data} ${ELK_DIR} && \
chown -R 1000:docker "${ELK_DIR}" "${DATA_DIR}"/{elasticsearch,logstash,logs,kibana,filebeat} && \
chmod 775 "${DATA_DIR}" && \
chmod 777 "${DATA_DIR}"/{elasticsearch,kibana}/data/; \
chmod 666 "${ELK_DIR}"/logstash/logstash.yml; \
chmod 744 "${ELK_DIR}"/elasticsearch/elastic_initial_setup_script.sh; \
find "${DATA_DIR}"/elasticsearch/data/ -type d | xargs chmod 775; \
find "${DATA_DIR}"/elasticsearch/data/ -type f | xargs chmod 664; \
find "${ELK_DIR}" -type d | xargs chmod 775; \
find "${ELK_DIR}" -type f | xargs chmod 664;

# Tune kernel
grep -q 'vm.max_map_count=262144' /etc/sysctl.conf || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf && sysctl --load /etc/sysctl.conf;

# filebeat auto-discovery ACL (to be able to run filebeat as non-root user)
apt-get install acl && \
    setfacl -m group:root:rw /var/run/docker.sock && \
    chmod 750 ${ALTERNATIVE_DOCKER_ROOT_DIR}/containers ${ALTERNATIVE_DOCKER_ROOT_DIR}/containers/* && \
    setfacl -d -m group:root:rx ${ALTERNATIVE_DOCKER_ROOT_DIR}/containers

# Initialize swarm cluster
docker swarm init --advertise-addr 10.0.0.1
docker swarm init --advertise-addr 10.0.0.1 --listen-addr 10.0.0.1 --data-path-port 1666 #--default-addr-pool 10.0.0.0/10

# Optionally create a custom ingress network (in case of conflict with current network)
docker network create --driver overlay --ingress --subnet=10.33.0.0/16 --gateway=10.33.0.1 --opt com.docker.network.driver.mtu=1450 ingress

# wrong checksum issue preventing overlay network to work properly
ethtool -K <interface> tx off

# Use join token to add other nodes (both manager and worker)
docker swarm join-token manager
docker swarm join-token worker

# add label to nodes
docker node update --label-add name=node1 HOSTNAME1
docker node update --label-add name=node2 HOSTNAME2
docker node update --label-add name=node3 HOSTNAME3

## substituting logstash pipelines variables 
#for FILE in $(1s -1 logstash/conf.d.tmpl); do echo "Substituting $FILE variables."; envsubst < logstash/conf.d.tmpl/$FILE > /tmp/envsubst; mv -f /tmp/envsubst logstash/conf.d/$FILE; done

# generate certificates
docker compose --env-file .env -f generate-certs-compose.yml up

# deploy stack
docker stack deploy --resolve-image never -c compose.yml elk