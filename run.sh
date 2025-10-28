#!/bin/bash

# Quick run script for Video Resume Application

echo "🚀 Starting Video Resume Application..."
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found!"
    echo "Please run ./setup.sh first to set up the application."
    exit 1
fi

# Activate virtual environment
source venv/bin/activate

# Check if database exists
if [ ! -f "video_resumes.db" ]; then
    echo "📋 Database not found. Initializing..."
    python3 init_db.py
    echo ""
fi

# Start the application
echo "🌐 Starting Flask application..."
echo "✅ Application will be available at:"
echo "   - Candidate Form: http://localhost:5000/"
echo "   - Admin Dashboard: http://localhost:5000/admin"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

python3 video_resume_app.py
