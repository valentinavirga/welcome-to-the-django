variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "deploy_ssh_public_key" {
  description = "Contenuto della chiave pubblica SSH per l'utente deploy"
  type        = string
}