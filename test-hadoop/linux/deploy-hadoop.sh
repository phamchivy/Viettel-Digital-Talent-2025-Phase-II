#!/bin/bash

# Hadoop on Kubernetes Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl không được tìm thấy. Vui lòng cài đặt kubectl."
        exit 1
    fi
    print_status "kubectl đã sẵn sàng"
}

# Check cluster connectivity
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Không thể kết nối với Kubernetes cluster"
        exit 1
    fi
    print_status "Kết nối cluster thành công"
}

# Deploy function
deploy_hadoop() {
    print_status "Bắt đầu triển khai Hadoop trên Kubernetes..."
    
    # Create namespace and configmap
    print_status "Tạo namespace và configmap..."
    kubectl apply -f hadoop-namespace-configmap.yaml
    
    # Wait for namespace to be ready
    kubectl wait --for=condition=Active namespace/hadoop --timeout=60s
    
    # Deploy NameNode
    print_status "Triển khai NameNode..."
    kubectl apply -f namenode-deployment.yaml
    
    # Wait for NameNode to be ready
    print_status "Đợi NameNode khởi động..."
    kubectl wait --for=condition=Ready pod -l app=hadoop-namenode -n hadoop --timeout=300s
    
    # Deploy DataNodes
    print_status "Triển khai DataNodes..."
    kubectl apply -f datanode-deployment.yaml
    
    # Deploy YARN components
    print_status "Triển khai YARN (ResourceManager và NodeManager)..."
    kubectl apply -f yarn-deployment.yaml
    
    print_status "Đợi các thành phần khởi động hoàn tất..."
    sleep 30
    
    # Check status
    check_deployment_status
}

# Check deployment status
check_deployment_status() {
    print_status "Kiểm tra trạng thái triển khai..."
    
    echo "=== PODS ==="
    kubectl get pods -n hadoop -o wide
    
    echo -e "\n=== SERVICES ==="
    kubectl get services -n hadoop
    
    echo -e "\n=== PERSISTENT VOLUMES ==="
    kubectl get pvc -n hadoop
    
    # Check if NameNode is accessible
    if kubectl get pod -l app=hadoop-namenode -n hadoop | grep Running; then
        print_status "NameNode đang chạy"
        NAMENODE_POD=$(kubectl get pod -l app=hadoop-namenode -n hadoop -o jsonpath='{.items[0].metadata.name}')
        echo "NameNode pod: $NAMENODE_POD"
    else
        print_warning "NameNode chưa sẵn sàng"
    fi
}

# Setup port forwarding
setup_port_forwarding() {
    print_status "Thiết lập port forwarding cho Web UI..."
    
    # NameNode Web UI
    kubectl port-forward -n hadoop service/hadoop-namenode 9870:9870 &
    NAMENODE_PF_PID=$!
    
    # ResourceManager Web UI  
    kubectl port-forward -n hadoop service/hadoop-resourcemanager 8088:8088 &
    RESOURCEMANAGER_PF_PID=$!
    
    print_status "Port forwarding đã được thiết lập:"
    echo "  - NameNode Web UI: http://localhost:9870"
    echo "  - ResourceManager Web UI: http://localhost:8088"
    echo ""
    echo "Để dừng port forwarding, nhấn Ctrl+C hoặc chạy:"
    echo "  kill $NAMENODE_PF_PID $RESOURCEMANAGER_PF_PID"
}

# Test HDFS
test_hdfs() {
    print_status "Kiểm tra HDFS..."
    
    NAMENODE_POD=$(kubectl get pod -l app=hadoop-namenode -n hadoop -o jsonpath='{.items[0].metadata.name}')
    
    # Create test directory
    kubectl exec -n hadoop $NAMENODE_POD -- hdfs dfs -mkdir -p /user/test
    
    # List directories
    kubectl exec -n hadoop $NAMENODE_POD -- hdfs dfs -ls /
    
    # Create test file
    kubectl exec -n hadoop $NAMENODE_POD -- bash -c "echo 'Hello Hadoop on Kubernetes!' | hdfs dfs -put - /user/test/hello.txt"
    
    # Read test file
    kubectl exec -n hadoop $NAMENODE_POD -- hdfs dfs -cat /user/test/hello.txt
    
    print_status "HDFS test hoàn tất!"
}

# Cleanup function
cleanup_hadoop() {
    print_warning "Xóa Hadoop deployment..."
    
    kubectl delete -f yarn-deployment.yaml --ignore-not-found=true
    kubectl delete -f datanode-deployment.yaml --ignore-not-found=true  
    kubectl delete -f namenode-deployment.yaml --ignore-not-found=true
    kubectl delete -f hadoop-namespace-configmap.yaml --ignore-not-found=true
    
    print_status "Cleanup hoàn tất!"
}

# Scale function
scale_datanodes() {
    local replicas=${1:-3}
    print_status "Scaling DataNodes to $replicas replicas..."
    
    # For DaemonSet, we use node selector instead
    print_warning "DataNodes được triển khai dưới dạng DaemonSet, sẽ chạy trên tất cả nodes"
    print_warning "Để giới hạn, sử dụng nodeSelector hoặc taints/tolerations"
}

# Monitor function
monitor_hadoop() {
    print_status "Theo dõi Hadoop cluster..."
    
    while true; do
        clear
        echo "=== HADOOP CLUSTER STATUS ==="
        echo "Time: $(date)"
        echo ""
        
        echo "=== PODS ==="
        kubectl get pods -n hadoop
        echo ""
        
        echo "=== SERVICES ==="
        kubectl get services -n hadoop
        echo ""
        
        echo "Nhấn Ctrl+C để dừng monitoring..."
        sleep 10
    done
}

# Main menu
show_menu() {
    echo "=== HADOOP ON KUBERNETES DEPLOYMENT ==="
    echo "1. Deploy Hadoop"
    echo "2. Check Status" 
    echo "3. Setup Port Forwarding"
    echo "4. Test HDFS"
    echo "5. Monitor Cluster"
    echo "6. Scale DataNodes"
    echo "7. Cleanup"
    echo "8. Exit"
    echo ""
}

# Main script
main() {
    check_kubectl
    check_cluster
    
    while true; do
        show_menu
        read -p "Chọn tùy chọn (1-8): " choice
        
        case $choice in
            1)
                deploy_hadoop
                ;;
            2)
                check_deployment_status
                ;;
            3)
                setup_port_forwarding
                ;;
            4)
                test_hdfs
                ;;
            5)
                monitor_hadoop
                ;;
            6)
                read -p "Nhập số lượng DataNode replicas: " replicas
                scale_datanodes $replicas
                ;;
            7)
                read -p "Bạn có chắc chắn muốn xóa Hadoop deployment? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    cleanup_hadoop
                fi
                ;;
            8)
                print_status "Thoát..."
                exit 0
                ;;
            *)
                print_error "Lựa chọn không hợp lệ"
                ;;
        esac
        
        echo ""
        read -p "Nhấn Enter để tiếp tục..."
    done
}

# Run main function
main