#!/bin/zsh

mm_cg_name=mirror-maker
source_alias=primary
source_bootstrap=localhost:9094
target_bootstrap=localhost:9095
working_dir=/tmp


kafka-consumer-groups.sh --bootstrap-server ${source_bootstrap} --describe --group ${mm_cg_name} | awk -v group=$mm_cg_name '$1 == group { print $2,$3,$4-1 }' | tee ${working_dir}/mm-migration-offset.csv

for topic partition offset in $(cat ${working_dir}/mm-migration-offset.csv); do
  printf '["MirrorSourceConnector",{"cluster":"%s","partition":%s,"topic":"%s"}]|{"offset":%s}\n' $source_alias $partition $topic $offset 
done | tee ${working_dir}/mm-migration-offset.jsons

kafka-topics.sh --bootstrap-server ${target_bootstrap} --create --topic mm2-offsets.$source_alias.internal --partitions 25 --config cleanup.policy=compact

cat ${working_dir}/mm-migration-offset.jsons | kafka-console-producer.sh --bootstrap-server ${target_bootstrap} --topic mm2-offsets.$source_alias.internal --property key.separator=\| --property parse.key=true




