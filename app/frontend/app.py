import os
import logging
import requests
from flask import Flask, render_template

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class HealthCheckFilter(logging.Filter):
    def filter(self, record):
        msg = record.getMessage()
        return 'GET /health' not in msg and 'GET /favicon' not in msg
logging.getLogger('werkzeug').addFilter(HealthCheckFilter())

BACKEND_URL = os.environ.get('BACKEND_URL', 'http://backend:5001')
logger.info('BACKEND_URL=%s', BACKEND_URL)

@app.route('/health')
def health():
    return {"status": "ok"}, 200

@app.route('/')
def index():
    try:
        url = f'{BACKEND_URL}/api/data'
        logger.info('Calling backend: %s', url)
        resp = requests.get(url, timeout=10)
        logger.info('Backend responded status=%d', resp.status_code)
        if resp.status_code == 200:
            data = resp.json()
            logger.info('Got %d records from backend', len(data))
        else:
            logger.error('Backend returned non-200: %s', resp.text[:500])
            data = []
    except Exception as e:
        logger.error('Failed to call backend: %s', e, exc_info=True)
        data = []
    return render_template('index.html', data=data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=7000)