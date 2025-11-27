import requests

BASE_URL = "http://localhost:8000"  # adjust if different

ADMIN_EMAIL = "email"
ADMIN_PASSWORD = "plantpwd"

def login_as_admin():
    url = f"{BASE_URL}/api/auth/login"
    payload = {
        "email": ADMIN_EMAIL,
        "password": ADMIN_PASSWORD,
    }

    resp = requests.post(url, json=payload)
    print("Status:", resp.status_code)
    print("Body:", resp.text)

    resp.raise_for_status()  # raises if not 2xx

    data = resp.json()
    token = data["access_token"]
    print("Got token:", token)

    return token

def call_admin_endpoint(token: str):
    url = f"{BASE_URL}/api/consumer/my-plants"
    headers = {
        "Authorization": f"Bearer {token}",
    }
    resp = requests.get(url, headers=headers)
    print("Admin endpoint status:", resp.status_code)
    print("Admin endpoint body:", resp.text)

if __name__ == "__main__":
    token = login_as_admin()
    call_admin_endpoint(token)