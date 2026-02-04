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
