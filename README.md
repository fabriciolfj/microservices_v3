# microservices_v3
- este projeto faz uso da arquitetura de microservices utilizando no primeiro momento spring cloud / spring boot 3
- abaixo os recursos para atender a arquitetura de microservices:
  - spring gateway
  - resilience4j para circuit breaker 
  - micrometer para uso de trace (openTelemetry)
```
implementation 'io.micrometer:micrometer-tracing-bridge-brave'
implementation 'io.zipkin.reporter2:zipkin-reporter-brave'
```
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
  - retryExceptions: uma lista de exceptions, que acionará uma nova tentativa (cuidado para não abrir o circuit breaker, antes de terminar as retentativas)

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
  - mesmo se aplica a pasta commons, 
- a prioridade vem da pasta environments -> components -> commons

## cert manager
- é um controlador de gerenciamento de certificados no kubernetes
- ele pode gerar certificado que são provisionados quando o ingress (que o referencia) é criado (se o ingress tiver referencia)
- novo local do swagger: https://minikube.me/openapi/webjars/swagger-ui/index.html#/
- no exemplo abaaixo usamos o ca autoassinada (certificado autoassinado, ou seja emissor do certificado)
```
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ca-cert
spec:
  isCA: true
  commonName: hands-on-ca
  secretName: ca-secret
  issuerRef:
    name: selfsigned-issuer
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-secret
```
- arquivo hands-on-certificate.yaml, faz uso da configuração criada acima

## service mesh
- é uma camada de infraestrutura que controla e observa a comunicação entre serviços
- algumas capacidades:
  - observabilidade
  - segurança
  - aplicação de politicas
  - resiliência
  - gerenciamento de tráfego
- um componente importante no service mesh, é o proxy leve, que é injetado a cada pod do microservice, executando a função de sidecar
- nesse projeto usaremos o istio, ele ja faz uso de outros projetos de código aberto, como prometheus, grafana, jaeger e kiali

### recursos do istio
- gateway -> usado para lidar com a entrada e saída de dados do service mesh
  - um gateway depende de um virtual service para direcionar o tráfego de entrada ao services do k8s (esse recurso substitui o ingress)
  - tem algumas vantagens sobre o ingress, como: reporta telemetria, faz authenticação e autorização, possui roteamente mais refinado
- virtual service -> usado para definir regras de roteamento
- destinarion rule -> usado para definir políticas e regras para o tráfego que é roteado pelo virtual service, para um serviço específico (um destino)
  - por exemplo: usar criptografia
- PeerAuthentication -> usado para controlar a autenticação serviço a serviçop da malha
- requestAuthentication -> usado para atenticar usuários finais, fazendo uso do jwt (configuraremos o istio para utilizar o authorization-server)
- authorizationPolicy -> usaod para fornecer controle de acesso no istio
- para instalar o istio dentro do cluster, usaremos demo (não é indicado para produção, pois faz uso de recursos minímos)
```
istioctl install --skip-confirmation \
  --set profile=demo \
  --set meshConfig.accessLogFile=/dev/stdout \
  --set meshConfig.accessLogEncoding=JSON \ - para conseguirmos ver os logs dos proxies no pods
  --set values.pilot.env.PILOT_JWT_PUB_KEY_REFRESH_INTERVAL=15s \ - renovar o token a cada 15s
  -f kubernetes/istio-tracing.yml - permite a criação de intervalos de rastreamento usados para o rastreamento distribuído
```
- instalando recursos extras
```
istio_version=$(istioctl version --short --remote=false)
echo "Installing integrations for Istio v$istio_version"
kubectl apply -n istio-system -f https://raw.githubusercontent.com/istio/istio/${istio_version}/samples/addons/kiali.yaml
kubectl apply -n istio-system -f https://raw.githubusercontent.com/istio/istio/${istio_version}/samples/addons/jaeger.yaml
kubectl apply -n istio-system -f https://raw.githubusercontent.com/istio/istio/${istio_version}/samples/addons/prometheus.yaml
kubectl apply -n istio-system -f https://raw.githubusercontent.com/istio/istio/${istio_version}/samples/addons/grafana.yaml
```

### problemas de conectividade para uso no minikube
- o gwt do istio faz uso de um serviço do k8s com load balance
- para acessar o gwt, precisamos executar um balanceador de carga na frente do k8s
- para simular um loadbalance com minikube, executaremos o comando minikube tunnel

### configurando o istio neste projeto
- em helm/environments/istio-system, configuração para acessar externamento os recursos e configuração do certifica para requisição https
- no certificado está configurado para os dns dos recursos extrados e do microservice
- modelo helm/common/_istio_base.yaml, possui alguns manifestos, como:
  - gwt e virtual service, o gwt recebe a entrada da requisição para o host minikube.me e health.minikube.me e o vs faz o roteamento para service correspondente
- modelo helm/common/_istio_dr_mutual_tls.yaml, possui o DestinationRule, especificando o uso de mTls e subsets para deploy com inatividade 0
 -  apenas em prod usamos o subsets para versionamento, onde podemos ir trocando aos poucos pelos pods novos, sem deixar o sistema inativo
- execute as etapadas abaixo:
  - o script sh build-apps.sh
  - minikube tunnel em outra janela no terminal 
  - pegue o ip externo kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' ou
```
INGRESS_IP=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo $INGRESS_IP
MINIKUBE_HOSTS="minikube.me grafana.minikube.me kiali.minikube.me prometheus.minikube.me tracing.minikube.me kibana.minikube.me elasticsearch.minikube.me mail.minikube.me health.minikube.me"
echo "$INGRESS_IP $MINIKUBE_HOSTS" | sudo tee -a /etc/hosts
```
- para validar se a configuração ocorreu corretamente
```
curl -o /dev/null -sk -L -w "%{http_code}\n" https://kiali.minikube.me/kiali/
curl -o /dev/null -sk -L -w "%{http_code}\n" https://tracing.minikube.me
curl -o /dev/null -sk -L -w "%{http_code}\n" https://grafana.minikube.me
curl -o /dev/null -sk -L -w "%{http_code}\n" https://prometheus.minikube.me/graph#/
```

- cont Executando comandos para criar a malha de serviço

## siege para testes de carta
```
ACCESS_TOKEN=$(curl https://writer:secret-writer@minikube.me/oauth2/token -d grant_type=client_credentials -d scope="product:read product:write" -ks | jq .access_token -r)
echo ACCESS_TOKEN=$ACCESS_TOKEN
siege https://minikube.me/product-composite/1 -H "Authorization: Bearer $ACCESS_TOKEN" -c1 -d1 -v
```

## autorização e autenticação istio
- as configurações deste projeto, fará uso do nosso ms authorization-server

## mtls istio
- autenticação mútua
- a identidade do serviço e cliente são comprovadas, ou seja, o serviço prova sua identidade e o cliente também
- do lado do serviço
```
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: PERMISSIVE
```
- client
```
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: {{ $dr.name }}
spec:
  host: //omitido
    tls:
      mode: ISTIO_MUTUAL //aqui
```

## atualizações sem tempo de inatividade no istio
- canario: pedemos colocar um percentual de usuários para a nova versão e ir tombando os demais conforme o sucesso dela
- blue-green: deixamos um percentual de usuarios para a nova versão, e gradualmente os demais vão migrando para ela

## EFK
- elasticsearch -> bancos de dados distribuido
- fluentId -> coletor de dados, dividi-se em 3 partes:
  - source: origem da informação, no nosso caso logs dentro dos containers
  - filtro: para transformar/processar o log, extraindo partes interessantes do mesmo
  - match: para onde enviar os logs
- kibana -> frontend do elasticsearch

### exemplo configuração match 
```
   <match kubernetes.**istio**>
      @type rewrite_tag_filter
      <rule>
        key log
        pattern ^(.*)$
        tag istio.${tag}
      </rule>
    </match>

O <match>elemento corresponde a qualquer tag que siga o kubernetes.**istio**padrão, ou seja, tags que começam com Kubernetese depois contêm a palavra istioem algum lugar do nome da tag. istiopode vir do nome do namespace ou dorecipiente; ambos fazem parte da tag.
O <match>elemento contém apenas um <rule>elemento, que prefixa a tag com istio. A ${tag}variável contém o valor atual da tag.
Como este é o único <rule>elemento no <match>elemento, ele é configurado para corresponder a todos os registros de log.
Como todos os registros de log provenientes do Kubernetes possuem um logcampo, o keycampo é definido como log, ou seja, a regra procura um logcampo nos registros de log.
Para corresponder a qualquer string no logcampo, o patterncampo é definido como a ^(.*)$expressão regular. ^marca o início de uma string, enquanto $marca o final de uma string. (.*)corresponde a qualquer número de caracteres, exceto quebras de linha.
Os registros de log são reemitidos para o mecanismo de roteamento Fluentd. Como nenhum outro elemento no arquivo de configuração corresponde às tags que começam com istio, os registros de log serão enviados diretamente para o elemento de saída do Elasticsearch, que é definido no fluent.confarquivo que descrevemos anteriormente.
```

## prometheus e grafana
- prometheus -> armazena dados de série temporal, como métricas de desempenho.
- grafana -> para visualizar métricas de desempenho
- painel indicado para apps feitos em spring boot, rodando no k8s https://grafana.com/grafana/dashboards/11955-jvm-micrometer/
- management.metrics.tags.application - configuração para colocar o nome da app na métrica
- anotações necessárias no pod, para envio das métricas da app ao prometheus
```
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "4004"
  prometheus.io/scheme: http
  prometheus.io/path: "/actuator/prometheus"
``
