"""
Configuration file for Video Resume Application
"""
import os

class Config:
    """Base configuration"""
    
    # Application settings
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    DEBUG = os.environ.get('DEBUG', 'True').lower() == 'true'
    
    # Database settings
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///video_resumes.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Upload settings
    UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER') or 'uploads/videos'
    MAX_CONTENT_LENGTH = 100 * 1024 * 1024  # 100 MB
    ALLOWED_EXTENSIONS = {'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'}
    
    # Server settings
    HOST = os.environ.get('HOST', '0.0.0.0')
    PORT = int(os.environ.get('PORT', 5000))


class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True


class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    
    # Override with production database in environment
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or \
                             'postgresql://user:password@localhost/video_resumes'


# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}
