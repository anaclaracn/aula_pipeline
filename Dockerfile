# Imagem base leve do Python
FROM python:3.12-slim

# Diretório de trabalho
WORKDIR /app

# Atualiza pacotes do SO para reduzir vulnerabilidades da imagem base
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Instala dependências antes de copiar o código (aproveita o cache do Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia o restante da aplicação
COPY . .

# Executa como usuário não-root (evita a descoberta de segurança "runs as root")
USER nobody

# Executa a aplicação
CMD ["python", "main.py"]
