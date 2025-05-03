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

    response_model = model.generate_content(text)


    resposta = {'text': f'{response_model.text}'}
    return Response(
        json.dumps(resposta, ensure_ascii=False),
        content_type='application/json; charset=utf-8'
    )