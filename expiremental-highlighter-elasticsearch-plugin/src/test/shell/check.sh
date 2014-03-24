#!/bin/bash

curl -XDELETE "http://localhost:9200/test?pretty"
curl -XPOST "http://localhost:9200/test?pretty"
curl -XPUT http://localhost:9200/test/test/_mapping?pretty -d'{
    "properties": {
      "title" : {
        "type": "string",
        "index_options": "offsets",
        "term_vector": "with_positions_offsets"
      }
    }
}'

curl -XPOST "http://localhost:9200/test/test?pretty" -d '{"title": "a pretty tiny string to test with "}'
echo '{"title": "a much larger string to test with ' > /tmp/largerString
echo '{"title": "huge string with ' > /tmp/hugeString
echo '{"title": "many string with ' > /tmp/manyString
rm -f /tmp/hugePart
for i in {1..100}; do
  echo "very very very " >> /tmp/hugePart
done
rm -f /tmp/manyPart
for i in {1..100}; do
  echo "very very many " >> /tmp/manyPart
done
for i in {1..1000}; do
  echo 'much much more text.  ' >> /tmp/largerString
  cat /tmp/hugePart >> /tmp/hugeString
  echo 'much much more text.  ' >> /tmp/hugeString
done
for i in {1..100}; do
  cat /tmp/hugePart >> /tmp/manyString
  echo 'much much more text.  ' >> /tmp/manyString
done
echo 'and larger at the end"}' >> /tmp/largerString
echo 'and huge at the end"}' >> /tmp/hugeString
echo '"}' >> /tmp/manyString
curl -XPOST "http://localhost:9200/test/test?pretty" -d @/tmp/largerString
curl -XPOST "http://localhost:9200/test/test?pretty" -d @/tmp/hugeString
curl -XPOST "http://localhost:9200/test/test?pretty" -d @/tmp/manyString
curl -XPOST http://localhost:9200/test/_refresh?pretty

function go() {
  highlighter="$1"
  if [ "$highlighter" != "expiremental" ]; then
    hit_source="$2"
  fi
  echo '{
  "_source": false,
  "query": {
    "query_string": {
      "query": "'$search'"
    }
  },
  "highlight": {
    "order": "'$order'",
    "options": {
      "hit_source": "'$hit_source'"
    },
    "fields": {
      "title": {
        "number_of_fragments": '$number_of_fragments',
        "type": "'$highlighter'"
      }
    }
  }
}' > /tmp/post
  printf "%15s %10s %7s %10s %1s " $highlighter $search $order "$hit_source" $number_of_fragments
  if [ "$mode" = "check" ]; then
    curl -s -XPOST "http://localhost:9200/test/test/_search?pretty" -d @/tmp/post > /tmp/result
    grep "<em>" /tmp/result || cat /tmp/result
  elif [ "$mode" = "bench" ]; then
    count=200
    if [ "$highlighter" = "plain" ] && [ "$search" = "huge" ]; then
      count=50
    fi
    ab -c 3 -n $count -p /tmp/post http://localhost:9200/test/_search 2>&1 | grep Total:
  fi
}

function each() {
  for highlighter in plain fvh postings; do
    go $highlighter
  done
  for hit_source in postings vectors analyze; do
    go expiremental $hit_source
  done
}

function suite() {
  for order in score source; do
    export order=$order

    export search=tiny
    export number_of_fragments=1
    each
    export search=larger
    each
    export number_of_fragments=2
    each
    export search=huge
    each
    export search=many
    each
  done
}

export mode=check
suite

export mode=bench
suite
