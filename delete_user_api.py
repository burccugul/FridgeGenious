from flask import Flask, request, jsonify
from flask_cors import CORS
import requests

app = Flask(__name__)
CORS(app)

SUPABASE_URL = "https://pzelhqrawaevvuqbpjnc.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6ZWxocXJhd2FldnZ1cWJwam5jIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0NTE1Nzk2MywiZXhwIjoyMDYwNzMzOTYzfQ.TefYiUbmiuvwb_fT4PyKczdCMI5VpUk8cc74rIUESK4"

@app.route('/delete_user', methods=['POST'])
def delete_user():
    data = request.get_json()
    user_id = data.get('user_id')

    if not user_id:
        return jsonify({"error": "user_id is required"}), 400

    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}"
    }

    url = f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}"

    response = requests.delete(url, headers=headers)

    if response.status_code == 204:
        return jsonify({"message": "User deleted successfully"}), 200
    else:
        return jsonify({"error": response.json()}), response.status_code

if __name__ == '__main__':
    app.run(port=5000)