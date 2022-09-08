kafka-mirror-maker.sh --consumer.config config/source-mirror.config --num.streams 1 --producer.config config/target-mirror.config --whitelist='test-topic-.*'
