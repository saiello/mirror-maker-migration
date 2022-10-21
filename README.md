
Seamless migration from mirror-maker to mirror-maker-2.


## Migration Procedure

0. Set some vars

```
export mm_cg_name=mirror-maker
export source_alias=primary
export source_bootstrap=localhost:9094
export target_bootstrap=localhost:9095
export working_dir=/tmp
```

1. Stop MirrorMaker 1

Before any activity stop mirror-maker instance


2. Extract Offsets

```
kafka-consumer-groups.sh --bootstrap-server ${source_bootstrap} --describe --group ${mm_cg_name} | awk -v group=$mm_cg_name '$1 == group { print $2,$3,$4-1 }' | tee ${working_dir}/mm-migration-offset.csv
```

3. Convert 

for zsh only:
```
for topic partition offset in $(cat ${working_dir}/mm-migration-offset.csv); do
  printf '["MirrorSourceConnector",{"cluster":"%s","partition":%s,"topic":"%s"}]|{"offset":%s}\n' $source_alias $partition $topic $offset 
done | tee ${working_dir}/mm-migration-offset.jsons
```

alternatively:

```
awk -v cluster=$source_alias '{ print "[\"MirrorSourceConnector\",{\"cluster\":\""cluster"\",\"partition\":"$2",\"topic\":\""$1"\"}]|{\"offset\":"$3"}" }' ${working_dir}/mm-migration-offset.csv | tee ${working_dir}/mm-migration-offset.jsons
```


4. Create internal topic

```
kafka-topics.sh --bootstrap-server ${target_bootstrap} --create --topic mm2-offsets.$source_alias.internal --partitions 25 --config cleanup.policy=compact
```

5. Produce offsets

```
cat ${working_dir}/mm-migration-offset.jsons | kafka-console-producer.sh --bootstrap-server ${target_bootstrap} --topic mm2-offsets.$source_alias.internal --property key.separator=\| --property parse.key=true
```

6. Start MirrorMaker2 instance

Start mirror-maker-2 consuming from the offsets where mirror-maker-1 ends to.


## How to verify 

Shorter/scripted way

1. docker-compose up
2. ./create-topics.sh
3. ./mirror-maker-1.sh
4. ./start-prod-1.sh
5. ./start-prod-2.sh
6. after a while stop mirror maker (3) 
7. ./migrate.sh
8. ./mirror-maker-2.sh
9. ./verify.sh


Long version

1. Start two kafka clusters

```
docker-compose up
```

2. Create some topics 

```
kafka-topics.sh --bootstrap-server localhost:9094 --topic test-topic-a --create
kafka-topics.sh --bootstrap-server localhost:9094 --topic test-topic-b --create
```

3. Produce on topic-a

```
kafka-verifiable-producer.sh --bootstrap-server localhost:9094 --value-prefix 1 --topic test-topic-a --max-messages 10
```

4. Start mirror maker

```
kafka-mirror-maker.sh --consumer.config config/source-mirror.config --num.streams 1 --producer.config config/target-mirror.config --whitelist='test-topic-.*'
```

5. Produce some messages on both topics 

```
kafka-verifiable-producer.sh --bootstrap-server localhost:9094 --value-prefix 2 --topic test-topic-a --max-messages 7
kafka-verifiable-producer.sh --bootstrap-server localhost:9094 --value-prefix 2 --topic test-topic-b --max-messages 7
```


6. Stop mirror maker


7. Produce some further messages on both topics

```
kafka-verifiable-producer.sh --bootstrap-server localhost:9094 --value-prefix 3 --topic test-topic-a --max-messages 8
kafka-verifiable-producer.sh --bootstrap-server localhost:9094 --value-prefix 3 --topic test-topic-b --max-messages 8
```

8. Execute the migration procedure

```
./migrate.sh
```

9. Start Mirror Maker 2

```
connect-mirror-maker.sh config/connect-mirror-maker.properties
```

10. verify

Content of test-topic-a on cluster primary should have messaged with prefix 1, while same topic on cluster secondary should not.

.Cluster primary
```
kafka-console-consumer.sh --bootstrap-server localhost:9094 --topic test-topic-a --from-beginning --property print.offset=true --property=print.partition=true

Partition:0	Offset:0	1.0
Partition:0	Offset:1	1.1
Partition:0	Offset:2	1.2
Partition:0	Offset:3	1.3
Partition:0	Offset:4	1.4
Partition:0	Offset:5	1.5
Partition:0	Offset:6	1.6
Partition:0	Offset:7	1.7
Partition:0	Offset:8	1.8
Partition:0	Offset:9	1.9  // when we start mirroring with mirror-maker
Partition:0	Offset:10	2.0  
Partition:0	Offset:11	2.1
Partition:0	Offset:12	2.2
Partition:0	Offset:13	2.3
Partition:0	Offset:14	2.4
Partition:0	Offset:15	2.5
Partition:0	Offset:16	2.6
Partition:0	Offset:17	3.0 // when we start mirroring with mirror-maker2
Partition:0	Offset:18	3.1
Partition:0	Offset:19	3.2
Partition:0	Offset:20	3.3
Partition:0	Offset:21	3.4
Partition:0	Offset:22	3.5
Partition:0	Offset:23	3.6
Partition:0	Offset:24	3.7
```


.Cluster secondary
```
kafka-console-consumer.sh --bootstrap-server localhost:9095 --topic test-topic-a --from-beginning --property print.offset=true --property=print.partition=true


Partition:0	Offset:0	2.0
Partition:0	Offset:1	2.1
Partition:0	Offset:2	2.2
Partition:0	Offset:3	2.3
Partition:0	Offset:4	2.4
Partition:0	Offset:5	2.5
Partition:0     Offset:17       3.0
Partition:0     Offset:18       3.1
Partition:0     Offset:19       3.2
Partition:0     Offset:20       3.3
Partition:0     Offset:21       3.4
Partition:0     Offset:22       3.5
Partition:0	Offset:13	3.6
Partition:0	Offset:14	3.7
```


Content of test-topic-b should be identical

```
kafka-console-consumer.sh --bootstrap-server localhost:9094 --topic test-topic-b --from-beginning --property print.offset=true --property=print.partition=true 

kafka-console-consumer.sh --bootstrap-server localhost:9095 --topic test-topic-b --from-beginning --property print.offset=true --property=print.partition=true 
```

on both clusters you should obtain something like 

```
Partition:0	Offset:0	2.0  // when we start mirroring with mirror-maker
Partition:0	Offset:1	2.1
Partition:0	Offset:2	2.2
Partition:0	Offset:3	2.3
Partition:0	Offset:4	2.4
Partition:0	Offset:5	2.5
Partition:0	Offset:6	2.6
Partition:0	Offset:7	3.0 // when we start mirroring with mirror-maker-2
Partition:0	Offset:8	3.1
Partition:0	Offset:9	3.2
Partition:0	Offset:10	3.3
Partition:0	Offset:11	3.4
Partition:0	Offset:12	3.5
Partition:0	Offset:13	3.6
Partition:0	Offset:14	3.7
```





