import json
import rocksdb
from flask import Flask, jsonify, request

app = Flask(__name__)
db = rocksdb.DB("/data/userdb", rocksdb.Options(create_if_missing=True))

@app.route('/user/<username>')
def get_user(username):
    try:
        data = db.get(username.encode('utf-8'))
        if data is None:
            return jsonify({"error": "User not found"}), 404
        user_info = eval(data.decode('utf-8'))
        response = {
            "login": user_info['login'],
            "full_name": user_info['full_name'],
            "contact": {
                "email": user_info['contact']['email'],
                "phone": user_info['contact']['phone']
            }
        }
        return jsonify(response)
    except:
        return jsonify({"error": "Error retrieving user"}), 500

@app.route('/user/<username>', methods=['PUT'])
def update_user(username):
    try:
        data = db.get(username.encode('utf-8'))
        if not data:
            return jsonify({"error": "User not found."}), 404
        user_info = eval(data.decode('utf-8'))
        update_data = request.json
        if 'full_name' in update_data:
            user_info['full_name'] = update_data['full_name']
        if 'login' in update_data:
            user_info['login'] = update_data['login']
        if 'contact' in update_data:
            if 'email' in update_data['contact']:
                user_info['contact']['email'] = update_data['contact']['email']
            if 'phone' in update_data['contact']:
                user_info['contact']['phone'] = update_data['contact']['phone']
        db.put(username.encode('utf-8'), json.dumps(user_info).encode('utf-8'))
        return jsonify(user_info)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/user/<username>', methods=['DELETE'])
def delete_user(username):
    try:
        db.delete(username.encode('utf-8'))
        return jsonify({"success": "User deleted successfully"})
    except:
        return jsonify({"error": "Error deleting user"}), 500

@app.route('/user', methods=['POST'])
def add_user():
    try:
        user_info = request.get_json()
        if 'login' not in user_info:
            return jsonify({"error": "Login is required"}), 400
        username = user_info['login']
        db.put(username.encode('utf-8'), json.dumps(user_info).encode('utf-8'))
        return jsonify({"success": "User added successfully"})
    except:
        return jsonify({"error": "Error adding user"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0')
