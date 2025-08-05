::# Triển khai Zookeeper
kubectl apply -f zookeeper.yaml

::# Chờ Zookeeper sẵn sàng
kubectl wait --for=condition=available --timeout=300s deployment/zookeeper -n kafka

::# Triển khai Kafka
kubectl apply -f kafka.yaml

::# Chờ Kafka sẵn sàng
kubectl wait --for=condition=available --timeout=300s deployment/kafka -n kafka

::# Triển khai Kafka UI
kubectl apply -f kafka-ui.yaml

::# Kiểm tra trạng thái
kubectl get pods -n kafka