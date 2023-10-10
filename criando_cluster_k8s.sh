unset KUBECONFIG
minikube start \
 --memory=10240 \
 --cpus=4 \
 --disk-size=30g \
 --driver=docker \
 --ports=8080:80 --ports=8443:443 \
 --ports=30080:30080 --ports=30443:30443
minikube addons enable ingress
minikube addons enable metrics-server