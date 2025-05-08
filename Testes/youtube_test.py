import os
import time
import yt_dlp
import vlc
import threading

player = None
actual_file = None
stop_signal = False

def download_audio(query):
    temp_path = 'temp_audio.webm'

    # Exclui musica tocada anteriormente
    if os.path.exists(temp_path):
        os.remove(temp_path)

    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': 'temp_audio.%(ext)s',
        'postprocessors': [],
        'quiet': True,
        'no_warnings': True,
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(f"ytsearch1:{query}", download=True)
        print(f"Música selecionada: {info['entries'][0]['title']}")
        downloaded_file = ydl.prepare_filename(info['entries'][0])
        return downloaded_file

def play_audio(file_path):
    global player, stop_signal
    instance = vlc.Instance()
    player = instance.media_player_new()
    media = instance.media_new(file_path)

    player.set_media(media)
    player.play()
    print("Reproduzindo áudio...")
    
    # Espera a musica começar a tocar
    time.sleep(1)
    
    while player.is_playing() or player.get_state() == vlc.State.Paused:
        if stop_signal:
            break
        time.sleep(0.5)

def command_monitor():
    global player, actual_file, stop_signal
    while True:
        command = input("Comandos: [pausar, continuar, parar]: ").strip().lower()
        if command == "pausar" and player:
            player.pause()
            print("Música pausada.")
        elif command == "continuar" and player:
            player.pause()
            print("Música retomada.")
        elif command == "parar" and player:
            player.stop()
            stop_signal = True
            print("Música parada.")
            if actual_file and os.path.exists(actual_file):
                os.remove(actual_file)
                print("Arquivo removido.")
            break

def play_youtube_audio(query):
    global actual_file, stop_signal
    stop_signal = False
    actual_file = download_audio(query)

    # Thread para processar comandos do áudio tocado
    commands_thread = threading.Thread(target=command_monitor)
    commands_thread.daemon = True
    commands_thread.start()

    play_audio(actual_file)

query = input("Digite o nome da música que deseja tocar: ")
play_youtube_audio(query)