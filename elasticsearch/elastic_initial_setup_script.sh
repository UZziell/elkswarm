#!/usr/bin/env bash
#set -x
# This script initialized elasticsearch

f() {
    echo -e "\n---------------------------------------------------------------------------------------"
    echo -n "${0}:${BASH_LINENO} -- ";
    sed -n "${BASH_LINENO}p" < $0;
}

##########
# COMMON #
##########
function create_common() {
    if [ x{{ env "ELASTIC_PASSWORD" }} == x ]; then
        echo "Set the ELASTIC_PASSWORD environment variable in the .env file";
        exit 1;
    elif [ x{{ env "LOGSTASH_WRITER_PASSWORD" }} == x ] || [ x{{ env "APM_SYSTEM_PASSWORD" }} == x ] || [ x{{ env "BEATS_SYSTEM_PASSWORD" }} == x ] || [ x{{ env "KIBANA_SYSTEM_PASSWORD" }} == x ] || [ x{{ env "LOGSTASH_SYSTEM_PASSWORD" }} == x ] || [ x{{ env "REMOTE_MONITORING_USER PASSWORD" }} == x ]; then
        echo "One of the LOGSTASH_WRITER_PASSWORD, APM_SYSTEM_PASSWORD, LOGSTASH_SYSTEM_PASSWORD, REMOTE_MONITORING_USER_PASSWORD environment variables is not set in the .env file"
        exit 1;
    fi;
    echo "Waiting for Elasticsearch availability";
    until curl -s --cacert config/certs/ca/ca.crt https://es01:9200 | grep -q "missing authentication credentials"; do
        echo "sleeping more...";
        sleep 30;
    done;

    echo "Setting kibana_system password";
    curl -s -X POST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC_PASSWORD" }}" -H "Content-Type: application/json" https://es01:9200/_security/user/kibana_system/_password -d '{"password":"{{ env "KIBANA_SYSTEM_PASSWORD" }}"}'
    curl -s -X POST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC_PASSWORD" }}" -H "Content-Type: application/json" https://es01:9200/_security/user/logstash_system/_password -d '{"password":"{{ env "LOGSTASH_SYSTEM_PASSWORD" }}"}'
    curl -s -X POST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC PASSWORD" }}" -H "Content-Type: application/json" https://es01:9200/_security/user/apm_system/_password -d '{"password":"{{ env "APM_SYSTEM_PASSWORD" }}"}'
    curl -s -X POST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC PASSWORD" }}" -H "Content-Type: application/json" https://es01:9200/_security/user/beats_system/_password -d '{"password":"{{ env "BEATS_SYSTEM_PASSWORD" }}"}'
    curl -s -X POST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC PASSWORD" }}" -H "Content-Type: application/json" https://es01:9200/_security/user/remote_monitoringuser/_password -d '{"password":"{{ env "REMOTE_MONITORING_USER_PASSWORD" }}"}'
}

# Create logstash_writer role and user
f; curl -s -XPUT --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC_PASSWORD" }}" "https://es01:9200/_security/role/{{ env "LOGSTASH_WRITER_USER" }}" -H 'Content-Type: application/json' -d'
{ 
    "cluster" : [
        "monitor",
        "read_ilm",
        "manage",
        "manage_pipeline",
        "manage_ingest_pipelines",
        "manage_index_templates",
        "manage_ilm"
    ],
    "indices" : [
        {
            "names": [ "*" ],
            "privileges" : [
                "create",
                "create_doc",
                "create_index",
                "write",
                "index",
                "view_index_metadata",
                "auto_configure",
                "manage",
                "read",
                "manage_ilm"
            ],
            "allow_restricted_indices": false
        }
    ]
}'

f; curl -s -XPOST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC_PASSWORD" }}" "https://es01:9200/_security/user/{{ env "LOGSTASH_WRITER_USER" }}" -H 'Content-Type: application/json' -d'
{ 
    "roles" : [
        "{{ env "LOGSTASH_WRITER_USER" }}"
    ],
    "password" : "{{ env "LOGSTASH_WRITER_PASSWORD" }}"
}'

f; curl -s -XPOST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC_PASSWORD" }}" "https://es01:9200/_snapshot/snapshot-1" -H 'Content-Type: application/json' -d'
{
    "type" : "fs",
    "settings" : {
        "compress" : "true",
        "location" : "/app/elasticsearch/snapshot"
    }
}'


##########
# spaces #
##########
f; curl -s -XPOST --cacert config/certs/ca/ca.crt -u "elastic:{{ env "ELASTIC_PASSWORD" }}" "https://kibana:5601/api/spaces/space' -H 'Content-Type: application/json' -H 'kbn-xsrf: reporting' -d'
{
    "color": "#860000",
    "description": "CustomSpace",
    "disabledFeatures": [
        "graph",
        "monitoring",
        "m1",
        "maps",
        "canvas",
        "siem"
    ],
    "id": "customspace",
    "imageUrl": "",
    "initials": "c",
    "name": "CustomSpace"
}'
