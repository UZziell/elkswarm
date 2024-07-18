# Elastic Stack Deployment on Docker Swarm

This repository provides a deployment of the Elastic Stack (Elasticsearch, Kibana, Logstash, Beats [Filebeat, Metricbeat], and APM Server) on a Docker Swarm cluster.

## Architecture

The architecture of the deployment is illustrated in the provided diagram.
![ELK.Swarm](.ELK-Swarm.drawio.svg)
- **Elasticsearch Containers**: Each Elasticsearch container is bound to a specific swarm node using deployment constraints and labels.
- **Logstash and Kibana Containers**: These containers can be scheduled on any node, as decided by the swarm managers. You can set the number of replicas for these services using the `KIBANA_REPLICAS` and `LOGSTASH_REPLICAS` environment variables in the `.env` file.
- **Metricbeat**: Deployed in global mode, ensuring one replica is running on every swarm node.
- **Filebeat**: (To be done) Planned to be deployed in global mode.

## Additional Notes

- You can scale the swarm cluster beyond three nodes. In such cases, you can assign different roles (hot, warm, cold) to Elasticsearch nodes on different swarm nodes. To achieve this, use the `compose.extend.yml` file to define additional Elasticsearch services such as `es04`, `es05`, etc.

## Prerequisites

1. **Docker Engine** (Tested with version 24.09.01)
2. **Docker Compose Plugin**: (Tested with version 2.27.0)
3. **Docker Swarm Cluster**: A working cluster with at least three nodes, each properly labeled.
    - **Setting up Swarm** (This is super simplified. Follow the official documentation for more info. [Getting started with Swarm mode](https://docs.docker.com/engine/swarm/swarm-tutorial/)):
        ```sh
        docker swarm init --advertise-addr 10.0.0.1
        ```
    - **Labeling Nodes**:
        ```sh
        docker node update --label-add name=node1 HOSTNAME1
        docker node update --label-add name=node2 HOSTNAME2
        docker node update --label-add name=node3 HOSTNAME3
        ```

4. **Nodes Configuration**: Set the following on nodes running Elasticsearch container:
    ```sh
    grep -q 'vm.max_map_count=262144' /etc/sysctl.conf || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf && sysctl --load /etc/sysctl.conf;
    ```

## Environment Variables
To run this project, you will need to add the following environment variables to your .env file. These variables are used in two ways:
1. Variables used only in compose file like `STACK_VERSION`
2. Variables that are also passed to containers like `LOGSTASH_WRITER_USER`

|                   Variable                   |                                                                                                        Description                                                                                                       |                                                 Default                                                | Required |
|:--------------------------------------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:------------------------------------------------------------------------------------------------------:|:--------:|
| `IMAGE_REGISTRY_PREFIX`                      | Optinal Image registry prefix (Should end with /) . For example `registry.mycompany.com/'                                                                                                                                | <none>                                                                                                 | No       |
| `DATA_DIR`                                   | This  is the directory where all container data is stored. <br> Sub-directories created during setting up the cluster will be bind mounted to containers                                                                 |                                                                                                        | Yes      |
| `ELK_DIR`                                    | This is the full path of this project clone. For example /opt/elkswarm                                                                                                                                                   | <none>                                                                                                 | Yes      |
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

2. On a machine that is communicating with the swarm cluster:
    1. `docker stack deploy -c $(pwd)/docker-compose.yml elk`

That will bring up the ELK stack.

> **Note:** You may want to remove the stdout output using the `rubydebug` codec after confirming everything works as you expect. By leaving the stdout output enabled it would be too much output for most environments. Also you would want to increase the Elasticsearch heap size and memory/limits reservations for most deployments.

Access kibana at `http://<worker-node-ip>:5601`

