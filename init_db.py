#!/usr/bin/env python3
"""
Database initialization script for Video Resume Application

This script creates the database tables and optionally seeds with test data.
"""

import os
import sys
from video_resume_app import app, db, Candidate, VideoResume

def init_database(with_test_data=False):
    """Initialize the database with tables and optionally test data"""
    
    print("=" * 60)
    print("Video Resume Application - Database Initialization")
    print("=" * 60)
    
    with app.app_context():
        # Create upload directory
        os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
        print(f"✅ Upload directory created: {app.config['UPLOAD_FOLDER']}")
        
        # Drop all existing tables (be careful in production!)
        if '--reset' in sys.argv:
            print("\n⚠️  WARNING: Dropping all existing tables...")
            response = input("Are you sure you want to continue? (yes/no): ")
            if response.lower() != 'yes':
                print("❌ Database reset cancelled.")
                return
            db.drop_all()
            print("✅ All tables dropped.")
        
        # Create all tables
        print("\n📋 Creating database tables...")
        db.create_all()
        print("✅ Database tables created successfully!")
        
        # Print table information
        print("\n📊 Database schema created:")
        print("   - Candidates table")
        print("   - Video Resumes table")
        
        # Add test data if requested
        if with_test_data or '--test-data' in sys.argv:
            print("\n🧪 Adding test data...")
            add_test_data()
            print("✅ Test data added successfully!")
        
        # Print summary
        candidate_count = Candidate.query.count()
        video_count = VideoResume.query.count()
        
        print("\n" + "=" * 60)
        print("Database Initialization Complete!")
        print("=" * 60)
        print(f"📊 Statistics:")
        print(f"   - Total Candidates: {candidate_count}")
        print(f"   - Total Video Resumes: {video_count}")
        print(f"   - Database: {app.config['SQLALCHEMY_DATABASE_URI']}")
        print(f"   - Upload Folder: {app.config['UPLOAD_FOLDER']}")
        print("=" * 60)


def add_test_data():
    """Add test data to the database"""
    
    # Note: This creates candidate records without actual video files
    # In a real scenario, you would need actual video files
    
    test_candidates = [
        {
            'full_name': 'Yokeshwar L',
            'email': 'yokeshlakshmipathy@gmail.com',
            'phone_number': '+91 94442 16431',
            'google_name': 'Yokeshwar Lakshmipathy',
            'google_email': 'yokeshwarlakshmipathy@gmail.com',
            'consent_given': True
        },
        {
            'full_name': 'John Doe',
            'email': 'john.doe@example.com',
            'phone_number': '+1 555 123 4567',
            'google_name': 'John Doe',
            'google_email': 'john.doe@gmail.com',
            'consent_given': True
        },
        {
            'full_name': 'Jane Smith',
            'email': 'jane.smith@example.com',
            'phone_number': '+44 20 1234 5678',
            'google_name': 'Jane Smith',
            'google_email': 'jane.smith@gmail.com',
            'consent_given': True
        }
    ]
    
    for candidate_data in test_candidates:
        # Check if candidate already exists
        existing = Candidate.query.filter_by(email=candidate_data['email']).first()
        if not existing:
            candidate = Candidate(**candidate_data)
            db.session.add(candidate)
            print(f"   ✅ Added candidate: {candidate_data['full_name']}")
        else:
            print(f"   ⏭️  Skipped (already exists): {candidate_data['full_name']}")
    
    db.session.commit()


def show_help():
    """Show help information"""
    print("""
Video Resume Application - Database Initialization

Usage:
    python init_db.py [options]

Options:
    --reset         Drop all existing tables before creating new ones
    --test-data     Add sample test data to the database
    --help          Show this help message

Examples:
    python init_db.py                    # Initialize database
    python init_db.py --reset            # Reset and initialize
    python init_db.py --test-data        # Initialize with test data
    python init_db.py --reset --test-data # Reset and add test data
    """)


if __name__ == '__main__':
    if '--help' in sys.argv:
        show_help()
    else:
        init_database()
