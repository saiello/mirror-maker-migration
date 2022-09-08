


kafka-console-consumer.sh --bootstrap-server localhost:9095 --topic test-topic-a --from-beginning --max-messages 18000 > /tmp/target-a-last.txt
wc -l /tmp/target-a-last.txt
sort -n /tmp/target-a-last.txt | awk 'BEGIN{expected=0}{if(expected!=$1){print "MissingRecords["expected"-"$1"]"}; expected=$1+1}'


kafka-console-consumer.sh --bootstrap-server localhost:9095 --topic test-topic-b --from-beginning --max-messages 10000 > /tmp/target-b-last.txt
wc -l /tmp/target-b-last.txt
sort -n /tmp/target-b-last.txt | awk 'BEGIN{expected=0}{if(expected!=$1){print "MissingRecords["expected"-"$1"]"}; expected=$1+1}'


