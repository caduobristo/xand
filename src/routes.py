from flask import Blueprint, request
import json
from flask import Response
import subprocess

from openai import OpenAI
from dotenv import load_dotenv
import os
import google.generativeai as genai

import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
import time

# Carrega do .env
load_dotenv()
gemini_api_key = os.getenv("KEY_GEMINI")
spotify_client_id = os.getenv("SPOTIFY_CLIENT_ID")
spotify_client_secret = os.getenv("SPOTIFY_CLIENT_SECRET")

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
        return {'erro': 'Text não fornecido'}, 400
    

    genai.configure(api_key=gemini_api_key)
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


    genai.configure(api_key=gemini_api_key)
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

@main.get('/spotify/music')
def search_music():
    data = request.get_json()
    music = data.get('music') if data else None

    if not music:
        # Tenta pegar como form-data se não for JSON
        music = request.form.get('music')
    # Caso não tenha o campo text na requisição
    if not music: 
        return {'erro': 'Music não fornecido'}, 400
    
    auth_manager = SpotifyClientCredentials(client_id=spotify_client_id, client_secret=spotify_client_secret)
    sp = spotipy.Spotify(auth_manager=auth_manager)

    try:
        result = sp.search(q=music, type='track', limit=1)

        if result['tracks']['items']:
            track = result['tracks']['items'][0]
            name = track['name']
            artist = track['artists'][0]['name']
            track_id = track['id']
            duration_ms = track['duration_ms']
            spotify_uri = f"spotify:track:{track_id}"

            print(f"Tocando: {name} - {artist}")
            print(f"Duração: {duration_ms / 1000:.2f} s")

            subprocess.Popen(['spotify', f'--uri={spotify_uri}'])

            # Espera a duração da música + o tempo de abrir o spotify
            time.sleep(2 + duration_ms / 1000)

            #os.system("taskkill /f /im Spotify.exe")
        else:
            print("Nenhuma música encontrada")
    except Exception as e:
        return Response(
            json.dumps({'erro': f'Erro ao processar música: {str(e)}'}, 500, ensure_ascii=False),
            content_type='application/json; charset=utf-8'
        )