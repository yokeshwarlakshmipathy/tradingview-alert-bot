#!/bin/bash

# Video Resume Application Setup Script
# This script sets up the entire application environment

echo "======================================================================"
echo "Video Resume Application - Setup Script"
echo "======================================================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed."
    echo "Please install Python 3.8 or higher and try again."
    exit 1
fi

echo "✅ Python 3 is installed: $(python3 --version)"
echo ""

# Create virtual environment
echo "📦 Creating virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✅ Virtual environment created"
else
    echo "⏭️  Virtual environment already exists"
fi
echo ""

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate
echo "✅ Virtual environment activated"
echo ""

# Install dependencies
echo "📥 Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
echo "✅ Dependencies installed"
echo ""

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p uploads/videos
mkdir -p logs
echo "✅ Directories created"
echo ""

# Initialize database
echo "🗄️  Initializing database..."
python3 init_db.py
echo ""

echo "======================================================================"
echo "✅ Setup Complete!"
echo "======================================================================"
echo ""
echo "To start the application:"
echo "  1. Activate virtual environment: source venv/bin/activate"
echo "  2. Run the application: python video_resume_app.py"
echo ""
echo "Access the application at:"
echo "  - Candidate Form: http://localhost:5000/"
echo "  - Admin Dashboard: http://localhost:5000/admin"
echo ""
echo "======================================================================"
