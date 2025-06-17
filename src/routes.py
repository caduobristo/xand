from flask import Blueprint, request
import json
from flask import Response
import subprocess
import time
import os

import speech_recognition as sr
from pydub import AudioSegment 

from openai import OpenAI 
from dotenv import load_dotenv
import io
import google.generativeai as genai


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
    data = request.get_json()
    text = data.get('text') if data else None

    if not text:
        text = request.form.get('text')
    if not text:
        return {'erro': 'Text não fornecido'}, 400
    
    genai.configure(api_key=gemini_api_key)
    model = genai.GenerativeModel(model_name="models/gemini-2.0-flash") # flash para texto

    try:
        response_model = model.generate_content(text)
    except Exception as e:
        return {'erro': f'Erro ao processar texto: {str(e)}'}, 500

    resposta = {'text': f'{response_model.text}'}
    return Response(
        json.dumps(resposta, ensure_ascii=False),
        content_type='application/json; charset=utf-8'
    )


@main.get('/spotify/music')
def search_music():
    data = request.get_json()
    music = data.get('music') if data else None

    if not music:
        music = request.form.get('music')
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

            time.sleep(2 + duration_ms / 1000)

        else:
            print("Nenhuma música encontrada")
    except Exception as e:
        return Response(
            json.dumps({'erro': f'Erro ao processar música: {str(e)}'}, 500, ensure_ascii=False),
            content_type='application/json; charset=utf-8'
        )


@main.post('/xand/ask')
def xand_ask():
    base_prompt = """
    Você é o XAND, um assistente virtual com personalidade carismática e divertida.
    Sua tarefa é interpretar a **intenção** do usuário a partir do **texto** e responder **EXATAMENTE** no formato tabelado abaixo.
    Não adicione texto extra, explicações ou cumprimentos. Apenas a resposta tabelada correspondente à intenção identificada.
    Se a intenção do usuário não se encaixar claramente em NENHUM dos contextos listados, responda com "NULL".
    O que estiver entre chaves duplas '{{ }}' é uma variável que você deve substituir.

    ---
    Contextos e Respostas Tabeladas:

    1. **Pedir Música:** Quando o usuário pede para tocar/cantar uma música específica.
       - Exemplos de entrada: "toque a música {nome da música} para mim", "cante {nome da música}", "quero ouvir {nome da música}".
       - Resposta: 'tocar música {{nome da música}}'

    2. **Pedir Instrumento:** Quando o usuário pede para tocar um instrumento (sem especificar uma música).
       - Exemplos de entrada: "toque o instrumento {nome do instrumento}", "consegue tocar um {nome do instrumento}?".
       - Resposta: 'tocar instrumento {{nome do instrumento}}'

    3. **Repetir Fala:** Quando o usuário pede para você repetir o que ele diz.
       - Exemplos de entrada: "repita o que eu digo", "consegue falar o que ouve?", "fale isso: {frase}".
       - Resposta: 'Sim!, estou te ouvindo, diga o que quer que eu fale!'

    4. **Perguntar Horário:** Quando o usuário pergunta sobre a hora atual do sistema.
       - Exemplos de entrada: "que horas são?", "me diga a hora", "qual o horário agora?".
       - Resposta: 'horario: {{hora_atual}}'

    5. **Perguntar Temperatura de Curitiba:** Quando o usuário pergunta sobre a temperatura especificamente de Curitiba.
       - Exemplos de entrada: "qual a temperatura de Curitiba?", "está quente em Curitiba?", "me diga a temperatura atual em Curitiba".
       - Resposta: 'temperatura: {{temperatura_curitiba_celsius}}'

    ---
    Agora, interprete o texto do usuário e forneça a resposta tabelada.
    Se a intenção for "Perguntar Horário", substitua `{{hora_atual}}` pela string literal `{{hora_atual}}`.
    If the intention is "Perguntar Temperatura de Curitiba", replace `{{temperatura_curitiba_celsius}}` with the literal string `{{temperatura_curitiba_celsius}}`.
    """

    audio_file = request.files.get('audio')
    if not audio_file:
        return {'erro': 'Arquivo de áudio não fornecido'}, 400

    audio_bytes = audio_file.read()

    transcribed_text = ""
    recognizer = sr.Recognizer()

    try:
        audio_in_memory = io.BytesIO(audio_bytes)
        audio = AudioSegment.from_file(audio_in_memory, format="ogg")

        # Exporta para WAV também em memória
        wav_in_memory = io.BytesIO()
        audio.export(
            wav_in_memory,
            format="wav",
            parameters=["-ar", "16000", "-ac", "1", "-sample_fmt", "s16"] 
        )
        wav_in_memory.seek(0)
        
        with sr.AudioFile(wav_in_memory) as source:
            audio_data = recognizer.record(source)
            transcribed_text = recognizer.recognize_google(audio_data, language="pt-BR")
            print(f"DEBUG: Texto transcrito pelo Google Speech Recognition: {transcribed_text}")
            
    except sr.UnknownValueError:
        transcribed_text = ""
        print("DEBUG: Google Speech Recognition não conseguiu entender o áudio")
    except sr.RequestError as e:
        print(f"DEBUG: Não foi possível solicitar resultados do Google Speech Recognition; {e}")
        return Response(
            json.dumps({'erro': f'Erro no serviço de transcrição (Google STT): {str(e)}'}, ensure_ascii=False),
            content_type='application/json; charset=utf-8',
            status=500
        )
    except Exception as e:
        print(f"DEBUG: Erro geral na transcrição: {e}")
        return Response(
            json.dumps({'erro': f'Erro inesperado na transcrição do áudio: {str(e)}'}, ensure_ascii=False),
            content_type='application/json; charset=utf-8',
            status=500
        )
    finally:
        pass


    if not transcribed_text.strip():
        resposta = {'text': "NULL"}
        return Response(
            json.dumps(resposta, ensure_ascii=False),
            content_type='application/json; charset=utf-8'
        )

    # 2. Enviar o texto transcrito para o Gemini Flash para interpretação
    genai.configure(api_key=gemini_api_key)
    model = genai.GenerativeModel(model_name="models/gemini-2.0-flash") # Usando Flash para o texto

    try:
        combined_prompt_for_gemini = f"{base_prompt}\n\nEntrada do usuário: \"{transcribed_text}\""

        response_model = model.generate_content(combined_prompt_for_gemini)
        
        gemini_response_text = response_model.text.strip()
        
        print(f"DEBUG: Texto bruto do Gemini (após SpeechRecognition): {gemini_response_text}") # Debug da resposta Gemini
        
        if "horario:" in gemini_response_text:
            current_time = time.strftime("%H:%M")
            gemini_response_text = gemini_response_text.replace("{{hora_atual}}", current_time)
        
        if "temperatura:" in gemini_response_text:
            temperatura_curitiba = "25" # Substituir por API
            gemini_response_text = gemini_response_text.replace("{{temperatura_curitiba_celsius}}", temperatura_curitiba)

        resposta = {'text': gemini_response_text}
        return Response(
            json.dumps(resposta, ensure_ascii=False),
            content_type='application/json; charset=utf-8'
        )
    except Exception as e:
        print(f"Erro ao processar texto transcrito no Gemini: {e}")
        return Response(
            json.dumps({'erro': f'Erro ao interpretar a fala (Gemini Flash): {str(e)}'}, ensure_ascii=False),
            content_type='application/json; charset=utf-8',
            status=500
        )