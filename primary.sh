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

rm -rf primary_data/

LUCENE_SERVER_OPTS="-Duser.home=primary_data" ./build/install/nrtsearch/bin/lucene-server <(cat <<EOF
nodeName: "primary1"
hostName: "localhost"
port: "6000"
replicationPort: "6001"
EOF
) &


SERVER_PID=$!

sleep 2

./build/install/nrtsearch/bin/lucene-client createIndex --indexName test_idx

./build/install/nrtsearch/bin/lucene-client settings -f <(cat <<EOF
{
  "indexName": "test_idx",
  "directory": "MMapDirectory",
  "nrtCachingDirectoryMaxSizeMB": -1.0,
  "indexMergeSchedulerAutoThrottle": false,
  "concurrentMergeSchedulerMaxMergeCount": 16,
  "concurrentMergeSchedulerMaxThreadCount": 8
}
EOF
)

./build/install/nrtsearch/bin/lucene-client registerFields -f <(cat <<EOF
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

./build/install/nrtsearch/bin/lucene-client startIndex -f <(cat <<EOF
{
  "indexName" : "test_idx",
  "mode": "PRIMARY"
}
EOF
)

#echo "Waiting before adding documents"
#sleep 15
./build/install/nrtsearch/bin/lucene-client addDocuments -i test_idx -t csv -f <(cat <<EOF
doc_id,vendor_name,license_no
0,first vendor,100;200
1,second vendor,111;222
EOF
)

#./build/install/nrtsearch/bin/lucene-client refresh -i test_idx

#./build/install/nrtsearch/bin/lucene-client commit -i test_idx

#./build/install/nrtsearch/bin/lucene-client writeNRT -i test_idx -p 6001

#./build/install/nrtsearch/bin/lucene-client search -f <(cat <<EOF
#{
#  "indexName": "test_idx",
#  "startHit": 0,
#  "topHits": 100,
#  "retrieveFields": ["doc_id", "license_no", "vendor_name"],
#  "queryText": "vendor_name:first vendor"
#}
#EOF
#)

echo "Server running..."

wait ${SERVER_PID}