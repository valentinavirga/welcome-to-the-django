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

## Nuovi parametri infrastrutturali

Per creare anche `EC2` e `PostgreSQL`, aggiorna i file in `infra/parameters/*.json` con valori reali per:

- `VpcId`
- `Ec2SubnetId` (subnet pubblica per la VM)
- `DbSubnetIds` (almeno 2 subnet private per RDS, separate da virgola)
- `KeyPairName` (opzionale, per accesso SSH)
- `SshCidr` (meglio restringerlo al proprio IP)

Il template ora crea:

- bucket `S3`
- istanza `EC2` Amazon Linux 2023
- database `RDS PostgreSQL`
- secret automatico in `Secrets Manager` per le credenziali DB
