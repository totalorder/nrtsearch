#!/usr/bin/env bash
./build/install/nrtsearch/bin/lucene-client settings -f <(cat <<EOF
{
  "indexName": "test_idx",
  "directory": "MMapDirectory",
  "nrtCachingDirectoryMaxSizeMB": 0.0,
  "indexMergeSchedulerAutoThrottle": false,
  "concurrentMergeSchedulerMaxMergeCount": 16,
  "concurrentMergeSchedulerMaxThreadCount": 8
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

./build/install/nrtsearch/bin/lucene-client registerFields -f <(cat <<EOF
{             "indexName": "testIdx",
              "field":
              [
                      { "name": "doc_id", "type": "ATOM", "storeDocValues": true},
                      { "name": "vendor_name", "type": "TEXT" , "search": true, "store": true, "tokenize": true},
                      { "name": "license_no",  "type": "INT", "multiValued": true, "storeDocValues": true}
              ]
}
EOF
)

./build/install/nrtsearch/bin/lucene-client addDocuments -i testIdx -t csv -f <(cat <<EOF
doc_id,vendor_name,license_no
0,first vendor,100;200
1,second vendor,111;222
EOF
)

