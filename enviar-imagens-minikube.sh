./gradlew build
eval $(minikube docker-env)
docker-compose build
docker pull mysql:8.0.32
docker pull mongo:6.0.4
docker pull rabbitmq:3.11.8-management
docker pull openzipkin/zipkin:2.24.0

for f in kubernetes/helm/components/*; do helm dep up $f; done
for f in kubernetes/helm/environments/*; do helm dep up $f; done
helm dep ls kubernetes/helm/environments/dev-env/
helm template kubernetes/helm/environments/dev-env


helm install hands-on-dev-env  kubernetes/helm/environments/dev-env -n hands-on