# OficinaConectada Data Platform Infra

Repositorio dedicado ao provisionamento da camada de dados e mensageria da `OficinaConectada`.

## Escopo

- RDS PostgreSQL da aplicacao principal
- RDS PostgreSQL do `os-service`
- RDS PostgreSQL do `billing-service`
- DocumentDB para `execution-service` e auditoria do `billing-service`
- MSK para eventos de Saga e integracao
- Outputs para consumo por `platform-runtime`, `app-deployments` e pipelines

## Dependencias de infraestrutura

Este repositorio reutiliza a VPC criada em `oficinaconectada-foundation` para manter bancos e mensageria em rede privada.

## Autenticacao do pipeline

- `AWS_GITHUB_ACTIONS_ROLE_ARN` como GitHub Variable
- GitHub OIDC para assumir role na AWS

## Segredos no AWS Secrets Manager

Os valores sensiveis de infraestrutura deste repositorio devem existir em:

- `oficinaconectada/prod/infra/data-platform`

## Modelo de ambientes

- `local`: desenvolvimento fora da AWS, sem participacao desta esteira Terraform
- `prod`: unico ambiente provisionado por estes workflows

## Observacao de seguranca

Os valores sensiveis nao devem ser versionados em `terraform.tfvars` ou arquivos de estado locais. O pipeline foi preparado para consumir tudo a partir do AWS Secrets Manager.

## Execucao local

```bash
cd terraform
terraform init
terraform validate
terraform plan
```
