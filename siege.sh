ACCESS_TOKEN=$(curl https://writer:secret-writer@minikube.me/oauth2/token -d grant_type=client_credentials -d scope="product:read product:write" -ks | jq .access_token -r)
echo ACCESS_TOKEN=$ACCESS_TOKEN
siege https://minikube.me/product-composite/1001 -H "Authorization: Bearer $ACCESS_TOKEN" -c1 -d1 -v