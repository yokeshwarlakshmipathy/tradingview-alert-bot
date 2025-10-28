# Video Resume Application - Nohitatu Technologies

A professional web application for collecting and managing video resume submissions from job candidates.

## Features

### For Candidates
- ✨ Clean, professional submission form
- 📹 Video upload support (MP4, AVI, MOV, WMV, FLV, MKV, WebM)
- 📊 File size validation (max 100 MB)
- ✅ Consent tracking for GDPR compliance
- 📱 Responsive design for mobile and desktop
- 🔒 Secure file handling

### For Recruiters/Admins
- 📋 Admin dashboard to view all submissions
- 👁️ Preview videos directly in the browser
- ⬇️ Download video resumes
- 🔍 Search and filter candidates
- 📊 Statistics and metrics
- 🗑️ Delete submissions
- 📱 Mobile-friendly admin interface

## Technology Stack

- **Backend**: Flask (Python)
- **Database**: SQLite (easily upgradeable to PostgreSQL)
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **File Storage**: Local filesystem (configurable)
- **ORM**: SQLAlchemy

## Installation

### Prerequisites
- Python 3.8 or higher
- pip (Python package manager)

### Setup Instructions

1. **Clone or navigate to the project directory**
   ```bash
   cd /workspace
   ```

2. **Create a virtual environment (recommended)**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Initialize the database**
   ```bash
   python video_resume_app.py
   ```
   This will automatically create the database and tables on first run.

5. **Run the application**
   ```bash
   python video_resume_app.py
   ```

6. **Access the application**
   - Candidate submission form: http://localhost:5000/
   - Admin dashboard: http://localhost:5000/admin

## Project Structure

```
/workspace/
├── video_resume_app.py          # Main Flask application
├── config.py                    # Configuration settings
├── requirements.txt             # Python dependencies
├── templates/                   # HTML templates
│   ├── index.html              # Candidate submission form
│   └── admin.html              # Admin dashboard
├── static/                      # Static assets
│   ├── css/
│   │   └── style.css           # Application styles
│   └── js/
│       ├── script.js           # Form submission logic
│       └── admin.js            # Admin dashboard logic
├── uploads/                     # Video file storage
│   └── videos/                 # Uploaded video files
└── video_resumes.db            # SQLite database (created on first run)
```

## API Endpoints

### Public Endpoints

#### `POST /api/submit`
Submit a video resume with candidate information.

**Form Data:**
- `full_name` (required): Candidate's full name
- `email` (required): Email address
- `phone_number` (required): Phone number
- `google_name` (optional): Google account name
- `google_email` (optional): Google account email
- `consent` (required): Must be 'true' or '1'
- `video` (required): Video file

**Response:**
```json
{
  "success": true,
  "message": "Video resume submitted successfully",
  "data": {
    "id": 1,
    "full_name": "John Doe",
    "email": "john@example.com",
    ...
  }
}
```

### Admin Endpoints

#### `GET /api/candidates`
Get all candidate submissions.

**Response:**
```json
{
  "success": true,
  "count": 10,
  "data": [...]
}
```

#### `GET /api/candidates/<id>`
Get a specific candidate by ID.

#### `GET /api/video/<id>`
Stream or download a video file.

**Query Parameters:**
- `download`: Set to 'true' to download instead of stream

#### `DELETE /api/candidates/<id>`
Delete a candidate and their video resume.

## Configuration

Edit `config.py` to customize settings:

```python
# Database
SQLALCHEMY_DATABASE_URI = 'sqlite:///video_resumes.db'

# Upload settings
UPLOAD_FOLDER = 'uploads/videos'
MAX_CONTENT_LENGTH = 100 * 1024 * 1024  # 100 MB
ALLOWED_EXTENSIONS = {'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'}
```

### Environment Variables

You can override configuration using environment variables:

- `SECRET_KEY`: Flask secret key
- `DEBUG`: Enable/disable debug mode
- `DATABASE_URL`: Database connection string
- `UPLOAD_FOLDER`: Path for uploaded files
- `HOST`: Server host (default: 0.0.0.0)
- `PORT`: Server port (default: 5000)

## Database Schema

### Candidates Table
- `id`: Primary key
- `full_name`: Candidate's full name
- `email`: Email address (unique)
- `phone_number`: Phone number
- `google_name`: Google account name
- `google_email`: Google account email
- `consent_given`: Boolean for consent
- `submission_date`: Timestamp of submission

### Video Resumes Table
- `id`: Primary key
- `candidate_id`: Foreign key to candidates
- `filename`: Stored filename
- `original_filename`: Original upload filename
- `file_path`: Full path to file
- `file_size`: File size in bytes
- `file_type`: MIME type
- `upload_date`: Upload timestamp
- `duration`: Video duration in seconds

## Security Considerations

1. **File Validation**: Only allowed video formats are accepted
2. **File Size Limits**: Maximum 100 MB per upload
3. **Filename Sanitization**: Filenames are sanitized to prevent directory traversal
4. **Email Uniqueness**: Prevents duplicate submissions
5. **Consent Tracking**: GDPR-compliant consent management

## Production Deployment

### Using Gunicorn

1. Install Gunicorn:
   ```bash
   pip install gunicorn
   ```

2. Run with Gunicorn:
   ```bash
   gunicorn -w 4 -b 0.0.0.0:5000 video_resume_app:app
   ```

### Using PostgreSQL

1. Update `config.py`:
   ```python
   SQLALCHEMY_DATABASE_URI = 'postgresql://user:password@localhost/video_resumes'
   ```

2. Install PostgreSQL adapter:
   ```bash
   pip install psycopg2-binary
   ```

### Nginx Configuration

Example Nginx configuration for reverse proxy:

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    client_max_body_size 100M;
}
```

## Video Resume Instructions for Candidates

Candidates are asked to record a 1-minute video covering:

1. **Introduction**: Name, background, and area of expertise
2. **Motivation**: Why they want to join Nohitatu Technologies
3. **Skills**: Top skills or experiences relevant to the position
4. **Achievement**: One achievement they're most proud of
5. **Unique Factor**: Something unique about themselves

### Recording Guidelines

- Professional attire
- Good lighting
- Clear background
- Clear audio quality
- Can use phone, laptop, or webcam

## Troubleshooting

### Database Issues
```bash
# Reset database (WARNING: deletes all data)
rm video_resumes.db
python video_resume_app.py
```

### Upload Folder Permissions
```bash
mkdir -p uploads/videos
chmod 755 uploads/videos
```

### Port Already in Use
```bash
# Change port in config.py or use environment variable
PORT=8000 python video_resume_app.py
```

## Future Enhancements

- [ ] Email notifications on submission
- [ ] Video transcription using AI
- [ ] Automated candidate scoring
- [ ] Integration with ATS systems
- [ ] Cloud storage (AWS S3, Google Cloud Storage)
- [ ] Video compression and optimization
- [ ] Multi-language support
- [ ] Advanced search and filtering
- [ ] Export to CSV/Excel
- [ ] Candidate status tracking

## Support

For issues or questions, please contact:
- Email: support@nohitatu.com
- GitHub Issues: [Create an issue]

## License

Copyright © 2025 Nohitatu Technologies. All rights reserved.

---

**Made with ❤️ for better recruitment processes**
