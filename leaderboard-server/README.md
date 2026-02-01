# MinuteMark Leaderboard Server

Simple Node.js/Express API server for the MinuteMark game leaderboard.

## Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Start the Server
```bash
npm start
```

The server will start on `http://localhost:3000` by default.

### 3. Update Game Configuration
In `leaderboard_manager.gd`, update:
```gdscript
var api_base_url: String = "http://localhost:3000/api"  # For local testing
var api_enabled: bool = true
```

## API Endpoints

### POST `/api/leaderboard/submit`
Submit a new score.

**Request Body:**
```json
{
  "time": 123.45,
  "date": "2024-01-15T10:30:00",
  "player_id": "player_1234567890_123456",
  "player_name": "PlayerName",
  "ip_address": "192.168.1.100"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Score submitted successfully",
  "id": 1
}
```

### GET `/api/leaderboard/top?limit=100`
Get top scores.

**Query Parameters:**
- `limit` (optional): Number of scores to return (default: 100)

**Response:**
```json
[
  {
    "time": 98.5,
    "date": "2024-01-15T10:30:00",
    "player_id": "player_1234567890_123456",
    "player_name": "PlayerName",
    "ip_address": "192.168.1.100"
  }
]
```

### GET `/api/leaderboard/stats`
Get leaderboard statistics.

**Response:**
```json
{
  "total_scores": 150,
  "best_time": 87.3
}
```

## Database

The server uses SQLite (`leaderboard.db`) which is created automatically. The database file is stored in the server directory.

## Deployment

### Local Network Deployment
1. Find your computer's IP address:
   - Windows: `ipconfig`
   - Mac/Linux: `ifconfig` or `ip addr`
2. Update game config:
   ```gdscript
   var api_base_url: String = "http://YOUR_IP_ADDRESS:3000/api"
   ```
3. Make sure firewall allows port 3000

### Cloud Deployment Options

#### Option 1: Heroku
1. Install Heroku CLI
2. Create `Procfile`:
   ```
   web: node server.js
   ```
3. Deploy:
   ```bash
   heroku create your-app-name
   git push heroku main
   ```

#### Option 2: Railway
1. Connect GitHub repo
2. Railway auto-detects Node.js
3. Set environment variable `PORT` (auto-set by Railway)

#### Option 3: DigitalOcean / AWS / Google Cloud
- Use PM2 or systemd to run the server
- Set up reverse proxy (nginx) if needed
- Use PostgreSQL/MySQL for production (modify code)

## Environment Variables

- `PORT`: Server port (default: 3000)

## Production Considerations

For production, consider:
- Using PostgreSQL or MySQL instead of SQLite
- Adding authentication/rate limiting
- Using HTTPS
- Adding input validation and sanitization
- Setting up database backups
