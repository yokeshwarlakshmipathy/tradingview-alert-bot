// Video Resume Submission Form Handler

document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('videoResumeForm');
    const videoInput = document.getElementById('videoFile');
    const fileInfo = document.getElementById('fileInfo');
    const statusMessage = document.getElementById('statusMessage');
    const submitBtn = document.getElementById('submitBtn');

    // File size formatter
    function formatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }

    // Show file information when selected
    videoInput.addEventListener('change', function(e) {
        const file = e.target.files[0];
        
        if (file) {
            const fileSize = formatFileSize(file.size);
            const fileName = file.name;
            const fileType = file.type;
            
            // Check file size (100 MB = 104857600 bytes)
            if (file.size > 104857600) {
                showStatus('File size exceeds 100 MB limit. Please choose a smaller file.', 'error');
                videoInput.value = '';
                fileInfo.classList.remove('active');
                return;
            }
            
            // Validate file type
            const validTypes = ['video/mp4', 'video/avi', 'video/quicktime', 'video/x-ms-wmv', 
                              'video/x-flv', 'video/x-matroska', 'video/webm'];
            const validExtensions = ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.mkv', '.webm'];
            
            const hasValidType = validTypes.some(type => fileType.includes(type));
            const hasValidExtension = validExtensions.some(ext => fileName.toLowerCase().endsWith(ext));
            
            if (!hasValidType && !hasValidExtension) {
                showStatus('Invalid file type. Please upload a video file.', 'error');
                videoInput.value = '';
                fileInfo.classList.remove('active');
                return;
            }
            
            fileInfo.innerHTML = `
                <strong>📹 Selected File:</strong><br>
                <strong>Name:</strong> ${fileName}<br>
                <strong>Size:</strong> ${fileSize}<br>
                <strong>Type:</strong> ${fileType || 'Unknown'}
            `;
            fileInfo.classList.add('active');
            hideStatus();
        } else {
            fileInfo.classList.remove('active');
        }
    });

    // Form submission
    form.addEventListener('submit', async function(e) {
        e.preventDefault();
        
        // Validate form
        if (!form.checkValidity()) {
            showStatus('Please fill in all required fields.', 'error');
            return;
        }
        
        // Check consent
        const consent = document.getElementById('consent').checked;
        if (!consent) {
            showStatus('You must provide consent to submit the form.', 'error');
            return;
        }
        
        // Check video file
        const videoFile = videoInput.files[0];
        if (!videoFile) {
            showStatus('Please select a video file.', 'error');
            return;
        }
        
        // Disable submit button and show loading
        submitBtn.disabled = true;
        submitBtn.textContent = 'Uploading...';
        showStatus('Uploading your video resume... Please wait.', 'info');
        
        // Prepare form data
        const formData = new FormData();
        formData.append('full_name', document.getElementById('fullName').value);
        formData.append('email', document.getElementById('email').value);
        formData.append('phone_number', document.getElementById('phone').value);
        formData.append('google_name', document.getElementById('googleName').value);
        formData.append('google_email', document.getElementById('googleEmail').value);
        formData.append('consent', consent ? 'true' : 'false');
        formData.append('video', videoFile);
        
        try {
            // Submit form
            const response = await fetch('/api/submit', {
                method: 'POST',
                body: formData
            });
            
            const result = await response.json();
            
            if (response.ok && result.success) {
                showStatus('✅ Success! Your video resume has been submitted successfully. Thank you!', 'success');
                form.reset();
                fileInfo.classList.remove('active');
                
                // Scroll to top to show success message
                window.scrollTo({ top: 0, behavior: 'smooth' });
            } else {
                showStatus(`❌ Error: ${result.error || 'Failed to submit. Please try again.'}`, 'error');
            }
        } catch (error) {
            console.error('Submission error:', error);
            showStatus('❌ An error occurred while submitting. Please check your internet connection and try again.', 'error');
        } finally {
            // Re-enable submit button
            submitBtn.disabled = false;
            submitBtn.textContent = 'Submit Video Resume';
        }
    });

    // Status message helpers
    function showStatus(message, type) {
        statusMessage.textContent = message;
        statusMessage.className = 'status-message active ' + type;
    }

    function hideStatus() {
        statusMessage.className = 'status-message';
    }
});
