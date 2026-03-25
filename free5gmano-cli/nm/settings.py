import os

NM_HOST = os.getenv('NM_HOST', '127.0.0.1')
NM_PORT = os.getenv('NM_PORT', '30088')
NM_URL = 'http://{0}:{1}/'.format(NM_HOST, NM_PORT)

Kafka_HOST = os.getenv('KAFKA_HOST', '127.0.0.1')
Kafka_PORT = os.getenv('KAFKA_PORT', '8082')
Kafka_URL = 'http://{0}:{1}/'.format(Kafka_HOST, Kafka_PORT)
