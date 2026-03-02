"""
URL configuration for MIDI API project.
"""

from django.urls import path, include

urlpatterns = [
    path('api/', include('api.urls')),
]
