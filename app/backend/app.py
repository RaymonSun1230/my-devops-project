import os
import csv
import io
import logging
import boto3
from flask import Flask, jsonify
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Suppress only health check logs (keep /api/data visible)
class HealthCheckFilter(logging.Filter):
    def filter(self, record):
        return 'GET /health' not in record.getMessage()
logging.getLogger('werkzeug').addFilter(HealthCheckFilter())

S3_BUCKET = os.environ.get('S3_BUCKET', 'my-csv-bucket')
S3_KEY = os.environ.get('S3_KEY', 'data.csv')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
AWS_ACCESS_KEY = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')

AWS_ENDPOINT_URL = os.environ.get('AWS_ENDPOINT_URL')

s3_kwargs = {'region_name': AWS_REGION}
if AWS_ACCESS_KEY and AWS_SECRET_KEY:
    s3_kwargs['aws_access_key_id'] = AWS_ACCESS_KEY
    s3_kwargs['aws_secret_access_key'] = AWS_SECRET_KEY
if AWS_ENDPOINT_URL:
    s3_kwargs['endpoint_url'] = AWS_ENDPOINT_URL

logger.info('Initializing S3 client for region=%s', AWS_REGION)
logger.info('S3_BUCKET=%s S3_KEY=%s', S3_BUCKET, S3_KEY)
if AWS_ACCESS_KEY:
    logger.info('Using explicit AWS access key')
else:
    logger.info('No explicit AWS keys - relying on IRSA / default chain')

s3_client = boto3.client('s3', **s3_kwargs)

def read_csv_from_s3(bucket, key):
    try:
        logger.info('Reading s3://%s/%s', bucket, key)
        obj = s3_client.get_object(Bucket=bucket, Key=key)
        data = obj['Body'].read().decode('utf-8')
        csv_reader = csv.DictReader(io.StringIO(data))
        rows = list(csv_reader)
        logger.info('Read %d rows from S3', len(rows))
        return rows
    except ClientError as e:
        code = e.response['Error']['Code']
        logger.error('S3 ClientError: %s - %s', code, e)
        if code == 'NoSuchKey':
            return []
        raise e

@app.route('/api/data', methods=['GET'])
def get_data():
    try:
        logger.info('GET /api/data called')
        rows = read_csv_from_s3(S3_BUCKET, S3_KEY)
        return jsonify(rows)
    except Exception as e:
        logger.error('GET /api/data error: %s', e, exc_info=True)
        return jsonify({'error': str(e)}), 500
    
@app.route("/health")
def health():
    return {"status": "ok"}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=7001)