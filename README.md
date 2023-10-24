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

## Rastreamento ou tracing
- mecanismo de ver o caminho de processos executados na nossa aplicação, sejam eles via http, mensageria e etc.
- ele é composto por trace (fluxo completo) e spans (cada etapa do fluxo ou chamada)
- em termos de codigo, o rastreamento se parece com este:
  - traceparent:"00-2425f26083814f66c985c717a761e810-fbec8704028cfb20-01" 
```
00, indica a versão usada. Sempre será “ 00" usando a especificação atual.
124…810, é o ID de rastreamento.
fbe…b20é o ID do intervalo.
01, a última parte, contém vários sinalizadores. 
O único sinalizador suportado pela especificação atual é um 
sinalizador chamado sampled, com o valor 01. Isso significa 
que o chamador está gravando os dados de rastreamento dessa 
solicitação. Configuraremos nossos microsserviços para 
registrar dados de rastreamento para todas as solicitações, portanto, esse sinalizador sempre terá o valor de 01.
```
- para rastreamentos personalizados, consulte: https://micrometer.io/docs/observation
- configuração basica:
```
management.zipkin.tracing.endpoint: http://zipkin:9411/api/v2/spans
management.tracing.sampling.probability: 1.0
```
- no momento a api micrometer se não se da bem com reactor, para contornar devemos fazer uso:
```
 Hooks.enableAutomaticContextPropagation(); no método main do app
```
- para webclient, devemos adicionar a function:
````
  @Autowired
  private ReactorLoadBalancerExchangeFilterFunction lbFunction;

  @Bean
  public WebClient webClient(WebClient.Builder builder) {
    return builder.filter(lbFunction).build();
  }
````


# Kubernetes

## Suporte spring para desligamento 
- graceful shutdown: o microservice para de aceitar novas solicitações e aguarda um tempo configurável para que as solicitações ativas sejam concluídas antes de encerrar o aplicativo
```
server.shutdown: graceful
spring.lifecycle.timeout-per-shutdown-phase: 10s
```

- liveness e readiness probes: informa ao kubernetes se seu pod está pronto para aceitar solicitações. Podemos incluir no indicador de integridade, recursos que o ms utiliza, como mongodb e etc.
```
management.endpoint.health.probes.enabled: true
management.endpoint.health.group.readiness.include: readinessState, rabbit, db, mongo
#maiores detalhes consulte https://docs.spring.io/spring-boot/docs/3.0.4/reference/htmlsingle/#actuator.endpoints.kubernetes-probes
```

## Helm
- gerenciador de pacotes
- um pacote e conhecido como chart
- chart contem modelos, valores padrão para os modelos e dependências opcionais
- lib hart não contem nenhuma definição implantável, mas apenas modelos que devem ser usados por outros charts para manifestos kubernetes


## Looking into a Helm chart
- no helm temos a seguinte estrutura?
  - chart.yaml  (informações  sobre o chart e se depende de outros charts)
  - templates, pasta que contém os modelos de uso
  - Chart.lock, para solução de dependencias, rastreio ate aonde implantou o chart
  - .helmignore, similar ao .ignore do git
- alguns modelos para passagem de valores para o chart:
  - Values: usado para se referir a valores no values.yamlarquivo do gráfico ou valores fornecidos ao executar um Helmcomando como install.
  - Release: usado para fornecer metadados relativos à versão atual instalada. Ele contém campos como:
    - Name: O nome do lançamento
    - Namespace: O nome do namespace onde a instalação é executada
    - Service: O nome do Serviço de instalação, sempre retornandoHelm
  - Chart: Usado para acessar informações do Chart.yamlarquivo. Exemplos de campos que podem ser úteis para fornecer metadados para uma implantação são:
    - Name: O nome do gráfico
    - Version: o número da versão do gráfico
  - Files: Contém funções para acessar arquivos específicos do gráfico. Neste capítulo, usaremos as duas funções a seguir no Filesobjeto:
    - Glob: Retorna arquivos em um gráficobaseado em um padrão glob . Por exemplo, o padrão "config-repo/*"retornará todos os arquivos encontrados na pastaconfig-repo
    - AsConfig: Retorna o conteúdo dos arquivos como um mapa YAML apropriado para declarar valores em umConfigMap
  - Capabilities: pode ser usado para localizar informações sobre os recursos do cluster Kubernetes no qual a instalação é executada.
- para modelos nomeados, que serão usados por outros modelos, não para criar um manifesto em si, devem iniciaro nome com sublinhado _
- o helm podemos utilizar algumas funções, como:
  - {{ (.Files.Glob "config-repo/*").AsConfig | indent 2 }}, no caso pega os arquivos do config-repo, formata do jeito yaml, com recuso de 2 espaços
- alguns comandos do helm, para ver a saida dos charts, usando os dados do values:
````
helm dependency update components/gateway
helm template components/gateway -s templates/service.yaml
````
- alguns comandos uteis, para ver as imagens geradas e implantadas
````
 kubectl get pods -o json | jq .items[].spec.containers[].image
````
## atenção

- um ponto de atenção, nesse projeto temos o chart pai que está na pasta environment, charts filhos que são os componentes
- a estrutura do helm funciona da seguinte forma:
  -  na pasta environment, temos:
    - o values, com dados do ambiente
    - charts, dependencias de outros charts (que podemos fazer uso do values tambem)
    - templates, referenciando os templates que que faram uso dos values
  - na pasta componentes, seguem de forma similar:
    - o arquivo chart, referenciando outros charts que serão utilizados (que podem fazer uso do values tambem)
    - values, com valor de cada componente, esse values são utilizados nos templates referenciados, na pasta template
    - charts, as dependencias

## cert manager
- é um controlador de gerenciamento de certificados no kubernetes
- ele pode gerar certificado que são provisionados quando o ingress (que o referencia) é criado (se o ingress tiver referencia)
- novo local do swagger: https://minikube.me/openapi/webjars/swagger-ui/index.html#/