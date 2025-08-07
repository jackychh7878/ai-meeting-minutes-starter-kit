# AiMeetingMinutes

## Introduction

<!-- TODO: Add a detailed project introduction here -->

This project combines an AI-powered meeting backend with a self-hosted n8n automation and AI workflow stack, including vector database, MinIO, and Ollama for local LLMs.
![design_architecture.png](design_architecture.png)
## Prerequisites
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/)

## Getting Started

1. **Clone the repository:**
   ```sh
   git clone https://github.com/jackychh7878/ai-meeting-minutes-starter-kit.git
   cd ai-meeting-minutes-starter-kit
   ```

2. **Configure environment variables:**
   - Copy or create a `.env` file in the project root and fill in the required values.

3. **Start all services (default: CPU profile):**
   ```sh
   docker compose --profile cpu up
   ```
   - For Nvidia GPU:
     ```sh
     docker compose --profile gpu-nvidia up
     ```
   - For AMD GPU:
     ```sh
     docker compose --profile gpu-amd up
     ```
   - For Closing all services
     ```sh
     docker compose down -v
     ```

4. **Access the services:**
   - Backend API: [http://localhost:8000](http://localhost:8000)
   - n8n Automation: [http://localhost:5678](http://localhost:5678)
   - MinIO Console: [http://localhost:9001](http://localhost:9001)
   - Qdrant: [http://localhost:6333](http://localhost:6333)

5. ** Troubleshooting **
    ### Check Service Status
    ```bash
    docker-compose ps
    ```
    
    ### View Logs
    ```bash
    docker-compose logs -f [service-name]
    ```

## Environment Variables and Container Recreation

When you update your `.env` file, Docker containers may not automatically pick up the new environment variables due to caching. To force containers to use the updated environment variables:

```sh
# Stop and remove existing containers
docker-compose down

# Remove any cached images (optional but recommended)
docker-compose pull

# Start services with fresh containers
docker-compose up -d --force-recreate
```

**Why this is necessary:**
- Docker containers cache environment variables at build time
- Simply updating the `.env` file doesn't automatically update running containers
- The `--force-recreate` flag ensures containers are rebuilt with the latest environment variables

### Reset Everything
```bash
docker-compose down -v
docker-compose up -d
```

## n8n Credential Export

To export n8n credentials as individual JSON files for backup or migration:

### Export all credentials:
```sh
docker exec -it n8n n8n export:credentials --backup --output=/home/node/.n8n/exports/
```

### Export specific credential by ID:
```sh
docker exec -it n8n n8n export:credentials --id=<CREDENTIAL_ID> --output=/home/node/.n8n/exports/
```

### Export all credentials to a single file:
```sh
docker exec -it n8n n8n export:credentials --all --output=/home/node/.n8n/exports/all-credentials.json
```

**Note:** The exported files will be available in the `n8n/exports/` directory on your host machine due to the volume mount configuration.

## Folder Structure
- `src/` - Backend source code
- `n8n/` - n8n demo-data and shared folders
- `n8n/exports/` - Exported n8n credentials and workflows
- `docker-compose.yaml` - Main compose file for all services

## Notes
- n8n and the backend share the same Postgres database for simplicity.
- Ollama supports CPU, Nvidia GPU, and AMD GPU profiles. Select the appropriate profile for your hardware.
- Demo workflows and credentials for n8n are included in `n8n/demo-data`.
- Environment variables are loaded from the `.env` file in the project root.

## Running Ollama Pull Commands After docker-compose up

After starting your services with `docker-compose up`, you may want to pull additional models into your running Ollama container. Here are two ways to do this:

### 1. Run a One-Off Pull Command

You can execute a pull command directly inside the running Ollama container (named `ollama`) using:

```sh
docker exec ollama ollama pull qwen3:0.6b
```

Replace `qwen3:0.6b` with the model you wish to pull.

### 2. Open an Interactive Shell in the Container

If you want to run multiple commands or work interactively:

```sh
docker exec -it ollama /bin/sh
```

Then, inside the shell, type:

```sh
ollama pull qwen3:0.6b
```

This allows you to run any other commands as needed inside the container.

---

Use the first method for single commands, and the second for interactive work.

## Internal Docker Service DNS Table

| Service Name                | Internal Hostname                  | Internal Port |
|-----------------------------|------------------------------------|---------------|
| ai_meeting_backend          | ai_meeting_backend                 | 8000          |
| pgvector                    | pgvector                           | 5432          |
| minio                       | minio                              | 9000          |
| postgres                    | postgres                           | 5432          |
| n8n                         | n8n                                | 5678          |
| qdrant                      | qdrant                             | 6333          |
| ollama-cpu                  | ollama-cpu                         | 11434         |
| ollama-gpu                  | ollama-gpu                         | 11434         |
| ollama-gpu-amd              | ollama-gpu-amd                     | 11434         |
| ai_meeting_chatbot_frontend | ai_meeting_chatbot_frontend        | 3000          |

**Usage:**
- Use the `Internal Hostname` and `Internal Port` to connect between services inside Docker Compose (e.g., `http://ai_meeting_backend:8000`).
- These hostnames are only accessible to other containers on the same Docker network.

## On-Premises Deployment Checklist

### Step 1: Update .env File
- [ ] Set `ON_PREMISES_MODE` to `on_premises`
- [ ] Set `NGROK_PUBLIC_MODE` to `private`
- [ ] Update `TFLOW_HOST` to your on-premises host
- [ ] Configure MinIO settings:
  - [ ] Set `MINIO_ENDPOINT` to your MinIO server address (e.g., `localhost:9000` or `your-server-ip:9000`)
  - [ ] Set `MINIO_ACCESS_KEY` and `MINIO_SECRET_KEY` to your MinIO credentials
  - [ ] Set `MINIO_SECURE` to `true` for HTTPS or `false` for HTTP

### Step 2: Update n8n Workflows
- [ ] Update all `[T-flow]` nodes with the new T-flow host URL, app ID, and sign ID in both the Ai Meeting Minutes flow and Chatbot flow
- [ ] Ensure Ollama is connected successfully with the local n8n flow
- [ ] Check that the webhook is running successfully

### Step 3: Update T-flow
- [ ] Update the workflow backend host URL
- [ ] Update the app ID and sign ID as API parameters
- [ ] Update the chatbot `webhook_id`
- [ ] Update the tutorial video