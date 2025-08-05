# 5g_consumer_confluent.py
from confluent_kafka import Consumer, KafkaError
import json
from collections import defaultdict
import signal
import sys

# Cấu hình consumer
consumer_config = {
    'bootstrap.servers': 'localhost:9092',
    'group.id': '5g-analytics-group',
    'auto.offset.reset': 'latest',
    'enable.auto.commit': True,
    'client.id': '5g-data-consumer'
}

consumer = Consumer(consumer_config)

# Statistics tracking
stats = defaultdict(lambda: {
    'message_count': 0,
    'total_throughput': 0,
    'total_latency': 0,
    'device_types': set(),
    'qos_classes': set(),
    'avg_packet_loss': 0,
    'total_packet_loss': 0
})

def analyze_5g_data(data):
    """Phân tích dữ liệu 5G với metrics chi tiết"""
    cell_id = data['cell_id']
    
    # Cập nhật thống kê
    stats[cell_id]['message_count'] += 1
    stats[cell_id]['total_throughput'] += data['network_metrics']['throughput_mbps']
    stats[cell_id]['total_latency'] += data['network_metrics']['latency_ms']
    stats[cell_id]['total_packet_loss'] += data['network_metrics']['packet_loss_percent']
    stats[cell_id]['device_types'].add(data['device_type'])
    stats[cell_id]['qos_classes'].add(data['qos_class'])
    
    # Tính trung bình
    count = stats[cell_id]['message_count']
    avg_throughput = stats[cell_id]['total_throughput'] / count
    avg_latency = stats[cell_id]['total_latency'] / count
    avg_packet_loss = stats[cell_id]['total_packet_loss'] / count
    
    return {
        'cell_id': cell_id,
        'message_count': count,
        'avg_throughput_mbps': round(avg_throughput, 2),
        'avg_latency_ms': round(avg_latency, 2),
        'avg_packet_loss_percent': round(avg_packet_loss, 2),
        'device_types_count': len(stats[cell_id]['device_types']),
        'qos_classes': list(stats[cell_id]['qos_classes']),
        'current_user': data['user_id'],
        'current_service': data['service_type']
    }

def signal_handler(sig, frame):
    """Xử lý signal để dừng consumer gracefully"""
    print('\n⏹️  Đang dừng consumer...')
    consumer.close()
    sys.exit(0)

def main():
    # Đăng ký signal handler
    signal.signal(signal.SIGINT, signal_handler)
    
    topic = '5g-network-data'
    consumer.subscribe([topic])
    
    print(f"🔍 Bắt đầu consume dữ liệu 5G từ topic: {topic}")
    print("Nhấn Ctrl+C để dừng\n")
    
    try:
        while True:
            msg = consumer.poll(1.0)  # Timeout 1 giây
            
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    print(f'Reached end of partition {msg.partition()}')
                else:
                    print(f'Error: {msg.error()}')
                continue
            
            # Parse JSON data
            try:
                data = json.loads(msg.value().decode('utf-8'))
                analysis = analyze_5g_data(data)
                
                # Hiển thị thông tin phân tích
                print(f"📡 {analysis['cell_id']} | "
                      f"Msgs: {analysis['message_count']:>3} | "
                      f"Avg Throughput: {analysis['avg_throughput_mbps']:>6} Mbps | "
                      f"Avg Latency: {analysis['avg_latency_ms']:>4} ms | "
                      f"Packet Loss: {analysis['avg_packet_loss_percent']:>4}% | "
                      f"Devices: {analysis['device_types_count']} | "
                      f"QoS: {', '.join(analysis['qos_classes'])} | "
                      f"Service: {analysis['current_service']}")
                
                # Alerts cho performance issues
                if analysis['avg_throughput_mbps'] < 50:
                    print(f"⚠️  LOW THROUGHPUT: {analysis['cell_id']} - {analysis['avg_throughput_mbps']} Mbps")
                
                if analysis['avg_latency_ms'] > 20:
                    print(f"⚠️  HIGH LATENCY: {analysis['cell_id']} - {analysis['avg_latency_ms']} ms")
                    
                if analysis['avg_packet_loss_percent'] > 2:
                    print(f"⚠️  HIGH PACKET LOSS: {analysis['cell_id']} - {analysis['avg_packet_loss_percent']}%")
                
            except json.JSONDecodeError as e:
                print(f"❌ Error parsing JSON: {e}")
                
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        consumer.close()
        print("✅ Consumer đã dừng")

if __name__ == "__main__":
    main()