from flask import Flask, request, jsonify, render_template, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from werkzeug.utils import secure_filename
from datetime import datetime
import os
import mimetypes

app = Flask(__name__)

# Configuration
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///video_resumes.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = 'uploads/videos'
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100 MB max file size
app.config['ALLOWED_EXTENSIONS'] = {'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'}

# Ensure upload directory exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

db = SQLAlchemy(app)


# Database Models
class Candidate(db.Model):
    """Model for storing candidate information"""
    __tablename__ = 'candidates'
    
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(200), nullable=False)
    email = db.Column(db.String(200), nullable=False, unique=True)
    phone_number = db.Column(db.String(20), nullable=False)
    google_name = db.Column(db.String(200))
    google_email = db.Column(db.String(200))
    consent_given = db.Column(db.Boolean, default=False, nullable=False)
    submission_date = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationship with video resume
    video_resume = db.relationship('VideoResume', backref='candidate', uselist=False, cascade='all, delete-orphan')
    
    def to_dict(self):
        """Convert candidate object to dictionary"""
        return {
            'id': self.id,
            'full_name': self.full_name,
            'email': self.email,
            'phone_number': self.phone_number,
            'google_name': self.google_name,
            'google_email': self.google_email,
            'consent_given': self.consent_given,
            'submission_date': self.submission_date.isoformat(),
            'video_resume': self.video_resume.to_dict() if self.video_resume else None
        }


class VideoResume(db.Model):
    """Model for storing video resume information"""
    __tablename__ = 'video_resumes'
    
    id = db.Column(db.Integer, primary_key=True)
    candidate_id = db.Column(db.Integer, db.ForeignKey('candidates.id'), nullable=False)
    filename = db.Column(db.String(300), nullable=False)
    original_filename = db.Column(db.String(300), nullable=False)
    file_path = db.Column(db.String(500), nullable=False)
    file_size = db.Column(db.Integer)  # in bytes
    file_type = db.Column(db.String(50))
    upload_date = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    
    # Video metadata
    duration = db.Column(db.Float)  # in seconds
    
    def to_dict(self):
        """Convert video resume object to dictionary"""
        return {
            'id': self.id,
            'candidate_id': self.candidate_id,
            'filename': self.filename,
            'original_filename': self.original_filename,
            'file_size': self.file_size,
            'file_type': self.file_type,
            'upload_date': self.upload_date.isoformat(),
            'duration': self.duration
        }


# Helper Functions
def allowed_file(filename):
    """Check if the file extension is allowed"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']


def get_file_size(file):
    """Get file size in bytes"""
    file.seek(0, os.SEEK_END)
    size = file.tell()
    file.seek(0)
    return size


# API Routes
@app.route('/')
def index():
    """Home page with submission form"""
    return render_template('index.html')


@app.route('/api/submit', methods=['POST'])
def submit_video_resume():
    """
    Submit a video resume with candidate information
    
    Expected form data:
    - full_name: Candidate's full name
    - email: Email address
    - phone_number: Phone number
    - google_name: Google account name (optional)
    - google_email: Google account email (optional)
    - consent: Consent checkbox (must be 'true' or '1')
    - video: Video file
    """
    try:
        # Validate required fields
        required_fields = ['full_name', 'email', 'phone_number', 'consent']
        for field in required_fields:
            if field not in request.form:
                return jsonify({
                    'success': False,
                    'error': f'Missing required field: {field}'
                }), 400
        
        # Check consent
        consent = request.form.get('consent', '').lower() in ['true', '1', 'on', 'yes']
        if not consent:
            return jsonify({
                'success': False,
                'error': 'Consent must be given to submit'
            }), 400
        
        # Check if video file is present
        if 'video' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No video file provided'
            }), 400
        
        video_file = request.files['video']
        
        # Check if file is selected
        if video_file.filename == '':
            return jsonify({
                'success': False,
                'error': 'No video file selected'
            }), 400
        
        # Validate file type
        if not allowed_file(video_file.filename):
            return jsonify({
                'success': False,
                'error': f'Invalid file type. Allowed types: {", ".join(app.config["ALLOWED_EXTENSIONS"])}'
            }), 400
        
        # Check if candidate already exists
        email = request.form.get('email')
        existing_candidate = Candidate.query.filter_by(email=email).first()
        if existing_candidate:
            return jsonify({
                'success': False,
                'error': 'A submission with this email already exists'
            }), 400
        
        # Get file size
        file_size = get_file_size(video_file)
        
        # Create secure filename with timestamp
        original_filename = secure_filename(video_file.filename)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"{timestamp}_{original_filename}"
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        # Save video file
        video_file.save(file_path)
        
        # Create candidate record
        candidate = Candidate(
            full_name=request.form.get('full_name'),
            email=email,
            phone_number=request.form.get('phone_number'),
            google_name=request.form.get('google_name', ''),
            google_email=request.form.get('google_email', ''),
            consent_given=consent
        )
        
        db.session.add(candidate)
        db.session.flush()  # Get candidate ID before committing
        
        # Create video resume record
        video_resume = VideoResume(
            candidate_id=candidate.id,
            filename=filename,
            original_filename=original_filename,
            file_path=file_path,
            file_size=file_size,
            file_type=mimetypes.guess_type(original_filename)[0] or 'video/unknown'
        )
        
        db.session.add(video_resume)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Video resume submitted successfully',
            'data': candidate.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': f'An error occurred: {str(e)}'
        }), 500


@app.route('/api/candidates', methods=['GET'])
def get_candidates():
    """Get all candidates"""
    try:
        candidates = Candidate.query.order_by(Candidate.submission_date.desc()).all()
        return jsonify({
            'success': True,
            'count': len(candidates),
            'data': [candidate.to_dict() for candidate in candidates]
        }), 200
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'An error occurred: {str(e)}'
        }), 500


@app.route('/api/candidates/<int:candidate_id>', methods=['GET'])
def get_candidate(candidate_id):
    """Get a specific candidate by ID"""
    try:
        candidate = Candidate.query.get(candidate_id)
        if not candidate:
            return jsonify({
                'success': False,
                'error': 'Candidate not found'
            }), 404
        
        return jsonify({
            'success': True,
            'data': candidate.to_dict()
        }), 200
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'An error occurred: {str(e)}'
        }), 500


@app.route('/api/video/<int:video_id>', methods=['GET'])
def get_video(video_id):
    """Stream or download a video file"""
    try:
        video_resume = VideoResume.query.get(video_id)
        if not video_resume:
            return jsonify({
                'success': False,
                'error': 'Video not found'
            }), 404
        
        directory = os.path.dirname(video_resume.file_path)
        filename = os.path.basename(video_resume.file_path)
        
        return send_from_directory(
            directory,
            filename,
            as_attachment=request.args.get('download', 'false').lower() == 'true',
            download_name=video_resume.original_filename
        )
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'An error occurred: {str(e)}'
        }), 500


@app.route('/api/candidates/<int:candidate_id>', methods=['DELETE'])
def delete_candidate(candidate_id):
    """Delete a candidate and their video resume"""
    try:
        candidate = Candidate.query.get(candidate_id)
        if not candidate:
            return jsonify({
                'success': False,
                'error': 'Candidate not found'
            }), 404
        
        # Delete video file if exists
        if candidate.video_resume and os.path.exists(candidate.video_resume.file_path):
            os.remove(candidate.video_resume.file_path)
        
        # Delete from database (cascade will handle video_resume)
        db.session.delete(candidate)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Candidate deleted successfully'
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({
            'success': False,
            'error': f'An error occurred: {str(e)}'
        }), 500


@app.route('/admin')
def admin_dashboard():
    """Admin dashboard to view all submissions"""
    return render_template('admin.html')


# Database initialization
def init_db():
    """Initialize the database"""
    with app.app_context():
        db.create_all()
        print("Database initialized successfully!")


if __name__ == '__main__':
    # Initialize database
    init_db()
    
    # Run the application
    app.run(host='0.0.0.0', port=5000, debug=True)
