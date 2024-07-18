# Elastic Stack Deployment on Docker Swarm

This repository provides a deployment of the Elastic Stack (Elasticsearch, Kibana, Logstash, Beats [Filebeat, Metricbeat], and APM Server) on a Docker Swarm cluster.

## Architecture

The architecture of the deployment is illustrated in the provided diagram. <br>
![ELK.Swarm](.ELK-Swarm.drawio.svg)
- **Elasticsearch Containers**: Each Elasticsearch container is bound to a specific swarm node using deployment constraints and labels.
- **Logstash and Kibana Containers**: These containers can be scheduled on any node, as decided by the swarm managers. You can set the number of replicas for these services using the `KIBANA_REPLICAS` and `LOGSTASH_REPLICAS` environment variables in the `.env` file.
- **Metricbeat**: Deployed in global mode, ensuring one replica is running on every swarm node.
- **Filebeat**: (To be done) Planned to be deployed in global mode.

## Additional Notes

- You can scale the swarm cluster beyond the default three nodes. In such cases, you can assign different roles (hot, warm, cold) to Elasticsearch containers running on different swarm nodes. To achieve this, use the `compose.extend.yml` file to define additional Elasticsearch services such as `es04`, `es05`, etc.

## Prerequisites

1. **Docker Engine** (Tested with version 24.09.01)
2. **Docker Compose Plugin**: (Tested with version 2.27.0)
3. **Docker Swarm Cluster**: A working cluster with at least three nodes, each properly labeled (Covered in the Deployment section).
    - **Setting up Swarm** (Follow the official documentation for more info. [Getting started with Swarm mode](https://docs.docker.com/engine/swarm/swarm-tutorial/)):
        ```sh
        docker swarm init --advertise-addr 10.0.0.1
        ```


## Environment Variables
To run this project, you will need to add the following environment variables to your `.env` file. These variables are used in two ways:
1. Variables used only in compose file itself like `STACK_VERSION`
2. Variables that are also passed to containers like `LOGSTASH_WRITER_USER`

|                   Variable                   |                                                                                                        Description                                                                                                       |                                                 Default                                                | Required |
|:--------------------------------------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:------------------------------------------------------------------------------------------------------:|:--------:|
| `IMAGE_REGISTRY_PREFIX`                      | Optinal Image registry prefix (Should end with /) . For example `registry.mycompany.com/'                                                                                                                                | <none>                                                                                                 | No       |
| `DATA_DIR`                                   | This  is the directory where all container data is stored. <br> Sub-directories created during setting up the cluster will be bind mounted to containers                                                                 |                                                                                                        | Yes      |
| `ELK_DIR`                                    | This is the full path of this project clone.                                                                                                                                                                             | /opt/elkswarm                                                                                          | Yes      |
| `APM_SERVER_REPLICAS`                        | APM Server service replica count                                                                                                                                                                                         | 1                                                                                                      | Yes      |
| `FILEBEAT_REPLICAS`                          | Filebeat service replica count                                                                                                                                                                                           | 3                                                                                                      | Yes      |
| `KIBANA_REPLICAS`                            | Kibana service replica count                                                                                                                                                                                             | 2                                                                                                      | Yes      |
| `LOGSTASH_REPLICAS`                          | Logstash service replica count                                                                                                                                                                                           | 2                                                                                                      | Yes      |
| `STACK_VERSION`                              | Version of Elastic product. Used in compose.yml image tags                                                                                                                                                               | 8.13.2                                                                                                 | Yes      |
| `RUN_AS_USER`                                | The user id used to run the containers                                                                                                                                                                                   | 1000                                                                                                   | Yes      |
| `CLUSTER_NAME`                               | The Elasticsearch cluster name                                                                                                                                                                                           | <none>                                                                                                 | Yes      |
| `ES_PORT`                                    | Port to expose Elasticsearch HTTP API on swarm nodes                                                                                                                                                                     | 9200                                                                                                   | Yes      |
| `KIBANA_PORT`                                | Port to expose Kibana service on swarm nodes                                                                                                                                                                             | 5601                                                                                                   | Yes      |
| `NFS_SERVER_IP`                              | In case of using [shared file system repository](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshots-filesystem-repository.html) for snapshots, this variable is the IP of the NFS server          | <none>                                                                                                 | No       |
| `NFS_SERVER_DEVICE_PATH`                     | In case of using [shared file system repository](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshots-filesystem-repository.html) for snapshots, this variable is the device path of the NFS server | <none>                                                                                                 | No       |
| `KIBANA_SERVER_PUBLICBASEURL`                | Public URL of kibana server including port, used as kibana's server.publicBaseURL                                                                                                                                        | <none>                                                                                                 | Yes      |
| `KIBANA_HOSTNAMES`                           | Comma-separated list of Kibana hostnames. Used for generating certificates                                                                                                                                               | <none>                                                                                                 | Yes      |
| `KIBANA_HOSTS_IP`                            | Comma-separated list of Kibana IPs. Used for generating certificates                                                                                                                                                     | <none>                                                                                                 | Yes      |
| `ELASTIC_JVM_HEAP_SIZE`                      | Sets Elasticsearch JVM heap size. This value is used as both -Xms and -Xmx to prevent resizing heap at runtime. <br> DO NOT set this value more than half of the available physical memory of the host                   | 2g (GB)                                                                                                | Yes      |
| `LOGSTASH_JVM_HEAP_SIZE`                     | Sets Logstash JVM heap size. This value is used as both -Xms and -Xmx to prevent resizing heap at runtime                                                                                                                | 2g (GB)                                                                                                | Yes      |
| `ELASTIC_HOSTS`                              | Space-separated list of Elasticsearch data nodes. Used in Logstash pipelines output <br> **In case of the default three node cluster, every node has all the roles**                                                     | 'https://es01:9200 https://es02:9200 https://es03:9200'                                                | Yes      |
| `ELASTIC_HOSTS_LIST`                         | List of Elasticsearch nodes                                                                                                                                                                                              | ["https://es01:9200","https://es02:9200","https://es03:9200"]                                          | Yes      |
| `ELASTIC_MASTER_ROLES`                       | Comma-separated list of elasticsearch **master** node roles. <br> In case of the default three node cluster, all of the 3 nodes should have all the roles.                                                               | master,ingest,ml,remote_cluster_client,data_warm, <br>  data_cold,transform,data,data_hot,data_content | Yes      |
| `ELASTIC_HOT_ROLES`                          | Comma-separated list of elasticsearch **hot** node roles. <br> Only used when scaling the cluster to more than 3 nodes in `compose.extend.yml`                                                                           | data_hot,data_content,ingest                                                                           | Yes*     |
| `ELASTIC_WARM_ROLES`                         | Comma-separated list of elasticsearch **warm** node roles. <br> Only used when scaling the cluster to more than 3 nodes in `compose.extend.yml`                                                                          | data_warm,ingest                                                                                       | Yes*     |
| `LOGSTASH_HOSTS_LIST`                        | List of Logstash nodes                                                                                                                                                                                                   |                                                                                                        | Yes      |
| `ELASTIC_PASSWORD`                           | Password for the 'elastic' user (at least 6 characters)                                                                                                                                                                  | <none>                                                                                                 | Yes      |
| `KIBANA_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY` | Kibana encryption key (must be 32 characters)                                                                                                                                                                            | <none>                                                                                                 | Yes      |
| `KIBANA_SECURITY_ENCRYPTIONKEY`              | Kibana encryption key (must be 32 characters)                                                                                                                                                                            | <none>                                                                                                 | Yes      |
| `APM_SYSTEM_PASSWORD`                        | Password of `apm_system` user                                                                                                                                                                                            | <none>                                                                                                 | Yes      |
| `BEATS_SYSTEM_PASSWORD`                      | Password of `beats_system` user                                                                                                                                                                                          | <none>                                                                                                 | Yes      |
| `KIBANA_SYSTEM_PASSWORD`                     | Password of `kibana_system` user                                                                                                                                                                                         | <none>                                                                                                 | Yes      |
| `LOGSTASH_SYSTEM_PASSWORD`                   | Password of `logstash_system` user                                                                                                                                                                                       | <none>                                                                                                 | Yes      |
| `REMOTE_MONITORING_USER_PASSWORD`            | Password of `remote_monitoring_user` user                                                                                                                                                                                | <none>                                                                                                 | Yes      |
| `LOGSTASH_WRITER_USER`                       | A user created automatically during initialization. <br> Used by beats, logstash, and apm-server to connect to authenticate with elasticsearch cluster                                                                   | logstash_writer                                                                                        | Yes      |
| `LOGSTASH_WRITER_PASSWORD`                   | Password for the custom 'logstash_writer' user (created automatically during initialization)                                                                                                                             | <none>                                                                                                 | Yes      |
| `USERS_DEFAULT_PASSWORD`                     | Password for non-system users created automatically during initialization by script `elasticsearch/elastic_initial_setup_script.sh`                                                                                      | <none>                                                                                                 | Yes      |

# Deployment

1. Clone this repository

2. Fill the `.env` file. Then export .env variables in the current shell by using the below command
    ```sh
    while IFS= read -r variable; do export "${variable?}"; done < <(grep -vE '^#|^$' .env)
    ```

3. Create mountpoints with the right permission on all of the nodes
    ```sh
    mkdir -p "${DATA_DIR}"/{elasticsearch/{data,snapshot},fleet-server/data,elastic-agent/data,kibana/data,logstash/data,filebeat/data,metricbeat/data} ${ELK_DIR} && \
    chown -R "${RUN_AS_USER}:docker" "${ELK_DIR}" "${DATA_DIR}"/{elasticsearch,logstash,kibana,filebeat} && \
    chmod 775 "${DATA_DIR}" && \
    chmod 777 "${DATA_DIR}"/{elasticsearch,kibana,metricbeat,logstash}/data/;
    ```
4. **(Optinal)** In case of using [shared file system repository](https://www.elastic.co/guide/en/elasticsearch/reference/current/snapshots-filesystem-repository.html) for snapshots, setup the NFS server and ensure all client nodes can successfully connect and mount the share filesystem. Then uncomment the `snapshot-nfs` from both `volumes` and `es01` section of the `compose.yml` file. **Ensure to set this options for the nfs to work with docker volumes correctly: `(rw,sync,no_subtree_check,no_root_squash)`**

5. Update kernel parameters on nodes running Elasticsearch container:
    ```sh
    grep -q 'vm.max_map_count=262144' /etc/sysctl.conf || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf && sysctl --load /etc/sysctl.conf;
    ```
6. Properly label each node of the swarm:
    ```sh
    docker node update --label-add name=node1 HOSTNAME1
    docker node update --label-add name=node2 HOSTNAME2
    docker node update --label-add name=node3 HOSTNAME3
    ```
7. Generate elasticsearch certificates
    ```sh
    docker compose --env-file .env -f generate-certs-compose.yml up --force-recreate
    ```

7. Deploy ELK to swarm as a stack named **elk**:
    ```sh
    docker stack deploy --resolve-image never -c compose.yml elk
    ```

8. See the status of the deployment
    ```sh
    docker stack ps --no-trunc elk
    ```
