import os
import csv
import io
import boto3
from flask import Flask, jsonify
from botocore.exceptions import ClientError

app = Flask(__name__)

S3_BUCKET = os.environ.get('S3_BUCKET', 'my-csv-bucket')
S3_KEY = os.environ.get('S3_KEY', 'data.csv')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
AWS_ACCESS_KEY = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')

AWS_ENDPOINT_URL = os.environ.get('AWS_ENDPOINT_URL')
extra_config = {}
if AWS_ENDPOINT_URL:
    extra_config['endpoint_url'] = AWS_ENDPOINT_URL

s3_client = boto3.client(
    's3',
    region_name=AWS_REGION,
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY,
    **extra_config
)

def read_csv_from_s3(bucket, key):
    try:
        obj = s3_client.get_object(Bucket=bucket, Key=key)
        data = obj['Body'].read().decode('utf-8')
        csv_reader = csv.DictReader(io.StringIO(data))
        return list(csv_reader)
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            return []
        raise e

@app.route('/api/data', methods=['GET'])
def get_data():
    try:
        rows = read_csv_from_s3(S3_BUCKET, S3_KEY)
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    
@app.route("/health")
def health():
    return {"status": "ok"}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=7001)