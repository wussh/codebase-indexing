# 🚀 Copilot Codebase Indexing with Qdrant + MCP (Docker)

Semantic memory for GitHub Copilot using **Qdrant Vector DB** and **Model Context Protocol (MCP)**.

---

## 📚 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start (STDIO)](#-quick-start-stdio)
- [Setup Steps](#-setup-steps)
- [Index & Search Examples](#-index--search-examples)
- [Models](#-models)
- [Result](#-result)
- [Docker Deployment Modes](#-docker-deployment-modes)
- [Troubleshooting](#-troubleshooting)
- [References](#-references)

---

## ✨ Overview

This repo provides a Docker-based setup for running **mcp-server-qdrant** so GitHub Copilot can store and retrieve semantic memory from a Qdrant vector database.

---

## 🧠 Architecture

```
VS Code (Copilot Chat)
        │  (MCP tools via stdio)
        ▼
Docker: mcp-qdrant
        │
        ▼
Qdrant (vector database)
```

---

## 📦 Prerequisites

- Docker Desktop / Rancher / Podman
- VS Code + GitHub Copilot
- Internet access (first-time model download)

---

## ⚡ Quick Start (STDIO)

1. Run Qdrant.
2. Build the MCP image.
3. Create the model cache volume.
4. Configure MCP in VS Code.
5. Restart VS Code and verify tools.

---

## 🛠️ Setup Steps

### 1. Run Qdrant

```bash
docker run -d --name qdrant \
  -p 6333:6333 -p 6334:6334 \
  qdrant/qdrant
```

Check:

```bash
curl http://localhost:6333/collections
```

---

### 2. Build the MCP Qdrant Image

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip \
 && pip install fastembed mcp-server-qdrant

CMD ["mcp-server-qdrant"]
```

Build:

```bash
docker build -t mcp-qdrant .
```

---

### 3. Create Model Cache Volume

```bash
docker volume create hf-cache
```

---

### 4. (Optional) HuggingFace Token

Create a token: https://huggingface.co/settings/tokens
Role: **Read**

---

### 5. Configure VS Code MCP

### `mcp.json` Location

| OS      | Location                                           |
| ------- | -------------------------------------------------- |
| Windows | `C:\Users\USER\AppData\Roaming\Code\User\mcp.json` |
| Linux   | `~/.config/Code/User/mcp.json`                     |

---

### `mcp.json` Content

```json
{
  "servers": {
    "qdrant": {
      "command": "docker",
      "args": [
        "run","--rm","-i",

        "-v","hf-cache:/root/.cache/huggingface",

        "--network","host",
        "-e","QDRANT_URL=http://host.docker.internal:6333",
        "-e","COLLECTION_NAME=copilot-codebase",
        "-e","EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5",

        "-e","TOOL_STORE_DESCRIPTION=Store reusable code snippets. Put code in metadata.code",
        "-e","TOOL_FIND_DESCRIPTION=Search for relevant code snippets before generating new code",

        "-e","HF_TOKEN=hf_xxxxxxxxxxxxxxxxx",

        "mcp-qdrant"
      ]
    }
  }
}
```

> On Linux, replace `host.docker.internal` with `localhost`.

---

### 6. Restart VS Code

1. Close all VS Code windows.
2. Reopen VS Code.
3. Copilot Chat → ⚙ → **Tools**

You should see:

* `qdrant-find`
* `qdrant-store`

---

## 🔎 Index & Search Examples

### 1. Index the Codebase

In Copilot Chat:

```text
Use qdrant-store to index all source and config files in this workspace.
Store each file with its relative path and content as metadata.
```

---

### 2. Semantic Search Examples

```text
With qdrant-find, explain how authentication works.
```

```text
Use qdrant-find to locate database connection logic.
```

---

### 3. Encourage Copilot to Reuse Code

Add this to **Copilot Custom Instructions**:

```text
Always call qdrant-find before generating or modifying code.
Reuse existing patterns from the retrieved snippets.
```

---

## 🧪 Models

| Component | Model                            |
| --------- | -------------------------------- |
| Embedding | `nomic-ai/nomic-embed-text-v1.5` |
| Dimension | 768                              |
| Provider  | fastembed (ONNX, CPU)            |

---

## 🎉 Result

Copilot can now:

- Remember the entire codebase
- Understand architecture
- Reuse code
- Reduce hallucinations


The two Dockerfiles are **not duplicates**. They represent **two different deployment modes**.

---

# 🐳 Docker Deployment Modes

## 1) **SSE / HTTP Server Mode (Remote, Team, Cursor)**

Use this when you need network access via `/sse`.
Ideal for Cursor, Windsurf, Claude, and other web tools.

```dockerfile
# Dockerfile.sse
FROM python:3.11-slim

WORKDIR /app

# Install uv for package management
RUN pip install --no-cache-dir uv

# Install the mcp-server-qdrant package
RUN uv pip install --system --no-cache-dir mcp-server-qdrant

# Expose the default port for SSE transport
EXPOSE 8000

# Default env (override at runtime)
ENV QDRANT_URL=""
ENV QDRANT_API_KEY=""
ENV COLLECTION_NAME="default-collection"
ENV EMBEDDING_MODEL="sentence-transformers/all-MiniLM-L6-v2"

# Run server with SSE transport
CMD ["uvx","mcp-server-qdrant","--transport","sse"]
```

### Build & Run

```bash
docker build -f Dockerfile.sse -t mcp-qdrant-sse .

docker run -p 8000:8000 \
  -e FASTMCP_HOST="0.0.0.0" \
  -e QDRANT_URL="http://localhost:6333" \
  -e COLLECTION_NAME="code-snippets" \
  mcp-qdrant-sse
```

Endpoint:

```
http://localhost:8000/sse
```

---

## 2) **STDIO Mode (Local Copilot, VS Code MCP)**

Use this for **Copilot Chat** (stdio, no exposed ports).

```dockerfile
# Dockerfile.stdio
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    curl \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip \
 && pip install fastembed mcp-server-qdrant

CMD ["mcp-server-qdrant"]
```

### Build

```bash
docker build -f Dockerfile.stdio -t mcp-qdrant .
```

Called via `mcp.json`:

```json
"command": "docker",
"args": [
  "run","--rm","-i",
  "-v","hf-cache:/root/.cache/huggingface",
  "--network","host",
  "-e","QDRANT_URL=http://host.docker.internal:6333",
  "-e","COLLECTION_NAME=copilot-codebase",
  "-e","EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5",
  "mcp-qdrant"
]
```

---

## 🎯 Summary

| Mode      | Transport    | Access  | Client                   |
| --------- | ------------ | ------- | ------------------------ |
| **SSE**   | HTTP `/sse`  | Network | Cursor, Windsurf, Claude |
| **STDIO** | stdin/stdout | Local   | VS Code Copilot          |

---

## 🧩 Troubleshooting

- **Tools not showing up**: Restart VS Code and check Copilot Chat → ⚙ → **Tools**.
- **Linux networking issues**: Replace `host.docker.internal` with `localhost`.
- **Slow first run**: The embedding model downloads on first use; allow extra time.

---

## 📎 References

- Qdrant MCP Server: https://github.com/qdrant/mcp-server-qdrant
- Model Context Protocol: https://modelcontextprotocol.io
- Qdrant: https://qdrant.tech

---