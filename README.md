# xand
Projeto de oficinas de integração 2

## Como usar
Baixar o pip env:

```bash
pip install pipenv
```

Baixar as dependências:

```bash
pipenv install
```

Para rodar:

```bash
python run.py
```

## Configurações

Criar arquivo .env com as seguintes configurações:
- KEY_GEMINI="" (Preencher com a key da API do seu Gemini)
- SPOTIFY_CLIENT_ID
- SPOTIFY_CLIENT_SECRET

## Requisições

Em formato de texto para o Gemini:

```bash
curl -X POST http://localhost:5000/gemini/text -H "Content-Type: application/json" -d '{"text": "Faça uma solicitação aqui"}'
```