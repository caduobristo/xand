from openai import OpenAI
from dotenv import load_dotenv
import os

# Carrega do .env
load_dotenv()
api_key = os.getenv("KEY_GEMINI")

# Faz a requisição para o Chat
import google.generativeai as genai

# Configure sua chave da API do Google
genai.configure(api_key=api_key)

# Inicializa o modelo com suporte a áudio
model = genai.GenerativeModel(model_name="models/gemini-1.5-pro-latest")

# Envia o áudio diretamente (sem importar AudioPart)
response = model.generate_content(
    [
        "O que está sendo falado nesse áudio?",
        {
            "mime_type": "audio/ogg",
            "data": open("sound.ogg", "rb").read()
        }
    ]
)

print(response.text)
