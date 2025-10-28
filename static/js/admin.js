// Admin Dashboard JavaScript

document.addEventListener('DOMContentLoaded', function() {
    const tableBody = document.getElementById('candidatesTableBody');
    const refreshBtn = document.getElementById('refreshBtn');
    const searchInput = document.getElementById('searchInput');
    const statusMessage = document.getElementById('adminStatusMessage');
    const modal = document.getElementById('videoModal');
    const closeModal = document.querySelector('.close');
    
    let allCandidates = [];

    // Load candidates on page load
    loadCandidates();

    // Refresh button click
    refreshBtn.addEventListener('click', function() {
        loadCandidates();
    });

    // Search functionality
    searchInput.addEventListener('input', function(e) {
        const searchTerm = e.target.value.toLowerCase();
        filterCandidates(searchTerm);
    });

    // Close modal
    closeModal.addEventListener('click', function() {
        modal.classList.remove('active');
    });

    window.addEventListener('click', function(e) {
        if (e.target === modal) {
            modal.classList.remove('active');
        }
    });

    // Load all candidates
    async function loadCandidates() {
        try {
            refreshBtn.disabled = true;
            refreshBtn.textContent = '⏳ Loading...';
            tableBody.innerHTML = '<tr><td colspan="7" class="loading">Loading candidates...</td></tr>';

            const response = await fetch('/api/candidates');
            const result = await response.json();

            if (response.ok && result.success) {
                allCandidates = result.data;
                updateStats();
                displayCandidates(allCandidates);
                
                if (allCandidates.length === 0) {
                    showStatus('No submissions yet.', 'info');
                } else {
                    hideStatus();
                }
            } else {
                throw new Error(result.error || 'Failed to load candidates');
            }
        } catch (error) {
            console.error('Error loading candidates:', error);
            showStatus('Failed to load candidates: ' + error.message, 'error');
            tableBody.innerHTML = '<tr><td colspan="7" class="loading">Error loading data</td></tr>';
        } finally {
            refreshBtn.disabled = false;
            refreshBtn.textContent = '🔄 Refresh';
        }
    }

    // Update statistics
    function updateStats() {
        document.getElementById('totalSubmissions').textContent = allCandidates.length;
        
        if (allCandidates.length > 0) {
            const latest = allCandidates[0];
            const date = new Date(latest.submission_date);
            document.getElementById('latestSubmission').textContent = 
                `${latest.full_name} - ${date.toLocaleDateString()}`;
        }
    }

    // Display candidates in table
    function displayCandidates(candidates) {
        if (candidates.length === 0) {
            tableBody.innerHTML = '<tr><td colspan="7" class="loading">No candidates found</td></tr>';
            return;
        }

        tableBody.innerHTML = candidates.map(candidate => {
            const date = new Date(candidate.submission_date);
            const formattedDate = date.toLocaleString();
            
            const videoInfo = candidate.video_resume 
                ? `${formatFileSize(candidate.video_resume.file_size)}<br>${candidate.video_resume.file_type}`
                : 'No video';

            return `
                <tr>
                    <td>${candidate.id}</td>
                    <td>${escapeHtml(candidate.full_name)}</td>
                    <td>${escapeHtml(candidate.email)}</td>
                    <td>${escapeHtml(candidate.phone_number)}</td>
                    <td>${formattedDate}</td>
                    <td>${videoInfo}</td>
                    <td>
                        <div class="action-buttons">
                            ${candidate.video_resume ? 
                                `<button class="btn btn-success" onclick="viewCandidate(${candidate.id})">👁️ View</button>
                                 <button class="btn btn-success" onclick="downloadVideo(${candidate.video_resume.id})">⬇️ Download</button>` 
                                : ''}
                            <button class="btn btn-danger" onclick="deleteCandidate(${candidate.id})">🗑️ Delete</button>
                        </div>
                    </td>
                </tr>
            `;
        }).join('');
    }

    // Filter candidates based on search
    function filterCandidates(searchTerm) {
        if (!searchTerm) {
            displayCandidates(allCandidates);
            return;
        }

        const filtered = allCandidates.filter(candidate => 
            candidate.full_name.toLowerCase().includes(searchTerm) ||
            candidate.email.toLowerCase().includes(searchTerm) ||
            candidate.phone_number.includes(searchTerm)
        );

        displayCandidates(filtered);
    }

    // View candidate details and video
    window.viewCandidate = async function(candidateId) {
        try {
            const candidate = allCandidates.find(c => c.id === candidateId);
            if (!candidate) return;

            document.getElementById('modalCandidateName').textContent = candidate.full_name;
            
            // Display video
            if (candidate.video_resume) {
                const videoContainer = document.getElementById('videoContainer');
                videoContainer.innerHTML = `
                    <video controls>
                        <source src="/api/video/${candidate.video_resume.id}" type="${candidate.video_resume.file_type}">
                        Your browser does not support the video tag.
                    </video>
                `;
            }

            // Display candidate details
            const detailsContainer = document.getElementById('candidateDetails');
            const uploadDate = new Date(candidate.submission_date);
            
            detailsContainer.innerHTML = `
                <h3>Candidate Details</h3>
                <p><strong>Email:</strong> ${escapeHtml(candidate.email)}</p>
                <p><strong>Phone:</strong> ${escapeHtml(candidate.phone_number)}</p>
                ${candidate.google_name ? `<p><strong>Google Name:</strong> ${escapeHtml(candidate.google_name)}</p>` : ''}
                ${candidate.google_email ? `<p><strong>Google Email:</strong> ${escapeHtml(candidate.google_email)}</p>` : ''}
                <p><strong>Submission Date:</strong> ${uploadDate.toLocaleString()}</p>
                <p><strong>Consent Given:</strong> ${candidate.consent_given ? '✅ Yes' : '❌ No'}</p>
                ${candidate.video_resume ? `
                    <h3 style="margin-top: 20px;">Video Details</h3>
                    <p><strong>Filename:</strong> ${escapeHtml(candidate.video_resume.original_filename)}</p>
                    <p><strong>File Size:</strong> ${formatFileSize(candidate.video_resume.file_size)}</p>
                    <p><strong>Upload Date:</strong> ${new Date(candidate.video_resume.upload_date).toLocaleString()}</p>
                ` : ''}
            `;

            modal.classList.add('active');
        } catch (error) {
            console.error('Error viewing candidate:', error);
            showStatus('Failed to load candidate details', 'error');
        }
    };

    // Download video
    window.downloadVideo = function(videoId) {
        window.location.href = `/api/video/${videoId}?download=true`;
    };

    // Delete candidate
    window.deleteCandidate = async function(candidateId) {
        const candidate = allCandidates.find(c => c.id === candidateId);
        if (!candidate) return;

        if (!confirm(`Are you sure you want to delete ${candidate.full_name}'s submission? This action cannot be undone.`)) {
            return;
        }

        try {
            const response = await fetch(`/api/candidates/${candidateId}`, {
                method: 'DELETE'
            });

            const result = await response.json();

            if (response.ok && result.success) {
                showStatus('Candidate deleted successfully', 'success');
                loadCandidates();
            } else {
                throw new Error(result.error || 'Failed to delete candidate');
            }
        } catch (error) {
            console.error('Error deleting candidate:', error);
            showStatus('Failed to delete candidate: ' + error.message, 'error');
        }
    };

    // Helper functions
    function formatFileSize(bytes) {
        if (!bytes) return 'Unknown';
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
    }

    function escapeHtml(text) {
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        return text.replace(/[&<>"']/g, m => map[m]);
    }

    function showStatus(message, type) {
        statusMessage.textContent = message;
        statusMessage.className = 'status-message active ' + type;
        
        if (type === 'success') {
            setTimeout(() => hideStatus(), 5000);
        }
    }

    function hideStatus() {
        statusMessage.className = 'status-message';
    }
});
