./gradlew build
eval $(minikube docker-env)
docker-compose up -d mongodb mysql rabbitmq
docker-compose build
docker tag hands-on/auth-server hands-on/auth-server:v1
docker tag hands-on/product-composite-service hands-on/product-composite-service:v1
docker tag hands-on/product-service hands-on/product-service:v1
docker tag hands-on/recommendation-service hands-on/recommendation-service:v1
docker tag hands-on/review-service hands-on/review-service:v1
docker tag hands-on/product-service hands-on/product-service:v2
docker tag hands-on/recommendation-service hands-on/recommendation-service:v2
docker tag hands-on/review-service hands-on/review-service:v2

for f in kubernetes/helm/components/*; do helm dep up $f; done
for f in kubernetes/helm/environments/*; do helm dep up $f; done
helm dep ls kubernetes/helm/environments/prod-env/
helm template kubernetes/helm/environments/prod-env

helm upgrade --install istio-hands-on-addons kubernetes/helm/environments/istio-system -n istio-system --wait
kubectl apply -f kubernetes/hands-on-namespace.yml

helm install hands-on-prod-env  kubernetes/helm/environments/prod-env -n hands-on