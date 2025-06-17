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
curl -X POST http://localhost:5000/gemini/text \ 
    -H "Content-Type: application/json" \
    -d '{"text": "Faça uma solicitação aqui"}'
```

Em formato de áudio para o Gemini:
```bash
curl -X POST http://localhost:5000/gemini/audio \
  -F "audio=@caminho/para/seu_audio.mp3" \
  -F "text=Transcreva esse áudio e me diga o que foi falado."
```

Pedindo música para o Spotify:
```bash
curl -X GET http://localhost:5000/spotify/music -H "Content-Type: application/json" -d '{"music": "Escreva uma música"}'
```

PowerShell(ADM) - ffmpeg serve para manter o aúdio na memória:

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install ffmpeg
