from flask import Flask, jsonify
from datetime import datetime, timezone
import random

app = Flask(__name__)

@app.route('/sysload')
def sysload():
    sysload = round(random.uniform(5.0, 95.0), 1)
    timestamp = datetime.now(timezone.utc).isoformat()
    return jsonify(sysload=sysload, timestamp=timestamp)

if __name__ == '__main__':
    app.run(host='0.0.0.0')
