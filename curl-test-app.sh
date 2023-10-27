ACCESS_TOKEN=$(curl -k https://writer:secret-writer@minikube.me/oauth2/token -d grant_type=client_credentials -d scope="product:read product:write" -s | jq .access_token -r)
echo ACCESS_TOKEN=$ACCESS_TOKEN
curl -ks https://minikube.me/product-composite/1 -H "Authorization: Bearer $ACCESS_TOKEN" | jq .productId