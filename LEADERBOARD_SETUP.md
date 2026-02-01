# Leaderboard Setup Guide

## Overview
The leaderboard system supports both local and global score tracking. It automatically tracks:
- Player ID (unique identifier per installation)
- Player name (customizable)
- IP address (for identifying different computers/networks)
- Completion time
- Date/time of completion

## Local Leaderboard
The local leaderboard works automatically without any setup. Scores are saved to `user://leaderboard.json` and persist across game sessions.

## Global Leaderboard (Multi-Player, Multi-Computer)
To enable global leaderboard functionality across different computers, players, and IPs, you need to:

### Quick Start (Recommended)
A ready-to-use server is included in the `leaderboard-server/` directory!

**Option 1: Node.js Server (Recommended)**
```bash
cd leaderboard-server
npm install
npm start
```

**Option 2: Python Server**
```bash
cd leaderboard-server
pip install -r requirements.txt
python server-python.py
```

Then update `leaderboard_manager.gd`:
```gdscript
var api_base_url: String = "http://localhost:3000/api"  # For local testing
var api_enabled: bool = true
```

### Manual Backend Setup
If you prefer to create your own backend, you need:

### 1. Set Up Backend API
Create a backend server with two endpoints:

#### POST `/api/leaderboard/submit`
Receives score submissions in JSON format:
```json
{
  "time": 123.45,
  "date": "2024-01-15T10:30:00",
  "player_id": "player_1234567890_123456",
  "player_name": "PlayerName",
  "ip_address": "192.168.1.100"
}
```

Response: `200 OK` or `201 Created`

#### GET `/api/leaderboard/top?limit=100`
Returns top scores in JSON format:
```json
[
  {
    "time": 98.5,
    "date": "2024-01-15T10:30:00",
    "player_id": "player_1234567890_123456",
    "player_name": "PlayerName",
    "ip_address": "192.168.1.100"
  },
  ...
]
```

Or with wrapper:
```json
{
  "scores": [...]
}
```

### 2. Configure API in LeaderboardManager
Edit `leaderboard_manager.gd` and update:
```gdscript
var api_base_url: String = "https://your-api-server.com/api"  # Your actual API URL
var api_enabled: bool = true  # Set to true to enable API
```

### 3. Player Name (Optional)
Players can set their name (defaults to "Player"). You can add a UI to call:
```gdscript
LeaderboardManager.set_player_name("CustomName")
```

## Features
- **Automatic Player ID**: Generated on first run, stored in `user://player_id.txt`
- **IP Detection**: Automatically detects local IP address
- **Fallback**: If API is unavailable, falls back to local leaderboard
- **Global Display**: Victory screen shows global leaderboard if available, local otherwise
- **Player Identification**: Shows player names/IDs in leaderboard display

## Testing Without Backend
The system works perfectly fine without a backend - it will just use local leaderboard only. Set `api_enabled = false` to disable API calls.
