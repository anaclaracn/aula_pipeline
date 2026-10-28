# Pipeline DevSecOps com GitHub Actions

Aplicação Python de exemplo com um pipeline de CI/CD que integra verificações de
segurança (*shift-left security*) antes da publicação da imagem Docker.

## Ferramentas e verificação

| Ferramenta | Tipo | O que faz | Bloqueia o pipeline? |
|---|---|---|---|
| **Gitleaks** | Detecção de segredos | Varre o histórico do repositório em busca de senhas, tokens e chaves | Sim — qualquer segredo encontrado |
| **SonarCloud** | SAST (análise estática) | Análise de qualidade e segurança do código novo via Quality Gate | Sim — se o Quality Gate reprovar |
| **Trivy** (fs) | Análise de dependências | Varre as dependências do projeto (requirements.txt) | Sim — CRITICAL/HIGH com correção |
| **Trivy** (imagem) | Análise de imagem | Varre a imagem Docker construída | Sim — CRITICAL/HIGH com correção |
| **Trivy** (relatório) | Análise de imagem | Registra LOW/MEDIUM em relatório | Não — apenas relatório |
| **Syft** | SBOM | Gera o *Software Bill of Materials* da imagem | Não — gera artifact |

## Regras de bloqueio

| Severidade | Ação |
|---|---|
| CRITICAL | **Bloqueia** o merge (quando há correção disponível) |
| HIGH | **Bloqueia** o merge (quando há correção disponível) |
| MEDIUM | Registrada em relatório, **não bloqueia** |
| LOW | Registrada em relatório, **não bloqueia** |

A flag `ignore-unfixed: true` garante que somente vulnerabilidades **com correção
disponível** bloqueiem o pipeline, conforme o requisito 3.

## Estrutura do pipeline

```
push / pull_request / manual
        │
        ├── gitleaks ──────────────► detecta segredos (bloqueante)
        │
        ├── build-test ────────────► build + pytest (etapas existentes)
        │       │
        │       ├── sonarcloud ────► SAST + Quality Gate (bloqueante)
        │       │
        │       └── security-scan ► Trivy fs + imagem + SBOM (bloqueante/report)
        │
        └── publish ───────────────► push da imagem (só em main, depende de todos)
```

A publicação da imagem (`publish`) só executa após o sucesso de `gitleaks`,
`build-test`, `sonarcloud` e `security-scan`, e somente no push para `main`.

## Estrutura do repositório

```
.
├── .github/workflows/ci.yml   # pipeline DevSecOps
├── Dockerfile                  # imagem da aplicação
├── requirements.txt            # dependências (baseline seguro: urllib3 2.8.0)
├── .dockerignore
├── main.py                     # aplicação
└── test_main.py                # testes
```

## Pré-requisitos e configuração

### 1. SonarCloud (obrigatório)

1. Crie uma conta em [sonarcloud.io](https://sonarcloud.io) e faça login com o GitHub.
2. Crie uma **organização** e importe o repositório `anaclaracn/aula_pipeline`.
3. Gere um token em *My Account → Security → Generate Tokens*.
4. No repositório GitHub, acesse **Settings → Secrets and variables → Actions**:
   - Adicione o **secret** `SONAR_TOKEN` com o token gerado.
5. A organização e a chave do projeto já estão definidas em `sonar-project.properties`
   (não há variáveis a configurar).

> O job `sonarcloud` falha até que o token seja configurado.

### 2. GitHub Container Registry (publicação)

A publicação usa o `secrets.GITHUB_TOKEN` (já fornecido pelo GitHub) e a permissão
`packages: write`. Nenhuma configuração extra é necessária.

### 3. Proteção da branch `main` (recomendado)

Em **Settings → Branches → Add branch protection rule**, proteja a branch `main`
exigindo os checks: `gitleaks`, `build-test`, `sonarcloud` e `security-scan`.
> Obs.: os checks precisam ter rodado ao menos uma vez antes de aparecerem na lista.

## Demonstração — Requisito 5 (bloqueio e correção)

### Passo 1 — introduzir a vulnerabilidade

```bash
git checkout -b demo/vulnerabilidade

# Troque a versão no requirements.txt:
#   urllib3==2.8.0  ->  urllib3==2.2.3   (6 CVEs HIGH: CVE-2025-66418, CVE-2026-21441, ...)

git add requirements.txt
git commit -m "demo: introduz dependência vulnerável (urllib3 2.2.3)"
git push -u origin demo/vulnerabilidade
```

Abra um Pull Request. O pipeline **falha** no job `security-scan`, no passo
*Trivy — scan de dependências (bloqueante)*, apontando os CVEs HIGH do urllib3 2.2.3.
O merge fica **bloqueado**.

### Passo 2 — corrigir a dependência

```bash
# Volte a versão no requirements.txt:
#   urllib3==2.2.3  ->  urllib3==2.8.0

git add requirements.txt
git commit -m "fix: atualiza urllib3 para versão corrigida"
git push
```

O pipeline **passa** e o Pull Request pode ser mesclado. A imagem vulnerável nunca
é publicada, pois o `publish` só roda no push para `main` após todas as verificações.

> **Importante:** não use credenciais reais nos testes de Gitleaks. Para testar a
> detecção de segredos, use um valor fictício (ex.: `AWS_ACCESS_KEY_ID=AKIAEXAMPLE`
> — uma string falsa que o Gitleaks reconhece como formato de segredo).

## SBOM

O job `security-scan` publica o arquivo `sbom.spdx.json` (formato SPDX) como
artifact da execução. Para baixar: **Actions → execução → Artifacts → sbom**.

## Entregáveis

As evidências (capturas de tela e SBOM) estão na pasta [`evidencias/`](evidencias/).

- [x] Repositório GitHub com código-fonte e workflow YAML (`ci.yml`)
- [x] Evidência de execução do pipeline (`evidencias/pipe_verde.png`, `evidencias/pipe_success.png`)
- [x] Captura do PR bloqueado + trecho do relatório da vulnerabilidade (`evidencias/erro_vulnerabilidade_pr.png`, `evidencias/erro_pipe_pr_vulnerabilidade.png`)
- [x] Captura da execução aprovada após a correção (`evidencias/success_pipe_pr.png`)
- [x] SBOM publicado como artifact (`evidencias/sbom.spdx.json`)
- [x] Este README com ferramentas, verificações e regras de bloqueio
