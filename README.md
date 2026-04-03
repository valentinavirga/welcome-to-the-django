# welcome-to-the-django

## Struttura CloudFormation (GitOps)

```
infra/
	cloudformation/
		template.yml
	parameters/
		dev.json
		prod.json
.github/
	workflows/
		cloudformation.yml
```

## GitOps (GitHub Actions)

Il workflow si attiva su push in `main` quando cambiano i file in `infra/**`.

Configura i secrets nel repository:

- `AWS_REGION`
- **OIDC (consigliato)**: `AWS_ROLE_TO_ASSUME` (arn)
- **Oppure** access key: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- (Opzionale) `CF_STACK_NAME`
- (Opzionale) `CF_BUCKET_NAME`

## Bootstrap IAM da terminale (senza click)

Per creare solo i ruoli IAM iniziali via template CloudFormation:

1. Esporta variabili minime:
   - `AWS_REGION`
   - (Opzionale) `CF_STACK_NAME` (default: `welcome-to-the-django-prod`)
   - (Opzionale) `ENVIRONMENT_NAME` (default: `prod`)
   - (Opzionale) `GITHUB_REPOSITORY` (default: `valentinavirga/welcome-to-the-django`)
   - (Opzionale) `GITHUB_BRANCH` (default: `main`)

2. Esegui:

   `.github/scripts/bootstrap_iam_roles.sh`

Lo script fa deploy con `BootstrapOnly=true` e `CreateDatabase=false`, poi stampa i valori da salvare nei secrets GitHub:

- `AWS_ROLE_TO_ASSUME`
- `CF_DEPLOY_ROLE_ARN`

## Nuovi parametri infrastrutturali

Per creare anche `EC2` e `PostgreSQL`, aggiorna i file in `infra/parameters/*.json` con valori reali per:

- `VpcId`
- `Ec2SubnetId` (subnet pubblica per la VM)
- `DbSubnetIds` (almeno 2 subnet private per RDS, separate da virgola)
- `KeyPairName` (opzionale, per accesso SSH)
- `SshCidr` (meglio restringerlo al proprio IP)

Per deploy piu veloci durante test/iterazioni, puoi impostare:

- `CreateDatabase`: `"false"` (salta la creazione di `RDS`, riducendo molto i tempi)

Il template ora crea:

- bucket `S3`
- istanza `EC2` Amazon Linux 2023
- database `RDS PostgreSQL`
- secret automatico in `Secrets Manager` per le credenziali DB

Nota: l'istanza `RDS` usa una retention backup di `1` giorno per restare compatibile con account AWS Free Tier / piano gratuito.
