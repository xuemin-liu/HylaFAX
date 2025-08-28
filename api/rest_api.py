#!/usr/bin/env python3
"""
REST API wrapper for HylaFAX
Provides HTTP endpoints for sending faxes and checking status
"""

from flask import Flask, request, jsonify, send_file
from werkzeug.utils import secure_filename
import os
import tempfile
import logging
from typing import Dict, List, Any
import uuid
from pyfax import PyFaxAPI, QueueType

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Configuration
HYLAFAX_HOST = os.environ.get('HYLAFAX_HOST', 'localhost')
UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER', '/tmp/fax_uploads')
ALLOWED_EXTENSIONS = {'pdf', 'ps', 'txt', 'tiff', 'tif'}

# Ensure upload folder exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def create_api_response(success: bool, data: Any = None, message: str = "", 
                       status_code: int = 200) -> tuple:
    """Create standardized API response"""
    response = {
        'success': success,
        'message': message,
        'data': data or {}
    }
    return jsonify(response), status_code


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if success:
                return create_api_response(True, {'status': 'healthy'}, 
                                         'HylaFAX server is reachable')
            else:
                return create_api_response(False, {'status': 'unhealthy'}, 
                                         f'Cannot connect to HylaFAX: {error}', 503)
    except Exception as e:
        return create_api_response(False, {'status': 'error'}, str(e), 500)


@app.route('/api/fax/send', methods=['POST'])
def send_fax():
    """
    Send a fax
    
    Form data:
    - files: File(s) to send
    - destinations: JSON array of destination numbers
    - options: JSON object with fax options (optional)
    """
    try:
        # Check if files were uploaded
        if 'files' not in request.files:
            return create_api_response(False, message='No files provided', status_code=400)
        
        files = request.files.getlist('files')
        if not files or all(f.filename == '' for f in files):
            return create_api_response(False, message='No files selected', status_code=400)
        
        # Get destinations
        destinations_str = request.form.get('destinations', '[]')
        try:
            import json
            destinations = json.loads(destinations_str)
        except json.JSONDecodeError:
            return create_api_response(False, message='Invalid destinations format', status_code=400)
        
        if not destinations:
            return create_api_response(False, message='No destinations specified', status_code=400)
        
        # Get options
        options_str = request.form.get('options', '{}')
        try:
            options = json.loads(options_str)
        except json.JSONDecodeError:
            return create_api_response(False, message='Invalid options format', status_code=400)
        
        # Save uploaded files
        uploaded_files = []
        for file in files:
            if file and file.filename and allowed_file(file.filename):
                filename = secure_filename(file.filename)
                # Add UUID to prevent conflicts
                filename = f"{uuid.uuid4()}_{filename}"
                filepath = os.path.join(UPLOAD_FOLDER, filename)
                file.save(filepath)
                uploaded_files.append(filepath)
        
        if not uploaded_files:
            return create_api_response(False, message='No valid files uploaded', status_code=400)
        
        # Send fax
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if not success:
                return create_api_response(False, message=f'Connection failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.login()
            if not success:
                return create_api_response(False, message=f'Login failed: {error}', 
                                         status_code=503)
            
            result = fax_api.send_fax(uploaded_files, destinations, options)
            
            # Clean up uploaded files
            for filepath in uploaded_files:
                try:
                    os.unlink(filepath)
                except OSError:
                    pass
            
            if result['success']:
                return create_api_response(True, {
                    'job_id': result['job_id'],
                    'group_id': result['group_id'],
                    'total_pages': result['total_pages']
                }, 'Fax submitted successfully')
            else:
                return create_api_response(False, message=result['error'], status_code=400)
    
    except Exception as e:
        logger.exception("Error in send_fax")
        return create_api_response(False, message=str(e), status_code=500)


@app.route('/api/fax/status', methods=['GET'])
def get_fax_status():
    """
    Get fax status
    
    Query parameters:
    - queue: Queue type (send, done, recv, archive, document, server)
    """
    try:
        queue_param = request.args.get('queue', 'send').lower()
        
        queue_mapping = {
            'send': QueueType.SEND_QUEUE,
            'done': QueueType.DONE_QUEUE,
            'recv': QueueType.RECV_QUEUE,
            'archive': QueueType.ARCHIVE_QUEUE,
            'document': QueueType.DOCUMENT_QUEUE,
            'server': QueueType.SERVER_STATUS
        }
        
        if queue_param not in queue_mapping:
            return create_api_response(False, message='Invalid queue type', status_code=400)
        
        queue_type = queue_mapping[queue_param]
        
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if not success:
                return create_api_response(False, message=f'Connection failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.login()
            if not success:
                return create_api_response(False, message=f'Login failed: {error}', 
                                         status_code=503)
            
            jobs = fax_api.get_job_status(queue_type)
            
            return create_api_response(True, {
                'queue': queue_param,
                'jobs': jobs,
                'count': len(jobs)
            }, f'Retrieved {len(jobs)} jobs from {queue_param} queue')
    
    except Exception as e:
        logger.exception("Error in get_fax_status")
        return create_api_response(False, message=str(e), status_code=500)


@app.route('/api/fax/job/<job_id>', methods=['GET'])
def get_job_info(job_id):
    """Get information about a specific job"""
    try:
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if not success:
                return create_api_response(False, message=f'Connection failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.login()
            if not success:
                return create_api_response(False, message=f'Login failed: {error}', 
                                         status_code=503)
            
            # Search for job in all queues
            job_info = None
            for queue_type in [QueueType.SEND_QUEUE, QueueType.DONE_QUEUE, QueueType.ARCHIVE_QUEUE]:
                jobs = fax_api.get_job_status(queue_type)
                for job in jobs:
                    if job['job_id'] == job_id:
                        job_info = job
                        job_info['queue'] = queue_type.name.lower()
                        break
                if job_info:
                    break
            
            if job_info:
                return create_api_response(True, job_info, 'Job found')
            else:
                return create_api_response(False, message='Job not found', status_code=404)
    
    except Exception as e:
        logger.exception("Error in get_job_info")
        return create_api_response(False, message=str(e), status_code=500)


@app.route('/api/fax/job/<job_id>/kill', methods=['POST'])
def kill_job(job_id):
    """Kill a fax job"""
    try:
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if not success:
                return create_api_response(False, message=f'Connection failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.login()
            if not success:
                return create_api_response(False, message=f'Login failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.kill_job(job_id)
            
            if success:
                return create_api_response(True, {'job_id': job_id}, 'Job killed successfully')
            else:
                return create_api_response(False, message=error, status_code=400)
    
    except Exception as e:
        logger.exception("Error in kill_job")
        return create_api_response(False, message=str(e), status_code=500)


@app.route('/api/fax/job/<job_id>/suspend', methods=['POST'])
def suspend_job(job_id):
    """Suspend a fax job"""
    try:
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if not success:
                return create_api_response(False, message=f'Connection failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.login()
            if not success:
                return create_api_response(False, message=f'Login failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.suspend_job(job_id)
            
            if success:
                return create_api_response(True, {'job_id': job_id}, 'Job suspended successfully')
            else:
                return create_api_response(False, message=error, status_code=400)
    
    except Exception as e:
        logger.exception("Error in suspend_job")
        return create_api_response(False, message=str(e), status_code=500)


@app.route('/api/fax/job/<job_id>/resume', methods=['POST'])
def resume_job(job_id):
    """Resume a suspended fax job"""
    try:
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if not success:
                return create_api_response(False, message=f'Connection failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.login()
            if not success:
                return create_api_response(False, message=f'Login failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.resume_job(job_id)
            
            if success:
                return create_api_response(True, {'job_id': job_id}, 'Job resumed successfully')
            else:
                return create_api_response(False, message=error, status_code=400)
    
    except Exception as e:
        logger.exception("Error in resume_job")
        return create_api_response(False, message=str(e), status_code=500)


@app.route('/api/fax/job/<job_id>/wait', methods=['POST'])
def wait_for_job(job_id):
    """Wait for a job to complete"""
    try:
        with PyFaxAPI(HYLAFAX_HOST) as fax_api:
            success, error = fax_api.connect()
            if not success:
                return create_api_response(False, message=f'Connection failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.login()
            if not success:
                return create_api_response(False, message=f'Login failed: {error}', 
                                         status_code=503)
            
            success, error = fax_api.wait_for_job(job_id)
            
            if success:
                return create_api_response(True, {'job_id': job_id}, 'Job completed successfully')
            else:
                return create_api_response(False, message=error, status_code=400)
    
    except Exception as e:
        logger.exception("Error in wait_for_job")
        return create_api_response(False, message=str(e), status_code=500)


@app.errorhandler(413)
def too_large(e):
    return create_api_response(False, message='File too large', status_code=413)


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'False').lower() == 'true'
    
    logger.info(f"Starting HylaFAX REST API on port {port}")
    logger.info(f"HylaFAX Host: {HYLAFAX_HOST}")
    logger.info(f"Upload folder: {UPLOAD_FOLDER}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)
