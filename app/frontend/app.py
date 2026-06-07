import os
import logging
import requests
from flask import Flask, render_template

app = Flask(__name__)

# Suppress health check logs
class HealthCheckFilter(logging.Filter):
    def filter(self, record):
        return not ('GET / ' in record.getMessage() or 'GET /favicon' in record.getMessage())
logging.getLogger('werkzeug').addFilter(HealthCheckFilter())

BACKEND_URL = os.environ.get('BACKEND_URL', 'http://backend:5001')

@app.route('/')
def index():
    try:
        resp = requests.get(f'{BACKEND_URL}/api/data')
        if resp.status_code == 200:
            data = resp.json()
        else:
            data = []
    except Exception:
        data = []
    return render_template('index.html', data=data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=7000)