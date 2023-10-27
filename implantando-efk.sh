eval $(minikube docker-env)
docker pull docker.elastic.co/elasticsearch/elasticsearch:7.17.10
docker pull docker.elastic.co/kibana/kibana:7.17.10


helm install logging-hands-on-add-on kubernetes/helm/environments/logging \
    -n logging --create-namespace --wait