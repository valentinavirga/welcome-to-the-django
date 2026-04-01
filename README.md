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
- **OIDC (consigliato)**: `AWS_ROLE_TO_ASSUME`
- **Oppure** access key: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- (Opzionale) `CF_STACK_NAME`
- (Opzionale) `CF_BUCKET_NAME`
