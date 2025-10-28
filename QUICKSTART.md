# Quick Start Guide - Video Resume Application

This guide will help you get the Video Resume Application up and running in minutes.

## 🚀 Quick Setup (Linux/Mac)

```bash
# 1. Navigate to the project directory
cd /workspace

# 2. Run the setup script
chmod +x setup.sh
./setup.sh

# 3. Start the application
source venv/bin/activate
python video_resume_app.py
```

## 🪟 Quick Setup (Windows)

```cmd
# 1. Navigate to the project directory
cd \workspace

# 2. Create virtual environment
python -m venv venv

# 3. Activate virtual environment
venv\Scripts\activate

# 4. Install dependencies
pip install -r requirements.txt

# 5. Initialize database
python init_db.py

# 6. Start the application
python video_resume_app.py
```

## 📱 Access the Application

Once the application is running, open your web browser and go to:

- **Candidate Submission Form**: http://localhost:5000/
- **Admin Dashboard**: http://localhost:5000/admin

## 🧪 Testing the Application

### Submit a Video Resume

1. Go to http://localhost:5000/
2. Fill in the form:
   - Full Name: Your Name
   - Email: your.email@example.com
   - Phone Number: +1 234 567 8900
   - Upload a video file (MP4, AVI, MOV, etc.)
   - Check the consent checkbox
3. Click "Submit Video Resume"
4. You should see a success message

### View Submissions (Admin)

1. Go to http://localhost:5000/admin
2. You'll see all submitted video resumes
3. Click "View" to watch a video
4. Click "Download" to download the video file
5. Click "Delete" to remove a submission

## 🛠️ Common Operations

### Reset Database

```bash
# WARNING: This will delete all data!
python init_db.py --reset
```

### Add Test Data

```bash
python init_db.py --test-data
```

### Reset and Add Test Data

```bash
python init_db.py --reset --test-data
```

### Change Port

```bash
# Run on port 8000 instead of 5000
PORT=8000 python video_resume_app.py
```

## 📋 API Testing with curl

### Submit a Video Resume

```bash
curl -X POST http://localhost:5000/api/submit \
  -F "full_name=John Doe" \
  -F "email=john.doe@example.com" \
  -F "phone_number=+1234567890" \
  -F "consent=true" \
  -F "video=@path/to/your/video.mp4"
```

### Get All Candidates

```bash
curl http://localhost:5000/api/candidates
```

### Get Specific Candidate

```bash
curl http://localhost:5000/api/candidates/1
```

### Delete Candidate

```bash
curl -X DELETE http://localhost:5000/api/candidates/1
```

## 🔍 Troubleshooting

### Port Already in Use

```bash
# Kill process using port 5000
lsof -ti:5000 | xargs kill -9

# Or use a different port
PORT=8000 python video_resume_app.py
```

### Module Not Found Error

```bash
# Make sure virtual environment is activated
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Reinstall dependencies
pip install -r requirements.txt
```

### Database Error

```bash
# Reset database
rm video_resumes.db
python init_db.py
```

### Upload Directory Permission Error

```bash
# Create and set permissions
mkdir -p uploads/videos
chmod 755 uploads/videos
```

## 📚 Next Steps

- Read the full documentation: [VIDEO_RESUME_README.md](VIDEO_RESUME_README.md)
- Customize the configuration: [config.py](config.py)
- Deploy to production: See deployment section in README

## 💡 Tips

1. **Video Format**: MP4 is the most widely supported format
2. **File Size**: Keep videos under 50MB for better performance
3. **Video Length**: 1 minute is recommended for candidate videos
4. **Security**: Change the SECRET_KEY in config.py for production
5. **Database**: Consider PostgreSQL for production use

## 🆘 Need Help?

- Check the full README: `VIDEO_RESUME_README.md`
- Review the code: `video_resume_app.py`
- Check logs for errors
- Ensure all dependencies are installed

---

**Happy recruiting! 🎉**
