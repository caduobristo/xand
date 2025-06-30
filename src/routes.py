from flask import Blueprint, request, Response
import json
import time
import os
import re 

import speech_recognition as sr
from pydub import AudioSegment 

from dotenv import load_dotenv
import google.generativeai as genai
import requests
import io
import vlc
import yt_dlp
import unicodedata
import base64

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

def download_audio(query):
    def normalizar(texto):
        return unicodedata.normalize('NFKD', texto).encode('ASCII', 'ignore').decode().lower()
    
    temp_path = 'temp_audio.webm'

    # Exclui musica tocada anteriormente
    if os.path.exists(temp_path):
        os.remove(temp_path)

    ydl_opts = {
        'format': 'bestaudio[abr<=128]/bestaudio',
        'outtmpl': 'temp_audio.%(ext)s',
        'postprocessors': [],
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
        'extract_flat': False,
    }

    palavras_proibidas = ['live', 'ao vivo', 'entrevista', 'aula', 
                          'podcast', 'reaction', 'documentario', 'cover',
                          'tutorial']
    duracao_maxima_segundos = 600  # 10 minutos

    flat_opts = ydl_opts.copy()
    flat_opts['extract_flat'] = True
    
    with yt_dlp.YoutubeDL(flat_opts) as ydl:
        results = ydl.extract_info(f"ytsearch5:{query}", download=False)
        entries = results.get('entries', [])

        for entry in entries:
            titulo = normalizar(entry.get('title', ''))
            if any(p in titulo for p in palavras_proibidas):
                continue

            url = entry['url']
            print(f"Selecionado após filtro leve: {titulo}")

            # 2ª etapa: carregar os metadados completos só desse vídeo
            with yt_dlp.YoutubeDL(ydl_opts) as ydl_detalhado:
                full_info = ydl_detalhado.extract_info(url, download=True)
                if 'Music' not in full_info.get('categories', []):
                    continue  # não é da categoria Música
                if full_info.get('duration', 0) <= duracao_maxima_segundos:
                    print(f"Música final: {full_info['title']}")
                    return (ydl_detalhado.prepare_filename(full_info), full_info['title'])

    print("Nenhuma música apropriada encontrada.")
    return None

player = None
def play_audio(file_path):
    global player
    instance = vlc.Instance()
    player = instance.media_player_new()
    media = instance.media_new(file_path)

    player.set_media(media)
    player.play()
    print("Reproduzindo áudio...")


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

def parse_duration_to_seconds(text):
    total_seconds = 0
    
    # Regex para minutos
    minutes_match = re.search(r'(\d+)\s*(minuto|minutos|min)', text, re.IGNORECASE)
    if minutes_match:
        mins = int(minutes_match.group(1))
        total_seconds += mins * 60
    else:
        print("DEBUG_PARSE: Nenhum minuto encontrado.")

    # Regex para segundos
    seconds_match = re.search(r'(\d+)\s*(segundo|segundos|seg)', text, re.IGNORECASE)
    if seconds_match:
        secs = int(seconds_match.group(1))
        total_seconds += secs
    else:
        print("DEBUG_PARSE: Nenhum segundo encontrado.")

    if total_seconds == 0: # Só entra aqui se não achou minutos nem segundos
        num_match = re.search(r'\b(\d+)\b', text, re.IGNORECASE) 
        if num_match:
            if "timer" in text.lower() or "alarme" in text.lower() or "cronômetro" in text.lower():
                total_seconds = int(num_match.group(1))
                print(f"DEBUG_PARSE: Fallback - Número puro encontrado: {total_seconds} (assumido segundos)")
            else:
                print(f"DEBUG_PARSE: Fallback - Número puro encontrado, mas sem palavra-chave de tempo relevante.")
        else:
            print(f"DEBUG_PARSE: Fallback - Nenhum número puro encontrado (regex \b(\d+)\b).")
    else: 
        print(f"DEBUG_PARSE: Já encontrou unidades de tempo, pulando fallback.")
    
    result = total_seconds if total_seconds > 0 else None
    print(f"DEBUG_PARSE: parse_duration_to_seconds - Resultado final: {result}")
    return result

def parse_alarm_time_to_hhmmss(text):
    print(f"DEBUG_PARSE: parse_alarm_time_to_hhmmss - Texto de entrada: '{text}'")
    
    # 1. Tenta HH:MM:SS ou HH:MM
    time_match = re.search(r'(\d{1,2}):(\d{2})(?::(\d{2}))?', text)
    if time_match:
        h = int(time_match.group(1))
        m = int(time_match.group(2))
        s = int(time_match.group(3)) if time_match.group(3) else 0
        result = f"{h:02d}:{m:02d}:{s:02d}"
        print(f"DEBUG_PARSE: HH:MM:SS/HH:MM encontrado: {result}")
        return result

    # 2. Tenta linguagem natural
    hour = None
    minute = 0
    second = 0

    # Match para "X horas"
    hour_match = re.search(r'(\d{1,2})\s*horas', text, re.IGNORECASE)
    if hour_match:
        hour = int(hour_match.group(1))
        print(f"DEBUG_PARSE: Horas por extenso: {hour}")
    
    # Match para "e X minutos" ou "X minutos"
    minute_match = re.search(r'(?:e\s*)?(\d{1,2})\s*minutos', text, re.IGNORECASE)
    if minute_match:
        minute = int(minute_match.group(1))
        print(f"DEBUG_PARSE: Minutos por extenso: {minute}")

    # Match para "e meia"
    if 'e meia' in text.lower() and hour is not None:
        minute = 30
        print(f"DEBUG_PARSE: 'e meia' detectado, minuto: {minute}")
    
    # Palavras-chave específicas
    if 'meia noite' in text.lower():
        hour = 0
        minute = 0
        print("DEBUG_PARSE: 'meia noite' detectado")
    elif 'meio dia' in text.lower():
        hour = 12
        minute = 0
        print("DEBUG_PARSE: 'meio dia' detectado")

    # AM/PM detection for conversion to 24h
    if hour is not None:
        if ('da tarde' in text.lower() or 'da noite' in text.lower() or 'pm' in text.lower()) and hour < 12:
            hour += 12
            print(f"DEBUG_PARSE: AM/PM - Convertido para {hour} (PM/noite)")
        elif ('da manhã' in text.lower() or 'am' in text.lower()) and hour == 12:
            hour = 0
            print(f"DEBUG_PARSE: AM/PM - Convertido 12 AM para {hour}")
    
    if hour is not None:
        result = f"{hour:02d}:{minute:02d}:{second:02d}"
        print(f"DEBUG_PARSE: parse_alarm_time_to_hhmmss - Resultado por extenso: {result}")
        return result
    
    print("DEBUG_PARSE: parse_alarm_time_to_hhmmss - Nenhum formato de tempo reconhecido")
    return None


@main.post('/xand/ask')
def xand_ask():
    base_prompt = """
    Você é o XAND, um assistente virtual com personalidade carismática e divertida.

    Sua tarefa é interpretar a **intenção principal** do usuário e responder **EXATAMENTE** no formato especificado abaixo.

    **Ignore cumprimentos, saudações ou frases de cortesia** como "bom dia", "tudo bem", "por favor", "obrigado", "Xande", etc. Foque apenas nos comandos e palavras-chave.

    Não adicione texto extra, explicações ou cumprimentos. Apenas a resposta formatada correspondente à intenção identificada.

    **NÃO** utilize formatação de código Markdown (como crases triplas ```), aspas simples, aspas duplas, ou outros caracteres de formatação que não sejam parte do texto literal da resposta.

    O que estiver entre chaves duplas '{{ }}' é uma variável que você deve retornar literalmente para substituição no sistema, a menos que especificado o contrário.

    ---

    **Respostas Formato Tabela por Intenção:**

    1.  **Pedir Música:** Quando o usuário pede para tocar/cantar uma música específica.
        * **Entrada:** "toque a música {{nome da música}} para mim", "cante {{nome da música}}", "quero ouvir {{nome da música}}".
        * **Saída:** 'tocar música {{nome da música}}'
            (Substitua {{nome da música}} pela música que o usuário pediu)

    2   **Parar Música:** Quando o usuário pedir para parar de tocar a música.
        * **Entrada:** "Pare de tocar a música para mim", "Pare de cantar", "Não quero mais ouvir música", "Pare de tocar a música {{nome da música}}".
        * **Saída:** 'parar música'

    3.  **Tocar Guitarra:** Quando o usuário pede explicitamente para tocar o instrumento guitarra.
        * **Entrada:** "toque guitarra", "consegue tocar uma guitarra?", "Xand, toque guitarra".
        * **Saída:** 'tocar guitarra'

    4.  **Repetir Fala (com frase):** Quando o usuário pede para você repetir algo que ele diz.
        * **Entrada:** "repita o que eu digo Xand, Olá Mundo", "fale isso: Eu gosto de gatos".
        * **Saída:** 'TEXTO: {{frase_a_repetir}}'
            (Substitua {{frase_a_repetir}} pela frase exata que o usuário pediu para repetir, **sem incluir o comando de repetição**).

    5.  **Perguntar Horário:** Quando o usuário pergunta sobre a hora atual do sistema.
        * **Entrada:** "que horas são?", "me diga a hora", "qual o horário agora?".
        * **Saída:** 'horario: {{hora_atual}}'

    6.  **Perguntar Temperatura de Curitiba:** Quando o usuário pergunta sobre a temperatura especificamente de Curitiba.
        * **Entrada:** "qual a temperatura de Curitiba?", "está quente em Curitiba?", "me diga a temperatura atual em Curitiba".
        * **Saída:** temperatura: {{temperatura_curitiba_celsius}}

    7.  **Brincar (Ação do Pet):** Quando o usuário pede para o XAND brincar.
        * **Entrada:** "quero brincar", "Xand, vamos brincar?", "brinca comigo".
        * **Saída:** 'brincar'

    8.  **Comer (Ação do Pet):** Quando o usuário pede para o XAND comer.
        * **Entrada:** "Xand, coma", "quero comer", "alimente o Xand".
        * **Saída:** 'comer'

    9.  **Dormir (Ação do Pet):** Quando o usuário pede para o XAND dormir/acordar.
        * **Entrada:** "Xand, vá dormir", "hora de dormir", "Xand acorde".
        * **Saída:** 'dormir'

    10. **Iniciar Minigame:** Quando o usuário pede para iniciar o minigame "Xand, o Voador".
        * **Entrada:** "vamos jogar", "iniciar minigame", "quero jogar Xand o Voador", "minigame".
        * **Saída:** 'jogar'

    11. **Configurar Timer:** Quando o usuário pede para configurar um cronômetro com uma duração específica.
        * **Entrada:** "iniciar timer de 1 minuto", "cronômetro 30 segundos", "timer para 5 minutos".
        * **Saída:** 'timer: {{duracao_em_segundos}}'
            (Substitua {{duracao_em_segundos}} pela duração total em segundos como um número inteiro. Ex: para "1 minuto e 30 segundos", retorne "90").

    12. **Configurar Alarme:** Quando o usuário pede para configurar um alarme para um horário específico.
        * **Entrada:** "definir alarme para 7 horas", "alarme 8 e meia da manhã", "me acorde às 14:00".
        * **Saída:** 'alarme: {{horario_alarme_HHMMSS}}'
            (Substitua {{horario_alarme_HHMMSS}} pelo horário no formato HH:MM:SS (24h). Ex: para "8 e meia da manhã", retorne "08:30:00"; para "2 da tarde", retorne "14:00:00").

    13. **Cancelar Alarme:** Quando o usuário pede para cancelar o alarme.
        * **Entrada:** "cancelar alarme", "desligar alarme".
        * **Saída:** 'acao: cancelar alarme'

    14. **Perguntas Comuns/Interação Geral:** Quando o usuário faz uma pergunta que não se encaixa nas categorias acima, mas que esperaria uma resposta direta de um assistente virtual (ex: "faça essa conta", "quanto é 2 mais 2", "quem ganhou o jogo do Palmeiras ontem?", "qual a capital da França?").
        * **Saída:** 'TEXTO: [Resposta concisa e direta do Gemini à pergunta do usuário]'
            (Para esta categoria, **não** retorne '{{resposta_geral_do_gemini}}'. Em vez disso, forneça a resposta diretamente dentro da string, por exemplo: 'TEXTO: 4' para "quanto é 2 mais 2").

    ---

    Agora, interprete o texto do usuário: "##TEXTO_DO_USUARIO##" e forneça a resposta formatada.

    Se nenhuma intenção clara for detectada nos pontos 1-14, responda com "NULL".
    """

    audio_file = request.files.get('audio')
    if not audio_file:
        # Requisição de texto para DEBUG de funções
        transcribed_text = request.form.get('text', '').strip()
        if not transcribed_text:
            return {'erro': 'Nem áudio nem texto foram fornecidos.'}, 400
    else:
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
                parameters=["-ar", "16000", "-ac", "1", "-sample_fmt", "s16"] # Força 16kHz, mono, 16-bit PCM
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
    gemini_model_flash = genai.GenerativeModel(model_name="models/gemini-2.0-flash")

    try:
        combined_prompt_for_gemini = base_prompt.replace("##TEXTO_DO_USUARIO##", transcribed_text)

        response_model_flash = gemini_model_flash.generate_content(combined_prompt_for_gemini)
        
        gemini_response_text = response_model_flash.text.strip()
        
        if gemini_response_text.startswith('```') and gemini_response_text.endswith('```'):
            gemini_response_text = gemini_response_text[3:-3].strip() 
            if gemini_response_text.startswith('python\n'): 
                gemini_response_text = gemini_response_text[len('python\n'):].strip()
            elif gemini_response_text.startswith('text\n'): 
                gemini_response_text = gemini_response_text[len('text\n'):].strip()

        print(f"DEBUG: Resposta bruta do Gemini Flash (limpa): {gemini_response_text}")

        final_response_for_frontend = gemini_response_text
        
        print(f"DEBUG_MATCH: final_response_for_frontend: '{final_response_for_frontend}'")
        print(f"DEBUG_MATCH: transcribed_text: '{transcribed_text}'")
        print(f"DEBUG_MATCH: Checking 'timer:' -> {final_response_for_frontend.startswith('timer: ')}")
        print(f"DEBUG_MATCH: Checking 'alarme:' -> {final_response_for_frontend.startswith('alarme: ')}")
        print(f"DEBUG_MATCH: Checking 'horario:' -> {final_response_for_frontend.startswith('horario: ')}")
        print(f"DEBUG_MATCH: Checking 'temperatura:' -> {final_response_for_frontend.startswith('temperatura: ')}")
        print(f"DEBUG_MATCH: Checking 'tocar música:' -> {final_response_for_frontend.startswith('tocar música: ')}")

        # 1. Substituição de HORÁRIO 
        if final_response_for_frontend.startswith('horario: {{hora_atual}}'): 
            current_time = time.strftime("%H:%M", time.localtime()) 
            final_response_for_frontend = final_response_for_frontend.replace("{{hora_atual}}", current_time)
        
        # 2. Substituição de TEMPERATURA 
        elif final_response_for_frontend.startswith('temperatura: {{temperatura_curitiba_celsius}}'): 
            temp_curitiba = get_curitiba_temperature(openweathermap_api_key)
            final_response_for_frontend = final_response_for_frontend.replace("{{temperatura_curitiba_celsius}}", temp_curitiba)
        
        # 3. Tratamento de AÇÕES (timer, alarme)
        elif final_response_for_frontend.startswith('timer: '): 
            match = re.search(r'timer: (\d+)', final_response_for_frontend) 
            if match:
                duration_seconds = int(match.group(1))
                final_response_for_frontend = f"timer: {duration_seconds}" 
                print(f"DEBUG: Comando Timer com duração de {duration_seconds} segundos (Extraído do Gemini)")
            else:
                final_response_for_frontend = "NULL" 
        
        elif final_response_for_frontend.startswith('alarme: '): 
            match = re.search(r'alarme: (\d{2}:\d{2}:\d{2})', final_response_for_frontend) 
            if match:
                alarm_time_str = match.group(1)
                final_response_for_frontend = f"alarme: {alarm_time_str}"
                print(f"DEBUG: Comando Alarme para {alarm_time_str} (Extraído do Gemini)")
            else:
                final_response_for_frontend = "NULL" 

        elif final_response_for_frontend == 'cancelar alarme': 
             pass 

        # 4. Tratamento de Repetir Fala
        elif final_response_for_frontend.startswith('TEXTO: {{frase_a_repetir}}'):
            if '{{frase_a_repetir}}' in final_response_for_frontend:
                phrase_to_repeat = transcribed_text
                if phrase_to_repeat.lower().startswith('repita o que eu digo'):
                    phrase_to_repeat = phrase_to_repeat.lower().replace('repita o que eu digo', '', 1).strip()
                elif phrase_to_repeat.lower().startswith('fale isso:'):
                    phrase_to_repeat = phrase_to_repeat.lower().replace('fale isso:', '', 1).strip()
                
                final_response_for_frontend = f"TEXTO: {phrase_to_repeat}"
                if not phrase_to_repeat: 
                    final_response_for_frontend = "TEXTO: Desculpe, qual frase devo repetir?"
            pass

        # 5. Tratamento de Tocar Música
        elif final_response_for_frontend.startswith('tocar música') or final_response_for_frontend.startswith('ouvir música'):
            musica = final_response_for_frontend.replace('tocar música', '').replace('ouvir música', '').strip()

            if not musica or musica == 'nome da música':
                resposta = {'text': 'Não encontrei a música solicitada.'}
            else:
                audio_info = download_audio(musica)

                if audio_info:
                    file_path, title = audio_info
                    cleaned_title = title.split('(')[0].strip()

                    with open(file_path, 'rb') as f:
                        audio_bytes = f.read()

                    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

                    os.remove(file_path)

                    resposta = {
                        'text': f'Boa pedida! Tocando {cleaned_title}',
                        'audio_data': audio_base64,
                        'audio_format': 'webm'
                    }
                else:
                    resposta = {'text': f'Desculpe, não consegui encontrar a música {musica}.'}

            # Envia a resposta JSON completa para o app
            return Response(
                json.dumps(resposta, ensure_ascii=False),
                content_type='application/json; charset=utf-8'
            )
        elif final_response_for_frontend.startswith('parar música'):
            # A lógica de parar agora será controlada pelo app
            resposta = {'command': 'stop_music'}
            return Response(
                json.dumps(resposta, ensure_ascii=False),
                content_type='application/json; charset=utf-8'
            )
        
        # LÓGICA PARA TOCAR A MÚSICA DIRETO NO RASP SE ACHARMOS MELHOR

        # elif final_response_for_frontend.startswith('tocar música') or final_response_for_frontend.startswith('ouvir música'):
        #     musica = final_response_for_frontend.replace('tocar música', '').replace('ouvir música', '')
        #     if musica == None:
        #         final_response_for_frontend = 'Não encontrei a música solicitada'
        #     else:
        #         music, title = download_audio(musica)
        #         play_audio(music)
        #         final_response_for_frontend = f'Boa pedida! Tocando {title}'
        #     pass
        # elif final_response_for_frontend.startswith('parar música'):
        #     if player.is_playing():
        #         print('Parando música')
        #         player.stop()
        #     else:
        #         final_response_for_frontend = 'Nenhum música está tocando'

        elif final_response_for_frontend.startswith('TEXTO: '):
            pass 

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
