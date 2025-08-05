# 5g_producer_confluent.py
from confluent_kafka import Producer
import json
import time
import random
from datetime import datetime

# Cấu hình producer
producer_config = {
    'bootstrap.servers': 'localhost:9092',
    'client.id': '5g-data-producer'
}

producer = Producer(producer_config)

def delivery_report(err, msg):
    """Callback để báo cáo kết quả gửi message"""
    if err is not None:
        print(f'Message delivery failed: {err}')
    else:
        print(f'Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}')

def generate_5g_data():
    """Tạo dữ liệu mô phỏng từ mạng 5G"""
    return {
        'timestamp': datetime.now().isoformat(),
        'cell_id': f"5G_CELL_{random.randint(1, 20)}",
        'user_id': f"USER_{random.randint(1000, 9999)}",
        'device_type': random.choice(['smartphone', 'iot_sensor', 'autonomous_vehicle', 'ar_device']),
        'location': {
            'lat': round(random.uniform(21.0, 21.1), 6),  # Hanoi coordinates
            'lon': round(random.uniform(105.8, 105.9), 6)
        },
        'network_metrics': {
            'rsrp_dbm': random.randint(-120, -60),     # Reference Signal Received Power
            'rsrq_db': random.randint(-20, -3),        # Reference Signal Received Quality
            'sinr_db': random.randint(-5, 30),         # Signal to Interference plus Noise Ratio
            'throughput_mbps': round(random.uniform(10, 1000), 2),
            'latency_ms': round(random.uniform(1, 10), 2),
            'packet_loss_percent': round(random.uniform(0, 5), 2)
        },
        'data_usage_mb': round(random.uniform(0.1, 100), 2),
        'service_type': random.choice(['video_streaming', 'web_browsing', 'gaming', 'iot_telemetry', 'autonomous_driving']),
        'qos_class': random.choice(['eMBB', 'URLLC', 'mMTC'])  # 5G QoS classes
    }

def main():
    topic = '5g-network-data'
    
    print(f"🚀 Bắt đầu gửi dữ liệu 5G đến topic: {topic}")
    print("Nhấn Ctrl+C để dừng\n")
    
    try:
        message_count = 0
        while True:
            # Tạo dữ liệu 5G
            data = generate_5g_data()
            key = data['cell_id']
            
            # Chuyển đổi dữ liệu thành JSON
            value = json.dumps(data)
            
            # Gửi đến Kafka (async)
            producer.produce(
                topic=topic,
                key=key,
                value=value,
                callback=delivery_report
            )
            
            # Trigger delivery reports
            producer.poll(0)
            
            message_count += 1
            print(f"📡 Sent #{message_count}: {data['cell_id']} | "
                  f"{data['device_type']} | "
                  f"Throughput: {data['network_metrics']['throughput_mbps']} Mbps | "
                  f"Latency: {data['network_metrics']['latency_ms']} ms | "
                  f"QoS: {data['qos_class']}")
            
            time.sleep(2)  # Gửi mỗi 2 giây
            
    except KeyboardInterrupt:
        print(f"\n⏹️  Đang dừng producer... Đã gửi {message_count} messages")
    finally:
        # Chờ tất cả messages được gửi
        producer.flush()
        print("✅ Producer đã dừng")

if __name__ == "__main__":
    main()