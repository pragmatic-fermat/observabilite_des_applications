from flask import Flask, request, render_template_string
from prometheus_client import start_http_server, Counter, Histogram, generate_latest
from prometheus_client.core import CollectorRegistry
import time
import random

# Initialiser l'application Flask
app = Flask(__name__)

# Crée un compteur pour les appels de fonction
REQUEST_COUNT = Counter('my_function_request_count', 'Total number of requests to my_function')

# Crée un histogramme pour les temps d'exécution
REQUEST_LATENCY = Histogram('my_function_request_latency_seconds', 'Latency of requests to my_function in seconds')

# Décorateur pour mesurer les métriques
def metric_decorator(func):
    def wrapper(*args, **kwargs):
        REQUEST_COUNT.inc()  # Incrémente le compteur de requêtes
        with REQUEST_LATENCY.time():  # Mesure le temps d'exécution de la fonction
            result = func(*args, **kwargs)
        return result
    return wrapper

@metric_decorator
def my_function():
    # Simule une tâche longue avec un temps d'exécution aléatoire
    time.sleep(random.uniform(0.1, 0.5))
    return "Function is complete."

@app.route('/')
def index():
    # Appel de la fonction décorée
    message = my_function()
    return render_template_string("<h1>{{ message }}</h1>", message=message)

@app.route('/metrics')
def metrics():
    # Exposer les métriques au format texte brut pour Prometheus
    return generate_latest()

if __name__ == '__main__':
    # Démarre un serveur HTTP pour exposer les métriques sur le port 8000
    start_http_server(8000)
    
    # Démarre l'application Flask sur toutes les interfaces réseau (0.0.0.0) sur le port 5000
    app.run(host='0.0.0.0', port=5000)
