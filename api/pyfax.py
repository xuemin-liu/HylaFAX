#!/usr/bin/env python3
"""
Python wrapper for HylaFAX API
Provides Python bindings for sending faxes and checking status
"""

import ctypes
import os
from ctypes import Structure, c_char_p, c_int, c_bool, c_float, POINTER
from typing import List, Dict, Optional, Tuple
from enum import Enum


class QueueType(Enum):
    SEND_QUEUE = 0
    DONE_QUEUE = 1
    RECV_QUEUE = 2
    ARCHIVE_QUEUE = 3
    DOCUMENT_QUEUE = 4
    SERVER_STATUS = 5


class FaxSendOptions(Structure):
    """C structure mapping for FaxSendOptions"""
    _fields_ = [
        ("recipient", c_char_p),
        ("dialString", c_char_p),
        ("subAddress", c_char_p),
        ("coverComments", c_char_p),
        ("coverRegarding", c_char_p),
        ("coverFromVoice", c_char_p),
        ("coverFromFax", c_char_p),
        ("coverFromCompany", c_char_p),
        ("coverFromLocation", c_char_p),
        ("coverTemplate", c_char_p),
        ("tagLineFormat", c_char_p),
        ("jobTag", c_char_p),
        ("tsi", c_char_p),
        ("sendTime", c_char_p),
        ("killTime", c_char_p),
        ("retryTime", c_char_p),
        ("pageSize", c_char_p),
        ("notification", c_char_p),
        ("priority", c_char_p),
        ("vResolution", c_float),
        ("maxRetries", c_int),
        ("maxDials", c_int),
        ("autoCoverPage", c_bool),
        ("useECM", c_bool),
        ("useXVRes", c_bool),
        ("archive", c_bool),
        ("desiredSpeed", c_int),
        ("minSpeed", c_int),
        ("desiredDataFormat", c_int),
    ]


class FaxSubmissionResult(Structure):
    """C structure mapping for FaxSubmissionResult"""
    _fields_ = [
        ("success", c_bool),
        ("jobId", c_char_p),
        ("groupId", c_char_p),
        ("errorMessage", c_char_p),
        ("totalPages", c_int),
    ]


class FaxJobInfo(Structure):
    """C structure mapping for FaxJobInfo"""
    _fields_ = [
        ("jobId", c_char_p),
        ("state", c_char_p),
        ("pages", c_char_p),
        ("dials", c_char_p),
        ("tts", c_char_p),
        ("sender", c_char_p),
        ("number", c_char_p),
        ("modem", c_char_p),
        ("tag", c_char_p),
        ("status", c_char_p),
        ("fileName", c_char_p),
        ("received", c_char_p),
    ]


class PyFaxAPI:
    """Python wrapper for HylaFAX API"""
    
    def __init__(self, host: str = "localhost", lib_path: str = None):
        """
        Initialize the HylaFAX API wrapper
        
        Args:
            host: HylaFAX server hostname
            lib_path: Path to libfaxapi shared library
        """
        self.host = host
        
        # Load the shared library
        if lib_path is None:
            lib_path = self._find_library()
        
        self.lib = ctypes.CDLL(lib_path)
        self._setup_function_signatures()
        
        # Create API instance
        self.api_instance = self.lib.fax_api_create(host.encode('utf-8'))
        self.connected = False
        self.logged_in = False
    
    def _find_library(self) -> str:
        """Find the libfaxapi shared library"""
        possible_paths = [
            "./libfaxapi.so",
            "/usr/local/lib/libfaxapi.so",
            "/usr/lib/libfaxapi.so",
            "../api/libfaxapi.so"
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        raise FileNotFoundError("Could not find libfaxapi shared library")
    
    def _setup_function_signatures(self):
        """Setup C function signatures for ctypes"""
        # FaxAPI creation/destruction
        self.lib.fax_api_create.argtypes = [c_char_p]
        self.lib.fax_api_create.restype = ctypes.c_void_p
        
        self.lib.fax_api_destroy.argtypes = [ctypes.c_void_p]
        self.lib.fax_api_destroy.restype = None
        
        # Connection methods
        self.lib.fax_api_connect.argtypes = [ctypes.c_void_p, c_char_p]
        self.lib.fax_api_connect.restype = c_bool
        
        self.lib.fax_api_disconnect.argtypes = [ctypes.c_void_p]
        self.lib.fax_api_disconnect.restype = c_bool
        
        self.lib.fax_api_login.argtypes = [ctypes.c_void_p, c_char_p, c_char_p]
        self.lib.fax_api_login.restype = c_bool
        
        # Fax sending
        self.lib.fax_api_send_fax.argtypes = [
            ctypes.c_void_p,  # api instance
            POINTER(c_char_p),  # files array
            c_int,  # files count
            POINTER(c_char_p),  # destinations array
            c_int,  # destinations count
            POINTER(FaxSendOptions),  # options
            POINTER(FaxSubmissionResult)  # result
        ]
        self.lib.fax_api_send_fax.restype = c_bool
        
        # Status checking
        self.lib.fax_api_get_job_status.argtypes = [
            ctypes.c_void_p,  # api instance
            c_int,  # queue type
            POINTER(FaxJobInfo),  # jobs array
            POINTER(c_int)  # jobs count
        ]
        self.lib.fax_api_get_job_status.restype = c_bool
        
        # Job management
        self.lib.fax_api_kill_job.argtypes = [ctypes.c_void_p, c_char_p, c_char_p]
        self.lib.fax_api_kill_job.restype = c_bool
        
        self.lib.fax_api_suspend_job.argtypes = [ctypes.c_void_p, c_char_p, c_char_p]
        self.lib.fax_api_suspend_job.restype = c_bool
        
        self.lib.fax_api_resume_job.argtypes = [ctypes.c_void_p, c_char_p, c_char_p]
        self.lib.fax_api_resume_job.restype = c_bool
        
        self.lib.fax_api_wait_for_job.argtypes = [ctypes.c_void_p, c_char_p, c_char_p]
        self.lib.fax_api_wait_for_job.restype = c_bool
    
    def connect(self) -> Tuple[bool, str]:
        """
        Connect to HylaFAX server
        
        Returns:
            (success, error_message)
        """
        error_msg = ctypes.create_string_buffer(1024)
        success = self.lib.fax_api_connect(self.api_instance, error_msg)
        self.connected = success
        return success, error_msg.value.decode('utf-8') if error_msg.value else ""
    
    def disconnect(self) -> bool:
        """Disconnect from HylaFAX server"""
        if self.connected:
            success = self.lib.fax_api_disconnect(self.api_instance)
            self.connected = False
            self.logged_in = False
            return success
        return True
    
    def login(self, username: str = "") -> Tuple[bool, str]:
        """
        Login to HylaFAX server
        
        Args:
            username: Username (empty for current user)
            
        Returns:
            (success, error_message)
        """
        error_msg = ctypes.create_string_buffer(1024)
        success = self.lib.fax_api_login(
            self.api_instance,
            username.encode('utf-8') if username else None,
            error_msg
        )
        self.logged_in = success
        return success, error_msg.value.decode('utf-8') if error_msg.value else ""
    
    def send_fax(self, files: List[str], destinations: List[str], 
                 options: Dict = None) -> Dict:
        """
        Send a fax
        
        Args:
            files: List of file paths to send
            destinations: List of destination numbers/addresses
            options: Dictionary of fax options
            
        Returns:
            Dictionary with result information
        """
        if not self.connected or not self.logged_in:
            return {
                'success': False,
                'error': 'Not connected or logged in'
            }
        
        # Convert options to C structure
        c_options = FaxSendOptions()
        if options:
            for key, value in options.items():
                if hasattr(c_options, key):
                    if isinstance(value, str):
                        setattr(c_options, key, value.encode('utf-8'))
                    else:
                        setattr(c_options, key, value)
        
        # Convert file list to C array
        files_array = (c_char_p * len(files))()
        for i, file_path in enumerate(files):
            files_array[i] = file_path.encode('utf-8')
        
        # Convert destinations list to C array
        dest_array = (c_char_p * len(destinations))()
        for i, dest in enumerate(destinations):
            dest_array[i] = dest.encode('utf-8')
        
        # Result structure
        result = FaxSubmissionResult()
        
        # Call C function
        success = self.lib.fax_api_send_fax(
            self.api_instance,
            files_array,
            len(files),
            dest_array,
            len(destinations),
            ctypes.byref(c_options),
            ctypes.byref(result)
        )
        
        return {
            'success': success and result.success,
            'job_id': result.jobId.decode('utf-8') if result.jobId else "",
            'group_id': result.groupId.decode('utf-8') if result.groupId else "",
            'total_pages': result.totalPages,
            'error': result.errorMessage.decode('utf-8') if result.errorMessage else ""
        }
    
    def get_job_status(self, queue_type: QueueType = QueueType.SEND_QUEUE) -> List[Dict]:
        """
        Get job status information
        
        Args:
            queue_type: Type of queue to check
            
        Returns:
            List of job information dictionaries
        """
        if not self.connected or not self.logged_in:
            return []
        
        # Allocate array for results (max 1000 jobs)
        max_jobs = 1000
        jobs_array = (FaxJobInfo * max_jobs)()
        jobs_count = c_int(0)
        
        success = self.lib.fax_api_get_job_status(
            self.api_instance,
            queue_type.value,
            jobs_array,
            ctypes.byref(jobs_count)
        )
        
        if not success:
            return []
        
        # Convert C array to Python list
        jobs = []
        for i in range(jobs_count.value):
            job_info = jobs_array[i]
            jobs.append({
                'job_id': job_info.jobId.decode('utf-8') if job_info.jobId else "",
                'state': job_info.state.decode('utf-8') if job_info.state else "",
                'pages': job_info.pages.decode('utf-8') if job_info.pages else "",
                'dials': job_info.dials.decode('utf-8') if job_info.dials else "",
                'tts': job_info.tts.decode('utf-8') if job_info.tts else "",
                'sender': job_info.sender.decode('utf-8') if job_info.sender else "",
                'number': job_info.number.decode('utf-8') if job_info.number else "",
                'modem': job_info.modem.decode('utf-8') if job_info.modem else "",
                'tag': job_info.tag.decode('utf-8') if job_info.tag else "",
                'status': job_info.status.decode('utf-8') if job_info.status else "",
                'file_name': job_info.fileName.decode('utf-8') if job_info.fileName else "",
                'received': job_info.received.decode('utf-8') if job_info.received else "",
            })
        
        return jobs
    
    def kill_job(self, job_id: str) -> Tuple[bool, str]:
        """Kill a fax job"""
        error_msg = ctypes.create_string_buffer(1024)
        success = self.lib.fax_api_kill_job(
            self.api_instance,
            job_id.encode('utf-8'),
            error_msg
        )
        return success, error_msg.value.decode('utf-8') if error_msg.value else ""
    
    def suspend_job(self, job_id: str) -> Tuple[bool, str]:
        """Suspend a fax job"""
        error_msg = ctypes.create_string_buffer(1024)
        success = self.lib.fax_api_suspend_job(
            self.api_instance,
            job_id.encode('utf-8'),
            error_msg
        )
        return success, error_msg.value.decode('utf-8') if error_msg.value else ""
    
    def resume_job(self, job_id: str) -> Tuple[bool, str]:
        """Resume a suspended fax job"""
        error_msg = ctypes.create_string_buffer(1024)
        success = self.lib.fax_api_resume_job(
            self.api_instance,
            job_id.encode('utf-8'),
            error_msg
        )
        return success, error_msg.value.decode('utf-8') if error_msg.value else ""
    
    def wait_for_job(self, job_id: str) -> Tuple[bool, str]:
        """Wait for a job to complete"""
        error_msg = ctypes.create_string_buffer(1024)
        success = self.lib.fax_api_wait_for_job(
            self.api_instance,
            job_id.encode('utf-8'),
            error_msg
        )
        return success, error_msg.value.decode('utf-8') if error_msg.value else ""
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.disconnect()
        if hasattr(self, 'api_instance'):
            self.lib.fax_api_destroy(self.api_instance)


# Example usage
if __name__ == "__main__":
    # Example using the Python wrapper
    with PyFaxAPI("localhost") as fax_api:
        # Connect and login
        success, error = fax_api.connect()
        if not success:
            print(f"Connection failed: {error}")
            exit(1)
        
        success, error = fax_api.login()
        if not success:
            print(f"Login failed: {error}")
            exit(1)
        
        print("Connected and logged in successfully!")
        
        # Send a fax
        options = {
            'coverComments': 'Test fax from Python API',
            'vResolution': 196.0,
            'useECM': True,
            'notification': 'done'
        }
        
        result = fax_api.send_fax(
            files=['/path/to/document.pdf'],
            destinations=['555-1234'],
            options=options
        )
        
        if result['success']:
            print(f"Fax sent successfully! Job ID: {result['job_id']}")
        else:
            print(f"Fax failed: {result['error']}")
        
        # Check send queue
        jobs = fax_api.get_job_status(QueueType.SEND_QUEUE)
        print(f"Jobs in send queue: {len(jobs)}")
        for job in jobs:
            print(f"  Job {job['job_id']}: {job['state']} - {job['pages']} pages")
