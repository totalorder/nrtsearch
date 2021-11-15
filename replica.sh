#!/usr/bin/env bash
set -e
set -o pipefail

function __exit () {
  EXIT_CODE=$?
  if [[ -n "${SERVER_PID}" && $(ps -p "${SERVER_PID}") ]]; then
    echo "Killing $SERVER_PID"
    kill "${SERVER_PID}"
    echo "Killed $SERVER_PID"
  else
    echo "Pid $SERVER_PID doesn't exist"
  fi
  echo "Exiting..."
  trap '' INT EXIT
  exit ${EXIT_CODE}
}

trap '__exit; exit' INT EXIT

rm -rf replica_data/

LUCENE_SERVER_OPTS="-Duser.home=replica_data" ./build/install/nrtsearch/bin/lucene-server <(cat <<EOF
nodeName: "replica1"
hostName: "localhost"
port: "7000"
replicationPort: "7001"
syncInitialNrtPoint: true
EOF
) &

SERVER_PID=$!

sleep 2

./build/install/nrtsearch/bin/lucene-client -p 7000 createIndex -i test_idx

./build/install/nrtsearch/bin/lucene-client -p 7000 settings -f <(cat <<EOF
{
  "indexName": "test_idx",
  "directory": "MMapDirectory",
  "nrtCachingDirectoryMaxSizeMB": -1.0
}
EOF
)

./build/install/nrtsearch/bin/lucene-client -p 7000 registerFields -f <(cat <<EOF
{             "indexName": "test_idx",
              "field":
              [
                      { "name": "doc_id", "type": "ATOM", "storeDocValues": true},
                      { "name": "vendor_name", "type": "TEXT" , "search": true, "store": true, "tokenize": true},
                      { "name": "license_no",  "type": "INT", "multiValued": true, "storeDocValues": true}
              ]
}
EOF
)

./build/install/nrtsearch/bin/lucene-client -p 7000 startIndex -f <(cat <<EOF
{
  "indexName" : "test_idx",
  "mode": "REPLICA",
  "primaryAddress": "localhost",
  "port": 6001
}
EOF
)


#sleep 1

#./build/install/nrtsearch/bin/lucene-client writeNRT -i test_idx -p 6001
#sleep 1

./build/install/nrtsearch/bin/lucene-client -p 7000 search -f <(cat <<EOF
{
  "indexName": "test_idx",
  "startHit": 0,
  "topHits": 100,
  "retrieveFields": ["doc_id", "license_no", "vendor_name"],
  "queryText": "vendor_name:first vendor"
}
EOF
)

echo "Server running..."
wait ${SERVER_PID}
