# microservices_v3
- este projeto faz uso da arquitetura de microservices utilizando no primeiro momento spring cloud / spring boot 3
- abaixo os recursos para atender a arquitetura de microservices:
  - spring gateway
  - resilience4j para circuit breaker
  - micrometer para uso de trace (openTelemetry)
  - eureka para server discovery
  - oauth2
  - spring load balance
  - spring cloud config

## oAuth2 e openId Connect
- oauth2 é para delegar a autorização e o openid connect é uma complemento a ele
- alguns conceitos participantes no oauth2
  - resource owner: usuario final
  - client: aplicação terceira que fará operações em nome do usuário final
  - resource server: aonde encontram-se as apis que queremos proteger
  - authorization server: aplicação que emite o token para o client, após o usuário final ter sido autenticado
- fluxos utilizados pelo oauth2 para concessão de autorização:
  - authorization code
  - concessão explícita (não está na versão 2.1)
  - resource owner password credentials (não está na versão 2.1)
  - client credentials

## openid connect (OIDC)
- forma que permite app clientes verificarem a identidade dos usuários
- isso é possível graças ao jwt (json web token)
- nele possui dados do usuário, como login, email e etc
- além de ser assinado digitalmente
- para validar a assinatura, os apps protegidos pegam a chave público do authorization server que emitiu o token


## oauth2 configuração
- as authorities precisam ser especificados com SCOPE_alguma coisa, por convenção no oauth2
- para o exemplo deste projeto, afim de solicitar um token fica authorization code, chame a rl https://localhost:8443/oauth2/authorize?response_type=code&client_id=reader&redirect_uri=https://my.redirect.uri&scope=product:read&state=35725
- com o resultado code, insira no script abaixo:
```
curl -k https://reader:secret-reader@localhost:8443/oauth2/token -d grant_type=authorization_code -d client_id=reader -d redirect_uri=https://my.redirect.uri -d code=$CODE -s | jq
```
- para solicitar um token, via client credentials (quando usamos para autenticação entre aplicações), execute o script abaixo:
```
curl -k https://writer:secret-writer@localhost:8443/oauth2/token -d grant_type=client_credentials -d scope="product:read product:write" -s | jq
```

## docker-compose
- caso queira utilizar valores para variaveis de ambiente, dentro do docker-compose, 
- coloque em um arquivo de nome .env, no local aonde encontra-se o arquivo docker-compose.yml

## config server
- para buscar as configurações de um microservice e perfil específico:
```
curl https://dev-usr:dev-pwd@localhost:8443/config/product/docker -ks | jq .
```

## Criptografando e descriptografando informações confidenciais
- o servidor de configuração expõe o endpoint /encrypt e /decrypt, para encriptar dado ou descriptar
- o dado encriptado pelo servidor de configuração, deve ser inserido com prefixo {cipher} e envolve-lo em ''
- exemplo para encryptar uma informação:
```
curl -k https://dev-usr:dev-pwd@localhost:8443/config/encrypt --data-urlencode "hello world"

curl -k https://dev-usr:dev-pwd@localhost:8443/config/decrypt -d d91001603dcdf3eb1392ccbd40ff201cdcf7b9af2fcaab3da39e37919033b206
```

## resilience4j
- afim de melhorar a resiliencia das nossas apps, diante a erros na comunicação sincrona
- alguns mecaninsmos:
  - circuit breaker
  - time limiter
  - retry

### resilience4j circuit breaker
- as principais características de um disjuntor são as seguintes:
  - se um disjuntor detectar muitas falhas, abrirá o circuito, ou seja, não permitirá novas chamadas
  - com o circuito aberto, o disjuntor executará uma lógica fail-fast, ou seja, chamará o método fallback
  - depois de um tempo, o disjuntor ficará semi aberto, permitindo novas chamadas, afim de verificar se o problema foi resolvido
  - caso tenha sido resolvido, o ficará fechado ou manterá aberto.
  - o resilience4j publica seus eventos no actuator/health e actuator/circuitbreakerevents.
- algumas configurações do resilience4j:
  - slidingWindowType: janela deslizante, afim de tomar decisão, em tempo ou contagem, para abrir o disjuntor
  - slidingWindowSize: número de chamadas em um estado fechado, para determinar se deve abrir o disjuntor
  - failureRateThreshold: limite em porcentagem, para chamdas com falha que causarão a abertura do circuito
  - automaticTransitionFromOpenToHalfOpenEnabled: determina se o disjuntor fará a transição automática pra o estado semiaberto 
  - waitDurationInOpenState: especifica o tempo que o circuito permanece aberto, antes de passar para o semi aberto.
  - permittedNumberOfCallsInHalfOpenState: quantidade de chamadas no estado semi aberto, para determinar se a chamada irá para o aberto ou fechado (leva em consideração o percentual failureRateThreshold)
  - ignoreExceptions: exceptions que não participam da contagem
  - registerHealthIndicator: permite que o resilience4j preencha o endpoint actuator sobre seus disjuntores
  - allowHealthIndicatorToFail: indica se deixará o componente como down ou up, caso o disjuntor esteja aberto
  - management.health.circuitbreakers.enabled: true : adicionar informações de integridado do disjuntor
  - timeoutDuration: tempo limite para retorno de uma chamada externa
- retry:
  - os eventos são inseridos no /actuator/retryevents
  - maxAttempts: número de tentativas antes de desistir
  - waitDuration: tempo de espera antes da próxima tentativa
  - retryExceptions: uma lista de exceptions, que acionará uma nova tentativa (cuidade para não abrir o circuit breaker, antes de terminar as retentativas)

### ponto importante do resilience4j
- ponto importante e a ordem de precedência:
  - Retry ( CircuitBreaker ( RateLimiter ( TimeLimiter ( Bulkhead ( Function ) ) ) ) )