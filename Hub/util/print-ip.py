import socket

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = "127.0.0.1"
    finally:
        s.close()
    return IP

def show_banner():
    ip = get_local_ip()
    print("="*60)
    print(f" 👇 USE THIS IP FOR YOUR ESP32 SETUP 👇")
    print(f"\n      \033[92m{ip}\033[0m") 
    print("="*60 + "\n")

if __name__ == "__main__":
    show_banner()