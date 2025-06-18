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
openweathermap_api_key = os.getenv("OPENWEATHER_API_KEY")


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

def get_curitiba_temperature(api_key):
    lat = -25.4284
    lon = -49.2733 # Coordenadas de Curitiba
    url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={api_key}&units=metric"
    
    try:
        response = requests.get(url)
        response.raise_for_status() 
        data = response.json()
        temperature = data['main']['temp']
        return f"{temperature:.1f}" 
    except requests.exceptions.RequestException as e:
        print(f"Erro ao obter temperatura de Curitiba: {e}")
        return "N/A" 

@main.post('/xand/ask')
def xand_ask():
    base_prompt = """
    Você é o XAND, um assistente virtual com personalidade carismática e divertida.
    Sua tarefa é interpretar a **intenção principal** do usuário a partir do **texto** e responder **EXATAMENTE** no formato tabelado abaixo.
    **Ignore cumprimentos, saudações ou frases de cortesia** como "bom dia", "tudo bem", "por favor", "obrigado", "Xande", etc. Foque apenas nos comandos e palavras-chave.
    Não adicione texto extra, explicações ou cumprimentos. Apenas a resposta tabelada correspondente à intenção identificada.
    
    O que estiver entre chaves duplas '{{ }}' é uma variável que você deve retornar literalmente para substituição no sistema.

    ---
    Contextos e Respostas Tabeladas:

    1. **Pedir Música:** Quando o usuário pede para tocar/cantar uma música específica.
       - Exemplos de entrada: "toque a música {nome da música} para mim", "cante {nome da música}", "quero ouvir {nome da música}".
       - Resposta: 'tocar música {{nome da música}}'

    2. **Tocar Piano:** Quando o usuário pede explicitamente para tocar o instrumento piano.
       - Exemplos de entrada: "toque piano", "consegue tocar um piano?", "Xand, toque piano".
       - Resposta: 'tocar piano'

    3. **Tocar Guitarra:** Quando o usuário pede explicitamente para tocar o instrumento guitarra.
       - Exemplos de entrada: "toque guitarra", "consegue tocar uma guitarra?", "Xand, toque guitarra".
       - Resposta: 'tocar guitarra'
    
    4. **Repetir Fala:** Quando o usuário pede para você repetir o que ele diz.
       - Exemplos de entrada: "repita o que eu digo", "consegue falar o que ouve?", "fale isso: {frase}".
       - Resposta: 'Sim!, estou te ouvindo, diga o que quer que eu fale!'

    5. **Perguntar Horário:** Quando o usuário pergunta sobre a hora atual do sistema.
       - Exemplos de entrada: "que horas são?", "me diga a hora", "qual o horário agora?".
       - Resposta: 'horario: {{hora_atual}}'

    6. **Perguntar Temperatura de Curitiba:** Quando o usuário pergunta sobre a temperatura especificamente de Curitiba.
       - Exemplos de entrada: "qual a temperatura de Curitiba?", "está quente em Curitiba?", "me diga a temperatura atual em Curitiba".
       - Resposta: 'temperatura: {{temperatura_curitiba_celsius}}'
    
    7. **Brincar (Ação do Pet):** Quando o usuário pede para o XAND brincar.
       - Exemplos de entrada: "quero brincar", "Xand, vamos brincar?", "brinca comigo".
       - Resposta: 'brincar'

    8. **Comer (Ação do Pet):** Quando o usuário pede para o XAND comer.
       - Exemplos de entrada: "Xand, coma", "quero comer", "alimente o Xand".
       - Resposta: 'comer'

    9. **Dormir (Ação do Pet):** Quando o usuário pede para o XAND dormir/acordar.
       - Exemplos de entrada: "Xand, vá dormir", "hora de dormir", "Xand acorde".
       - Resposta: 'dormir'

    10. **Iniciar Minigame:** Quando o usuário pede para iniciar o minigame "Xand, o Voador".
        - Exemplos de entrada: "vamos jogar", "iniciar minigame", "quero jogar Xand o Voador", "minigame".
        - Resposta: 'jogar'
    
    11. **Perguntas Comuns/Interação Geral:** Quando o usuário faz uma pergunta que não se encaixa nas categorias acima, mas que esperaria uma resposta direta de um assistente virtual (ex: "faça essa conta", "quanto é 2 mais 2", "quem ganhou o jogo do Palmeiras ontem?", "qual a capital da França?").
        - Resposta: 'TEXTO: {{resposta_geral_do_gemini}}'
        (Neste caso, você deve gerar uma resposta concisa e direta para a pergunta do usuário. Deve ignorar as variáveis `{{}}` aqui e só usar o texto).

    ---
    Agora, interprete o texto do usuário: "##TEXTO_DO_USUARIO##" e forneça a resposta tabelada.
    Se a intenção for "Perguntar Horário", substitua `{{hora_atual}}` pela string literal `{{hora_atual}}`.
    Se a intenção for "Perguntar Temperatura de Curitiba", substitua `{{temperatura_curitiba_celsius}}` pela string literal `{{temperatura_curitiba_celsius}}`.
    Se a intenção for "Perguntas Comuns/Interação Geral", substitua `{{resposta_geral_do_gemini}}` pela sua resposta concisa e direta à pergunta do usuário (não inclua o "TEXTO: " aqui, apenas a resposta).
    Se nenhuma intenção clara for detectada nos pontos 1-11, responda com "NULL".
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
    
    if not transcribed_text.strip():
        resposta = {'text': "NULL"}
        return Response(
            json.dumps(resposta, ensure_ascii=False),
            content_type='application/json; charset=utf-8'
        )

    genai.configure(api_key=gemini_api_key)
    gemini_model_flash = genai.GenerativeModel(model_name="models/gemini-2.0-flash") # Usando Flash para o texto

    try:
        combined_prompt_for_gemini = base_prompt.replace("##TEXTO_DO_USUARIO##", transcribed_text)

        response_model_flash = gemini_model_flash.generate_content(combined_prompt_for_gemini)
        
        gemini_response_text = response_model_flash.text.strip()
        
        print(f"DEBUG: Resposta bruta do Gemini Flash: {gemini_response_text}")

        final_response_for_frontend = gemini_response_text
        
        if 'horario: {{hora_atual}}' in final_response_for_frontend:
            current_time = time.strftime("%H:%M", time.localtime()) 
            final_response_for_frontend = final_response_for_frontend.replace("{{hora_atual}}", current_time)
        
        elif 'temperatura: {{temperatura_curitiba_celsius}}' in final_response_for_frontend:
            temp_curitiba = get_curitiba_temperature(openweathermap_api_key)
            final_response_for_frontend = final_response_for_frontend.replace("{{temperatura_curitiba_celsius}}", temp_curitiba)
        
        elif final_response_for_frontend.startswith('TEXTO: {{resposta_geral_do_gemini}}'):
            print(f"DEBUG: Intenção 'TEXTO', pedindo resposta geral para: {transcribed_text}")
            try:
                general_response_prompt = f"Responda à seguinte pergunta de forma concisa e direta: \"{transcribed_text}\""
                general_gemini_response = gemini_model_flash.generate_content(general_response_prompt)
                final_response_for_frontend = f"TEXTO: {general_gemini_response.text.strip()}"
                print(f"DEBUG: Resposta geral do Gemini: {final_response_for_frontend}")
            except Exception as general_e:
                print(f"Erro ao obter resposta geral do Gemini: {general_e}")
                final_response_for_frontend = "TEXTO: Desculpe, não consegui gerar uma resposta para isso."
                      
        resposta = {'text': final_response_for_frontend}
        return Response(
            json.dumps(resposta, ensure_ascii=False),
            content_type='application/json; charset=utf-8'
        )
    except Exception as e:
        print(f"Erro geral no processamento Gemini Flash: {e}")
        return Response(
            json.dumps({'erro': f'Erro ao interpretar a fala (Gemini Flash): {str(e)}'}, ensure_ascii=False),
            content_type='application/json; charset=utf-8',
            status=500
        )