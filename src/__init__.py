from flask import Flask

def create_app():
    app = Flask(__name__)
    
    # Configurações (pode usar app.config.from_object("config"))
    app.config['SECRET_KEY'] = 'chave-secreta'

    from .routes import main
    app.register_blueprint(main)

    return app
