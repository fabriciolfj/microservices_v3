helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --create-namespace \
  --namespace cert-manager \
  --version v1.11.0 \
  --set installCRDs=true \
  --wait