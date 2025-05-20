import spotipy
from spotipy.oauth2 import SpotifyClientCredentials
import os
import time
from dotenv import load_dotenv

load_dotenv()
import subprocess
import platform

client_id = os.getenv("SPOTIFY_CLIENT_ID")
client_secret = os.getenv("SPOTIFY_CLIENT_SECRET")

auth_manager = SpotifyClientCredentials(client_id=client_id, client_secret=client_secret)
sp = spotipy.Spotify(auth_manager=auth_manager)

def search_music(query):
    result = sp.search(q=query, type='track', limit=1)

    if result['tracks']['items']:
        track = result['tracks']['items'][0]
        name = track['name']
        artist = track['artists'][0]['name']
        track_id = track['id']
        duration_ms = track['duration_ms']
        spotify_uri = f"spotify:track:{track_id}"

        print(f"Tocando: {name} - {artist}")
        print(f"Duração: {duration_ms / 1000:.2f} s")

        try:
            subprocess.Popen(['spotify', f'--uri={spotify_uri}'])
        except FileNotFoundError:
            print("Spotify não encontrado. Verifique se está instalado e se o comando 'spotify' funciona no terminal.")

        time.sleep(2 + duration_ms / 1000)

    else:
        print("Nenhuma música encontrada.")

query = input("Digite o nome da música que deseja tocar: ")
search_music(query)
