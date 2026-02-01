# Deploy Leaderboard Server to Cloud (24/7 Running)

This guide will help you deploy the leaderboard server to run 24/7 in the cloud, so players can submit scores anytime, even when your computer is off.

## Option 1: Railway (Recommended - Easiest & Free)

Railway is the easiest option with a generous free tier.

### Steps:

1. **Sign up for Railway**
   - Go to https://railway.app
   - Sign up with GitHub (easiest)

2. **Create New Project**
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository (or create one first)

3. **Configure Deployment**
   - Railway auto-detects Node.js
   - It will automatically:
     - Install dependencies (`npm install`)
     - Start the server (`node server.js`)
     - Assign a public URL

4. **Get Your Server URL**
   - Railway gives you a URL like: `https://your-app-name.up.railway.app`
   - Copy this URL

5. **Update Game Configuration**
   - In `leaderboard_manager.gd`, update:
   ```gdscript
   var api_base_url: String = "https://your-app-name.up.railway.app/api"
   var api_enabled: bool = true
   ```
   - Replace `your-app-name.up.railway.app` with your actual Railway URL

6. **Done!**
   - Your server is now running 24/7
   - Players can submit scores anytime
   - Data persists in Railway's database

### Railway Free Tier:
- $5 free credit per month
- Enough for a small game leaderboard
- Auto-sleeps after inactivity (wakes on first request)

---

## Option 2: Render (Free Tier Available)

### Steps:

1. **Sign up**: https://render.com
2. **Create New Web Service**
3. **Connect GitHub repo**
4. **Settings**:
   - Build Command: `npm install`
   - Start Command: `node server.js`
   - Environment: Node
5. **Deploy**
6. **Get URL** and update game config

### Render Free Tier:
- Free tier available
- May sleep after inactivity (wakes on request)

---

## Option 3: Heroku (Limited Free Tier)

### Steps:

1. **Install Heroku CLI**: https://devcenter.heroku.com/articles/heroku-cli
2. **Login**: `heroku login`
3. **Create app**: `heroku create your-app-name`
4. **Deploy**: `git push heroku main`
5. **Get URL**: `heroku info` (shows your app URL)

### Note:
- Heroku's free tier is very limited now
- May require credit card for verification

---

## Option 4: DigitalOcean App Platform

### Steps:

1. **Sign up**: https://www.digitalocean.com
2. **Create App** from GitHub
3. **Configure**:
   - Build command: `npm install`
   - Run command: `node server.js`
4. **Deploy**

### Pricing:
- Starts at $5/month
- More reliable than free tiers

---

## Option 5: Self-Hosted VPS

If you have a VPS (like DigitalOcean Droplet, AWS EC2, etc.):

1. **SSH into your server**
2. **Install Node.js**: `curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs`
3. **Clone your repo** or upload files
4. **Install dependencies**: `npm install`
5. **Use PM2 to keep it running**:
   ```bash
   npm install -g pm2
   pm2 start server.js
   pm2 save
   pm2 startup  # Makes it start on boot
   ```
6. **Set up reverse proxy** (nginx) if needed
7. **Configure firewall** to allow port 3000 (or your chosen port)

---

## Important Notes

### Database Persistence

All cloud platforms will persist your SQLite database, but:
- **Railway/Render**: Database persists automatically
- **Heroku**: Uses ephemeral filesystem (data may be lost on restart) - consider PostgreSQL
- **VPS**: Database file persists on disk

### For Production (Many Players)

Consider upgrading to PostgreSQL:
- More reliable for production
- Better for concurrent access
- Requires code changes (see server code comments)

### Environment Variables

You can set the port via environment variable:
```javascript
const PORT = process.env.PORT || 3000;
```
(Already configured in server.js)

---

## Recommended: Railway

**Why Railway?**
- ✅ Easiest setup (just connect GitHub)
- ✅ Free tier ($5 credit/month)
- ✅ Auto-deploys on git push
- ✅ Persistent database
- ✅ HTTPS by default
- ✅ No credit card required for free tier

**Quick Start:**
1. Push your code to GitHub
2. Connect Railway to your repo
3. Deploy (automatic)
4. Copy the URL
5. Update game config
6. Done!

---

## Testing After Deployment

1. Test the health endpoint: `https://your-url.com/health`
2. Test submitting a score using `test-api.html` (update the URL in the file)
3. Test in your game

Your leaderboard will now work 24/7! 🎉
