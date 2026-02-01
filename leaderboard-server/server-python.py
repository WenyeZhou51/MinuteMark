#!/usr/bin/env python3
"""
Python Flask alternative server for MinuteMark leaderboard.
Requires: pip install flask flask-cors
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import sqlite3
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

DB_PATH = 'leaderboard.db'

def init_db():
    """Initialize the database and create table if needed."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            time REAL NOT NULL,
            date TEXT NOT NULL,
            player_id TEXT NOT NULL,
            player_name TEXT NOT NULL,
            ip_address TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()
    print("Database initialized")

@app.route('/api/leaderboard/submit', methods=['POST'])
def submit_score():
    """Submit a new score to the leaderboard."""
    data = request.json
    
    # Validate required fields
    if 'time' not in data or 'player_id' not in data:
        return jsonify({'error': 'Missing required fields: time and player_id are required'}), 400
    
    # Extract data with defaults
    time = data['time']
    date = data.get('date', datetime.now().isoformat())
    player_id = data['player_id']
    player_name = data.get('player_name', 'Player')
    ip_address = data.get('ip_address', '')
    
    # Insert into database
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO scores (time, date, player_id, player_name, ip_address)
            VALUES (?, ?, ?, ?, ?)
        ''', (time, date, player_id, player_name, ip_address))
        conn.commit()
        score_id = cursor.lastrowid
        conn.close()
        
        print(f"Score submitted: {time}s by {player_name} ({player_id}) from {ip_address}")
        return jsonify({
            'success': True,
            'message': 'Score submitted successfully',
            'id': score_id
        }), 201
    except Exception as e:
        print(f"Error inserting score: {e}")
        return jsonify({'error': 'Failed to save score'}), 500

@app.route('/api/leaderboard/top', methods=['GET'])
def get_top_scores():
    """Get top scores from the leaderboard."""
    limit = int(request.args.get('limit', 100))
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT time, date, player_id, player_name, ip_address
            FROM scores
            ORDER BY time ASC
            LIMIT ?
        ''', (limit,))
        rows = cursor.fetchall()
        conn.close()
        
        # Convert to list of dictionaries
        scores = []
        for row in rows:
            scores.append({
                'time': row[0],
                'date': row[1],
                'player_id': row[2],
                'player_name': row[3],
                'ip_address': row[4]
            })
        
        return jsonify(scores)
    except Exception as e:
        print(f"Error fetching scores: {e}")
        return jsonify({'error': 'Failed to fetch leaderboard'}), 500

@app.route('/api/leaderboard/stats', methods=['GET'])
def get_stats():
    """Get leaderboard statistics."""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) as total, MIN(time) as best_time FROM scores')
        row = cursor.fetchone()
        conn.close()
        
        return jsonify({
            'total_scores': row[0] or 0,
            'best_time': row[1]
        })
    except Exception as e:
        print(f"Error fetching stats: {e}")
        return jsonify({'error': 'Failed to fetch stats'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # Initialize database
    init_db()
    
    # Start server
    port = int(os.environ.get('PORT', 3000))
    print(f"Leaderboard API server running on port {port}")
    print(f"API endpoints:")
    print(f"  POST http://localhost:{port}/api/leaderboard/submit")
    print(f"  GET  http://localhost:{port}/api/leaderboard/top?limit=100")
    print(f"  GET  http://localhost:{port}/api/leaderboard/stats")
    print(f"  GET  http://localhost:{port}/health")
    
    app.run(host='0.0.0.0', port=port, debug=True)
