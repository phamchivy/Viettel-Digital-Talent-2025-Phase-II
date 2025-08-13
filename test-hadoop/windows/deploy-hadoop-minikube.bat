@echo off
REM Hadoop on Minikube Windows Deployment Script

echo ===================================
echo Hadoop on Minikube - Windows Setup
echo ===================================

REM Check if kubectl is available
kubectl version --client >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: kubectl not found. Please install kubectl first.
    pause
    exit /b 1
)

REM Check if minikube is running
minikube status >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Minikube is not running. Please start minikube first.
    echo Run: minikube start
    pause
    exit /b 1
)

echo [INFO] Checking Minikube status...
minikube status

echo.
echo [INFO] Current kubectl context:
kubectl config current-context

echo.
echo ===================================
echo Choose deployment option:
echo 1. Deploy Hadoop (Simple)
echo 2. Check Status
echo 3. Access Web UIs
echo 4. Test HDFS
echo 5. Cleanup
echo 6. Exit
echo ===================================

set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto deploy
if "%choice%"=="2" goto status
if "%choice%"=="3" goto webui
if "%choice%"=="4" goto test
if "%choice%"=="5" goto cleanup
if "%choice%"=="6" goto exit
goto invalid

:deploy
echo.
echo [INFO] Deploying complete Hadoop cluster to Minikube...
echo.

echo [INFO] Step 1: Creating namespace and configmap...
kubectl apply -f hadoop-namespace-configmap.yaml
if %errorlevel% neq 0 (
    echo ERROR: Failed to create namespace/configmap
    pause
    goto menu
)

echo [INFO] Step 2: Deploying NameNode...
kubectl apply -f namenode-deployment.yaml
if %errorlevel% neq 0 (
    echo ERROR: Failed to deploy NameNode
    pause
    goto menu
)

echo [INFO] Waiting for NameNode to be ready...
kubectl wait --for=condition=Ready pod -l app=hadoop-namenode -n hadoop --timeout=300s

echo [INFO] Step 3: Deploying DataNodes...
kubectl apply -f datanode-deployment.yaml
if %errorlevel% neq 0 (
    echo ERROR: Failed to deploy DataNodes
    pause
    goto menu
)

echo [INFO] Step 4: Deploying YARN components...
kubectl apply -f yarn-deployment.yaml
if %errorlevel% neq 0 (
    echo ERROR: Failed to deploy YARN components
    pause
    goto menu
)

echo [INFO] Waiting for all components to be ready...
timeout /t 30 /nobreak >nul

echo.
echo [INFO] Checking deployment status...
kubectl get pods -n hadoop -o wide
echo.
kubectl get services -n hadoop

echo.
echo [INFO] Complete Hadoop cluster deployment finished!
echo Access Web UIs using option 3.
pause
goto menu

:status
echo.
echo [INFO] Checking Hadoop cluster status...
echo.
echo === PODS ===
kubectl get pods -n hadoop -o wide
echo.
echo === SERVICES ===
kubectl get services -n hadoop
echo.
echo === NODES ===
kubectl get nodes
pause
goto menu

:webui
echo.
echo [INFO] Setting up access to Web UIs...
echo.

REM Get NodePort for NameNode
for /f "tokens=5 delims=: " %%a in ('kubectl get service hadoop-namenode -n hadoop -o^=jsonpath^="{.spec.ports[1].nodePort}"') do set NAMENODE_PORT=%%a

REM Get NodePort for ResourceManager  
for /f "tokens=5 delims=: " %%a in ('kubectl get service hadoop-resourcemanager -n hadoop -o^=jsonpath^="{.spec.ports[0].nodePort}"') do set RM_PORT=%%a

REM Get Minikube IP
for /f "tokens=*" %%a in ('minikube ip') do set MINIKUBE_IP=%%a

echo Minikube IP: %MINIKUBE_IP%
echo.
echo Web UIs are available at:
echo NameNode Web UI: http://%MINIKUBE_IP%:%NAMENODE_PORT%
echo ResourceManager Web UI: http://%MINIKUBE_IP%:%RM_PORT%
echo.
echo Opening browsers...
start http://%MINIKUBE_IP%:%NAMENODE_PORT%
start http://%MINIKUBE_IP%:%RM_PORT%

pause
goto menu

:test
echo.
echo [INFO] Testing HDFS...

REM Get NameNode pod name
for /f "tokens=*" %%a in ('kubectl get pod -l app^=hadoop-namenode -n hadoop -o jsonpath^="{.items[0].metadata.name}"') do set NAMENODE_POD=%%a

if "%NAMENODE_POD%"=="" (
    echo ERROR: NameNode pod not found
    pause
    goto menu
)

echo NameNode Pod: %NAMENODE_POD%
echo.

echo [INFO] Creating test directory...
kubectl exec -n hadoop %NAMENODE_POD% -- hdfs dfs -mkdir -p /user/test

echo [INFO] Listing HDFS root directory...
kubectl exec -n hadoop %NAMENODE_POD% -- hdfs dfs -ls /

echo [INFO] Creating test file...
kubectl exec -n hadoop %NAMENODE_POD% -- bash -c "echo 'Hello Hadoop on Minikube!' | hdfs dfs -put - /user/test/hello.txt"

echo [INFO] Reading test file...
kubectl exec -n hadoop %NAMENODE_POD% -- hdfs dfs -cat /user/test/hello.txt

echo [INFO] HDFS test completed!
pause
goto menu

:cleanup
echo.
set /p confirm="Are you sure you want to delete complete Hadoop deployment? (y/N): "
if /i not "%confirm%"=="y" goto menu

echo [INFO] Cleaning up complete Hadoop deployment...
echo [INFO] Removing YARN components...
kubectl delete -f yarn-deployment.yaml --ignore-not-found=true

echo [INFO] Removing DataNodes...
kubectl delete -f datanode-deployment.yaml --ignore-not-found=true

echo [INFO] Removing NameNode...
kubectl delete -f namenode-deployment.yaml --ignore-not-found=true

echo [INFO] Removing namespace and configmap...
kubectl delete -f hadoop-namespace-configmap.yaml --ignore-not-found=true

echo [INFO] Complete cleanup finished!
pause
goto menu

:invalid
echo Invalid choice. Please try again.
pause

:menu
cls
goto start

:exit
echo.
echo Goodbye!
pause