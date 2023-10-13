from flask import Flask, jsonify
import time

app = Flask(__name__)

@app.route("/get_data", methods=["GET"])
def get_data():
    current_timestamp = int(time.time())
    data = {
        "message": "Automate all the things!",
        "timestamp": current_timestamp
    }
    return jsonify(data)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0")