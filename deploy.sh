#!/bin/bash

# Script para automatizar o build, push e deploy de uma aplicação no Google Cloud Run.
#
# INSTRUÇÕES:
# 1. Altere as variáveis na seção de configuração com os seus dados.
# 2. Dê permissão de execução ao script: chmod +x deploy.sh
# 3. Execute o script: ./deploy.sh

# Saia imediatamente se um comando falhar.
set -e

# --- CONFIGURAÇÃO ---
# Altere estas variáveis para corresponder ao seu ambiente do Google Cloud.
# O script usará variáveis de ambiente se estiverem definidas (ideal para CI/CD),
# caso contrário, usará os valores padrão abaixo.
PROJECT_ID=${PROJECT_ID:-"your-project-id"} # Exemplo: "my-gcp-project"
REGION=${REGION:-"your-region"} # Exemplo: "us-central1"
REPOSITORY_NAME=${REPOSITORY_NAME:-"your-repository-name"} # Exemplo: "my-docker-repo"
IMAGE_NAME=${IMAGE_NAME:-"your-image-name"} # Exemplo: "my-api-image"

# --- VARIÁVEIS DINÂMICAS ---
# Usa o hash curto do commit do Git como tag da imagem para um versionamento preciso.
IMAGE_TAG=$(git rev-parse --short HEAD)
IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "----------------------------------------------------"
echo "Iniciando processo de deploy..."
echo "PROJECT_ID: ${PROJECT_ID}"
echo "REGION: ${REGION}"
echo "IMAGE_URL: ${IMAGE_URL}"
echo "----------------------------------------------------"

# --- PRÉ-REQUISITOS ---
echo "Passo 0: Verificando e ativando APIs necessárias..."
gcloud services enable artifactregistry.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com

echo "APIs ativadas."

echo "Verificando se o repositório do Artifact Registry existe..."
# Verifica se o repositório já existe para evitar erros.
if ! gcloud artifacts repositories describe ${REPOSITORY_NAME} --location=${REGION} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo "Repositório '${REPOSITORY_NAME}' não encontrado. Criando..."
  gcloud artifacts repositories create "${REPOSITORY_NAME}" \
    --repository-format=docker \
    --location="${REGION}" \
    --description="Repositório para imagens da API" \
    --project="${PROJECT_ID}"
  echo "Repositório criado com sucesso."
else
  echo "Repositório '${REPOSITORY_NAME}' já existe."
fi
echo "----------------------------------------------------"

# 1 e 2. Construir e enviar a imagem usando o Google Cloud Build
echo "Passo 1 e 2: Construindo e enviando a imagem com o Cloud Build..."
gcloud builds submit . --tag "${IMAGE_URL}" --project="${PROJECT_ID}"
echo "Build e push concluídos."

# 3. Fazer o deploy da imagem no Cloud Run
echo "Passo 3: Fazendo o deploy no Cloud Run..."
gcloud run deploy "${IMAGE_NAME}" \
  --image "${IMAGE_URL}" \
  --region "${REGION}" \
  --platform "managed" \
  --allow-unauthenticated \
  --quiet # Evita prompts interativos, essencial para CI/CD

echo "----------------------------------------------------"
echo "Deploy no Cloud Run concluído com sucesso!"
echo "----------------------------------------------------"