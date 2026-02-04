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
docker volume create fastembed-cache
```

---

## 🧊 Model Cache (FastEmbed Reality Check)

### ⚠️ ROOT CAUSE: FastEmbed Cache Location

FastEmbed does **NOT** use `$HF_HOME` or `~/.cache/huggingface`.

The **actual** cache location is:

```
/tmp/fastembed_cache
```

Full path example:

```
/tmp/fastembed_cache/models--nomic-ai--nomic-embed-text-v1.5/
```

### 🔥 Why Does the Model Keep Re-downloading?

Because `/tmp` in Docker is **ephemeral (temporary storage)**:

* Every container start → `/tmp` is wiped clean
* FastEmbed doesn't find the cached model → re-downloads everything
* Mounting volume to wrong path (e.g., `/root/.cache`) → doesn't help at all

This explains why the model downloads repeatedly, consuming bandwidth and time unnecessarily.

---

## ✅ SOLUTION: Mount to `/tmp/fastembed_cache`

To prevent model re-downloads on every container start:

**Step 1:** Create a persistent volume:

```bash
docker volume create fastembed-cache
```

**Step 2:** Mount to the **correct** path:

```bash
-v fastembed-cache:/tmp/fastembed_cache
```

This ensures FastEmbed finds the cached model on subsequent starts.

---

## 📊 Cache Location Reference

| Backend/Tool      | Cache Location               | Notes                           |
| ----------------- | ---------------------------- | ------------------------------- |
| **FastEmbed**     | **`/tmp/fastembed_cache`**   | **ACTUAL location (confirmed)** |
| HuggingFace SDK   | `$HF_HOME` or `~/.cache/hf`  | Not used by fastembed           |
| Old FastEmbed     | `~/.cache/fastembed`         | Legacy path, deprecated         |

---

## 🪟 Multiple VS Code Windows → Multiple Containers?

If you use `docker run --rm` in `mcp.json`, **each VS Code window spawns a separate container instance**.

### Solution (Optional, Advanced)

Use a **named container** (without `--rm`) to maintain **one global shared instance** across all VS Code windows:

```json
"args": [
  "run","-i",
  "--name","mcp-qdrant-mcp",
  "--restart","unless-stopped",

  "-v","fastembed-cache:/tmp/fastembed_cache",

  "--network","host",
  "-e","QDRANT_URL=http://localhost:6333",
  "-e","COLLECTION_NAME=copilot-codebase",
  "-e","EMBEDDING_MODEL=nomic-ai/nomic-embed-text-v1.5",

  "-e","TOOL_STORE_DESCRIPTION=Store reusable code snippets. Put code in metadata.code",
  "-e","TOOL_FIND_DESCRIPTION=Search for relevant code snippets before generating new code",

  "mcp-qdrant"
]
```

**Benefits:**
- Shared cache across all VS Code windows
- Container persists between sessions
- Faster startup (no container recreation)

> If the container already exists and you need to recreate it:

```bash
docker rm -f mcp-qdrant-mcp
```

---

## ⚠️ Important: MCP Argument Parsing

Each Docker flag **must be a separate array element** in JSON:

❌ **Wrong** (single string):

```json
"-v fastembed-cache:/tmp/fastembed_cache"
```

✅ **Correct** (separate elements):

```json
"-v","fastembed-cache:/tmp/fastembed_cache"
```

This is a common mistake that causes MCP to fail silently.

---

## 🧪 Verify Cache Persistence

After the container is running, verify the cache is properly mounted:

```bash
docker exec -it <container-name> ls -lah /tmp/fastembed_cache
```

You should see the model directory:

```
models--nomic-ai--nomic-embed-text-v1.5/
```

Alternative: Inspect the volume directly:

```bash
docker volume inspect fastembed-cache
```

**Success indicator:** Restart the container → **no more** "Fetching 5 files" or "Downloading model" messages.

---

## 📌 Root Cause Summary

| Issue                      | Explanation                                  |
| -------------------------- | -------------------------------------------- |
| FastEmbed cache location   | `/tmp/fastembed_cache` (NOT `$HF_HOME`)      |
| Docker `/tmp` behavior     | Ephemeral storage, wiped on every restart    |
| Wrong volume mount         | Mounting to `/root/.cache` has no effect     |
| Solution                   | Mount persistent volume to `/tmp/fastembed_cache` |

**Key Takeaway**: FastEmbed uses `/tmp/fastembed_cache`, **not** HuggingFace's cache directory. This is the critical detail often missed in documentation.

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

        "-v","fastembed-cache:/tmp/fastembed_cache",

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

## 🎉 Expected Results

Once configured, GitHub Copilot can:

✅ **Remember your entire codebase** semantically  
✅ **Understand project architecture** and patterns  
✅ **Reuse existing code** instead of generating new variants  
✅ **Reduce hallucinations** by referencing actual code  
✅ **Provide contextually relevant suggestions** based on your codebase

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
  "-v","fastembed-cache:/tmp/fastembed_cache",
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

### Tools Not Appearing in Copilot

**Symptoms:** `qdrant-find` and `qdrant-store` tools don't show up in Copilot Chat.

**Solutions:**
1. Close **all** VS Code windows completely (not just tabs)
2. Reopen VS Code
3. Open Copilot Chat → Click ⚙️ (gear icon) → **Tools**
4. Verify the tools are listed

If still not working:
- Check `mcp.json` syntax (valid JSON)
- Ensure the `mcp-qdrant` Docker image exists: `docker images | grep mcp-qdrant`
- Check Docker is running: `docker ps`

---

### Container Keeps Re-downloading Models

**Symptoms:** Every time you restart VS Code, the container downloads the embedding model again.

**Cause:** Volume not mounted to correct path.

**Solution:** Ensure `mcp.json` contains:
```json
"-v","fastembed-cache:/tmp/fastembed_cache"
```

**NOT** `~/.cache/huggingface` or any other path.

---

### Linux Networking Issues

**Symptom:** Container can't connect to Qdrant on `host.docker.internal:6333`.

**Cause:** `host.docker.internal` is Docker Desktop-specific (Mac/Windows).

**Solution for Linux:** Replace `host.docker.internal` with `localhost` or `172.17.0.1`:

```json
"-e","QDRANT_URL=http://localhost:6333"
```

Or use Docker's host network mode (already configured in examples).

---

### Slow First Run

**Expected behavior:** The first container start downloads the embedding model (~200MB for `nomic-embed-text-v1.5`).

**Timeline:**
- First run: 2-5 minutes (downloading)
- Subsequent runs: <10 seconds (cached)

If it's slow **every time**, see "Container Keeps Re-downloading Models" above.

---

### MCP Connection Errors

**Symptoms:** Errors in VS Code Output panel mentioning MCP connection failures.

**Check:**
1. Docker container is running: `docker ps`
2. Qdrant is accessible: `curl http://localhost:6333/collections`
3. Check Docker logs: `docker logs <container-name>`
4. Verify `mcp.json` argument formatting (each flag as separate array element)

---

### Permission Denied or Volume Errors

**Symptom:** `Error: permission denied` when mounting volumes.

**Solution:**
- Ensure volume exists: `docker volume ls | grep fastembed-cache`
- Recreate volume: `docker volume rm fastembed-cache && docker volume create fastembed-cache`
- Check Docker has necessary permissions on your system

---

## 📎 References

- Qdrant MCP Server: https://github.com/qdrant/mcp-server-qdrant
- Model Context Protocol: https://modelcontextprotocol.io
- Qdrant: https://qdrant.tech

---