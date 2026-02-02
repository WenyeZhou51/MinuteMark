const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors()); // Allow cross-origin requests
app.use(bodyParser.json());
app.use(express.json());

// Initialize SQLite database
const dbPath = path.join(__dirname, 'leaderboard.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
  } else {
    console.log('Connected to SQLite database');
    // Create table if it doesn't exist
    db.run(`
      CREATE TABLE IF NOT EXISTS scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time REAL NOT NULL,
        date TEXT NOT NULL,
        player_id TEXT NOT NULL,
        player_name TEXT NOT NULL,
        ip_address TEXT,
        level INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `, (err) => {
      if (err) {
        console.error('Error creating table:', err.message);
      } else {
        console.log('Database table ready');
        // Add level column if it doesn't exist (for existing databases)
        db.run(`
          ALTER TABLE scores ADD COLUMN level INTEGER DEFAULT 0
        `, (alterErr) => {
          if (alterErr) {
            // Column probably already exists, which is fine
            console.log('Level column already exists or could not be added (this is usually fine)');
          } else {
            console.log('Added level column to existing database');
          }
        });
      }
    });
  }
});

// Helper function to get top scores
function getTopScores(limit, level, callback) {
  let query;
  let params;
  
  if (level !== undefined && level !== null) {
    query = `
      SELECT time, date, player_id, player_name, ip_address, level
      FROM scores
      WHERE level = ?
      ORDER BY time ASC
      LIMIT ?
    `;
    params = [level, limit];
  } else {
    query = `
      SELECT time, date, player_id, player_name, ip_address, level
      FROM scores
      ORDER BY time ASC
      LIMIT ?
    `;
    params = [limit];
  }
  
  db.all(query, params, (err, rows) => {
    if (err) {
      callback(err, null);
    } else {
      callback(null, rows);
    }
  });
}

// POST /api/leaderboard/submit - Submit a new score
app.post('/api/leaderboard/submit', (req, res) => {
  const { time, date, player_id, player_name, ip_address, level } = req.body;
  
  // Validate required fields
  if (time === undefined || !player_id) {
    return res.status(400).json({ 
      error: 'Missing required fields: time and player_id are required' 
    });
  }
  
  const levelValue = level !== undefined ? level : 0; // Default to level 0
  
  // First, check how many entries exist for this level
  const countQuery = 'SELECT COUNT(*) as count FROM scores WHERE level = ?';
  
  db.get(countQuery, [levelValue], (countErr, countRow) => {
    if (countErr) {
      console.error('Error counting scores:', countErr.message);
      return res.status(500).json({ error: 'Failed to check existing scores' });
    }
    
    const currentCount = countRow.count;
    console.log(`Level ${levelValue} currently has ${currentCount} entries`);
    
    // If we have 10 or more entries, delete the worst (highest time) one
    if (currentCount >= 10) {
      const deleteWorstQuery = `
        DELETE FROM scores 
        WHERE id = (
          SELECT id FROM scores 
          WHERE level = ? 
          ORDER BY time DESC 
          LIMIT 1
        )
      `;
      
      db.run(deleteWorstQuery, [levelValue], function(deleteErr) {
        if (deleteErr) {
          console.error('Error deleting worst score:', deleteErr.message);
          // Continue with insertion anyway
        } else {
          console.log(`Deleted worst entry for level ${levelValue} (had ${currentCount} entries)`);
        }
        
        // Now insert the new score
        insertScore();
      });
    } else {
      // Less than 10 entries, just insert directly
      insertScore();
    }
  });
  
  // Helper function to insert the score
  function insertScore() {
    const query = `
      INSERT INTO scores (time, date, player_id, player_name, ip_address, level)
      VALUES (?, ?, ?, ?, ?, ?)
    `;
    
    db.run(query, [time, date || new Date().toISOString(), player_id, player_name || 'Player', ip_address || '', levelValue], function(err) {
      if (err) {
        console.error('Error inserting score:', err.message);
        return res.status(500).json({ error: 'Failed to save score' });
      }
      
      console.log(`Score submitted: ${time}s by ${player_name || 'Player'} (${player_id}) for level ${levelValue} from ${ip_address || 'unknown IP'}`);
      res.status(201).json({ 
        success: true, 
        message: 'Score submitted successfully',
        id: this.lastID 
      });
    });
  }
});

// GET /api/leaderboard/top - Get top scores
app.get('/api/leaderboard/top', (req, res) => {
  const limit = parseInt(req.query.limit) || 100;
  const level = req.query.level !== undefined ? parseInt(req.query.level) : null;
  
  getTopScores(limit, level, (err, rows) => {
    if (err) {
      console.error('Error fetching scores:', err.message);
      return res.status(500).json({ error: 'Failed to fetch leaderboard' });
    }
    
    // Return as array (matching the game's expected format)
    res.json(rows);
  });
});

// GET /api/leaderboard/stats - Get leaderboard statistics
app.get('/api/leaderboard/stats', (req, res) => {
  const level = req.query.level !== undefined ? parseInt(req.query.level) : null;
  
  let query;
  let params = [];
  
  if (level !== null) {
    query = 'SELECT COUNT(*) as total, MIN(time) as best_time FROM scores WHERE level = ?';
    params = [level];
  } else {
    query = 'SELECT COUNT(*) as total, MIN(time) as best_time FROM scores';
  }
  
  db.get(query, params, (err, row) => {
    if (err) {
      return res.status(500).json({ error: 'Failed to fetch stats' });
    }
    res.json({
      level: level,
      total_scores: row.total || 0,
      best_time: row.best_time || null
    });
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, () => {
  console.log(`Leaderboard API server running on port ${PORT}`);
  console.log(`API endpoints:`);
  console.log(`  POST http://localhost:${PORT}/api/leaderboard/submit`);
  console.log(`  GET  http://localhost:${PORT}/api/leaderboard/top?limit=100`);
  console.log(`  GET  http://localhost:${PORT}/api/leaderboard/stats`);
  console.log(`  GET  http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  db.close((err) => {
    if (err) {
      console.error('Error closing database:', err.message);
    } else {
      console.log('Database connection closed');
    }
    process.exit(0);
  });
});
