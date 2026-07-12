import json
import urllib.parse
import urllib.request
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
import websocket

pishock_cache = {}
active_websockets = {}
ws_lock = threading.Lock()

def get_or_create_ws(username, apikey):
    ws_url = f"wss://broker.pishock.com/v2?Username={urllib.parse.quote(str(username))}&ApiKey={urllib.parse.quote(str(apikey))}"
    key = (username, apikey)
    
    with ws_lock:
        if key in active_websockets:
            return active_websockets[key]
        
        print(f"Connecting to PiShock V2 WebSocket broker for {username}...")
        ws = websocket.create_connection(ws_url)
        active_websockets[key] = ws
        return ws

def close_ws(username, apikey):
    key = (username, apikey)
    with ws_lock:
        if key in active_websockets:
            try:
                active_websockets[key].close()
            except Exception:
                pass
            del active_websockets[key]

def get_pishock_data(username, apikey):
    cache_key = (username, apikey)
    if cache_key in pishock_cache:
        return pishock_cache[cache_key]
        
    try:
        # 1. Get User ID
        auth_url = f"https://auth.pishock.com/Auth/GetUserIfAPIKeyValid?apikey={urllib.parse.quote(str(apikey))}&username={urllib.parse.quote(str(username))}"
        req1 = urllib.request.Request(auth_url)
        with urllib.request.urlopen(req1) as response:
            user_info = json.loads(response.read().decode())
            # Fallback checks in case the key differs in casing
            user_id = user_info.get("UserId") or user_info.get("UserID") or user_info.get("userId") or user_info.get("id")
            
        if not user_id:
            print("Could not find UserID in auth response.")
            return None
            
        # 2. Get Devices
        devices_url = f"https://ps.pishock.com/PiShock/GetUserDevices?UserId={user_id}&Token={urllib.parse.quote(str(apikey))}&api=true"
        req2 = urllib.request.Request(devices_url)
        with urllib.request.urlopen(req2) as response:
            devices = json.loads(response.read().decode())
            
        clients = []
        for device in devices:
            client_id = device.get('clientId')
            shockers = device.get('shockers', [])
            valid_shockers = []
            for s in shockers:
                if not s.get('isPaused', False):
                    valid_shockers.append({
                        "shockerId": s.get('shockerId'),
                        "name": s.get('name', '')
                    })
            if valid_shockers:
                clients.append({"clientId": client_id, "shockers": valid_shockers})
                
        result = {"userId": user_id, "clients": clients}
        pishock_cache[cache_key] = result
        return result
    except Exception as e:
        print(f"Error fetching PiShock data: {e}")
        return None

def send_to_pishock_ws(data):
    username = data.get('username')
    apikey = data.get('apikey')
    
    if not username or not apikey:
        print("Missing username or apikey in payload.")
        return
        
    pishock_data = get_pishock_data(username, apikey)
    if not pishock_data:
        print("Failed to get dynamic PiShock data. Cannot send shock.")
        return
        
    user_id = pishock_data["userId"]
    clients = pishock_data["clients"]
    
    # Mapping Lua OP to WebSocket Mode
    op_map = {"0": "s", "1": "v", "2": "b"}
    mode = op_map.get(str(data.get('op')), "v")
    
    intensity = int(data.get('intensity', 10))
    duration_ms = int(float(data.get('duration', 1)) * 1000)
    
    shocker_names_str = data.get('shocker_names', '')
    allowed_names = [name.strip().lower() for name in shocker_names_str.split(',') if name.strip()]

    commands = []
    for client in clients:
        client_id = client["clientId"]
        for shocker in client["shockers"]:
            shocker_id = shocker["shockerId"]
            shocker_name = shocker.get("name", "").strip().lower()

            if allowed_names:
                if shocker_name not in allowed_names and str(shocker_id) not in allowed_names:
                    continue

            commands.append({
                "Target": f"c{client_id}-ops",
                "Body": {
                    "id": shocker_id,
                    "m": mode,
                    "i": intensity,
                    "d": duration_ms,
                    "r": True,
                    "l": {
                        "u": user_id,
                        "ty": "api",
                        "w": False,
                        "h": False,
                        "o": "Darktide"
                    }
                }
            })

    if not commands:
        print("No active/matching shockers found to send commands to.")
        return

    message = {
        "Operation": "PUBLISH",
        "PublishCommands": commands
    }
    
    max_retries = 1
    for attempt in range(max_retries + 1):
        try:
            ws = get_or_create_ws(username, apikey)
            ws.send(json.dumps(message))
            print(f"Sent direct PUBLISH command for {len(commands)} shocker(s)... (Attempt {attempt + 1})")
            break # Success
        except Exception as e:
            print(f"WebSocket Error on attempt {attempt + 1}: {e}")
            close_ws(username, apikey)
            if attempt == max_retries:
                print("Failed to send command after retries.")

class PiShockBridgeHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
            except json.JSONDecodeError:
                # Fallback if the game sends x-www-form-urlencoded
                import urllib.parse
                parsed = urllib.parse.parse_qs(post_data.decode('utf-8'))
                data = {k: v[0] for k, v in parsed.items()}
            
            print(f"Detected trigger via HTTP: {data}")
            
            # Send to PiShock asynchronously so we can reply to the game instantly
            threading.Thread(target=send_to_pishock_ws, args=(data,)).start()
            
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b"OK")
        except Exception as e:
            print(f"Error handling HTTP request: {e}")
            self.send_response(500)
            self.end_headers()

    # Silence the default HTTP logging so it doesn't spam the console
    def log_message(self, format, *args):
        pass

if __name__ == "__main__":
    server_address = ('127.0.0.1', 20010)
    httpd = HTTPServer(server_address, PiShockBridgeHandler)
    
    print("==================================================")
    print(" PiShock Darktide HTTP Server Active")
    print(" Listening for mod commands on http://127.0.0.1:20010/shock")
    print("==================================================")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        httpd.server_close()