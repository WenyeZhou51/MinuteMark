# Quick Start Guide

## Node.js Server (Recommended)

### 1. Install Node.js
Download from https://nodejs.org/ (LTS version recommended)

### 2. Install Dependencies
```bash
cd leaderboard-server
npm install
```

### 3. Start the Server
```bash
npm start
```

You should see:
```
Leaderboard API server running on port 3000
API endpoints:
  POST http://localhost:3000/api/leaderboard/submit
  GET  http://localhost:3000/api/leaderboard/top?limit=100
  ...
```

### 4. Update Game Configuration
Edit `leaderboard_manager.gd` in your game project:
```gdscript
var api_base_url: String = "http://localhost:3000/api"
var api_enabled: bool = true
```

### 5. Test It!
1. Run your game
2. Complete a level
3. Check the server console - you should see score submissions
4. The victory screen should show the global leaderboard

## Python Server (Alternative)

### 1. Install Python
Python 3.7+ required. Download from https://www.python.org/

### 2. Install Dependencies
```bash
cd leaderboard-server
pip install -r requirements.txt
```

### 3. Start the Server
```bash
python server-python.py
```

### 4. Update Game Configuration
Same as Node.js - update `leaderboard_manager.gd` with the server URL.

## Running on Local Network

To allow other computers on your network to connect:

### 1. Find Your IP Address
- **Windows**: Open Command Prompt, type `ipconfig`, look for "IPv4 Address"
- **Mac/Linux**: Open Terminal, type `ifconfig` or `ip addr`, look for your network interface

### 2. Update Game Configuration
On each computer, update `leaderboard_manager.gd`:
```gdscript
var api_base_url: String = "http://YOUR_IP_ADDRESS:3000/api"
var api_enabled: bool = true
```

Replace `YOUR_IP_ADDRESS` with the IP from step 1 (e.g., `192.168.1.100`)

### 3. Allow Firewall Access
- **Windows**: Allow Node.js/Python through Windows Firewall
- **Mac**: System Preferences → Security & Privacy → Firewall
- **Linux**: Configure firewall to allow port 3000

## Troubleshooting

### "Cannot connect to server"
- Make sure the server is running (`npm start` or `python server-python.py`)
- Check the URL in `leaderboard_manager.gd` matches the server
- For network access, ensure firewall allows port 3000
- Try `http://localhost:3000/health` in a browser to test

### "Failed to submit score"
- Check server console for error messages
- Verify the server is receiving requests
- Check database file permissions (`leaderboard.db`)

### Leaderboard shows "LEADERBOARD" instead of "GLOBAL LEADERBOARD"
- This means it's using local leaderboard (API not connected)
- Check `api_enabled = true` in `leaderboard_manager.gd`
- Verify the API URL is correct
- Check server is running and accessible

## Next Steps

- See `README.md` for deployment options (Heroku, Railway, etc.)
- For production, consider using PostgreSQL instead of SQLite
- Add authentication/rate limiting for public servers
