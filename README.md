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