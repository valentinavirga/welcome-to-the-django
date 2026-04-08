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
- (Opzionale) `CF_DEPLOY_ROLE_ARN` (ARN del ruolo di execution CloudFormation)
- (Opzionale) `CF_STACK_NAME`

## Nuovi parametri infrastrutturali

Per creare solo `EC2`, aggiorna i file in `infra/parameters/*.json` con valori reali per:

- `VpcId`
- `Ec2SubnetId` (subnet pubblica per la VM)
- `KeyPairName` (opzionale, per accesso SSH)
- `SshCidr` (meglio restringerlo al proprio IP)

Il template ora crea:

- istanza `EC2` Amazon Linux 2023
