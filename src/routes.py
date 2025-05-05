from flask import Blueprint, request
import json
from flask import Response

from openai import OpenAI
from dotenv import load_dotenv
import os
import google.generativeai as genai

# Carrega do .env
load_dotenv()
api_key = os.getenv("KEY_GEMINI")

main = Blueprint('main', __name__)

@main.route('/')
def home():
    return "Teste!"

@main.post('/gemini/text')
def gemini_text():
    # Caso o texto venha como JSON
    data = request.get_json()
    text = data.get('text') if data else None

    if not text:
        # Tenta pegar como form-data se não for JSON
        text = request.form.get('text')
    # Caso não tenha o campo text na requisição
    if not text:
        return {'erro': 'Texto não fornecido'}, 400
    

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(model_name="models/gemini-2.0-flash")

    try:
        response_model = model.generate_content(text)
    except Exception as e:
        return {'erro': f'Erro ao processar texto: {str(e)}'}, 500


    resposta = {'text': f'{response_model.text}'}
    return Response(
        json.dumps(resposta, ensure_ascii=False),
        content_type='application/json; charset=utf-8'
    )

@main.post('/gemini/audio')
def gemini_audio():
    # Verifica se o arquivo de áudio foi enviado
    audio_file = request.files.get('audio')
    if not audio_file:
        return {'erro': 'Arquivo de áudio não fornecido'}, 400

    audio_bytes = audio_file.read()

    # (Opcional) Campo de texto complementar
    prompt = request.form.get('text', '')


    genai.configure(api_key=api_key)
    model = genai.GenerativeModel(model_name="models/gemini-1.5-pro")  # Modelos multimodais precisam suportar áudio

    try:
        response_model = model.generate_content([
            prompt,
            {
                'mime_type': "audio/ogg",
                'data': audio_bytes
            }
        ])
    except Exception as e:
        return Response(
            json.dumps({'erro': f'Erro ao processar o áudio: {str(e)}'}, 500, ensure_ascii=False),
            content_type='application/json; charset=utf-8'
        )

    resposta = {'text': response_model.text}
    return Response(
        json.dumps(resposta, ensure_ascii=False),
        content_type='application/json; charset=utf-8'
    )