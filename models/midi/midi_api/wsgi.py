"""
WSGI config for MIDI API project.
"""

import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'midi_api.settings')

application = get_wsgi_application()
