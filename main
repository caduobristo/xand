import google.generativeai as genai

genai.configure(api_key="")
model = genai.GenerativeModel(model_name="models/gemini-1.5-flash-latest")

prompt_inicial = "Olá, Gemini. Preciso que faça o seguinte. Sempre que eu solicitar para você, de qualquer forma, que me dê a temperatura, envie apenas o valor numérico da temperatura de Curitiba em graus Celsius. E quando eu solicitar que toque um instrumento, preciso que envie apenas o nome do intrumento de volta. SEMPRE. Entendido?"
response_prompt = model.generate_content(prompt_inicial)
print(f"Resposta ao prompt inicial: {response_prompt.text}")

with open("temp.ogg", "rb") as audio_file_temp:
    audio_data_temp = audio_file_temp.read()

response_audio_temp = model.generate_content(
    [
        prompt_inicial,  
        {
            "mime_type": "audio/ogg",
            "data": audio_data_temp
        }
    ]
)
print(f"Resposta ao áudio de temperatura: {response_audio_temp.text}")

# Solicitação de instrumento via áudio (incluindo a instrução)
with open("inst.ogg", "rb") as audio_file_inst:
    audio_data_inst = audio_file_inst.read()

response_audio_inst = model.generate_content(
    [
        prompt_inicial, 
        {
            "mime_type": "audio/ogg",
            "data": audio_data_inst
        }
    ]
)
print(f"Resposta ao áudio de instrumento: {response_audio_inst.text}")
