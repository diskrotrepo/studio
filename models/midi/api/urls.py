"""
URL routing for the MIDI API.
"""

from django.urls import path
from .views import (
    GenerateView,
    MultitrackGenerateView,
    AddTrackView,
    ReplaceTrackView,
    CoverView,
    PretokenizeView,
    DiagnosisView,
    TrainingStartView,
    TrainingSummaryView,
    AutotuneView,
    DataBrowseView,
    DataScanView,
    DataStageView,
    DataDownloadView,
    TaskStatusView,
    DownloadView,
    ConvertView,
    TagsView,
    InstrumentsView,
    TrackInstrumentsView,
    HealthView,
    ModelsView,
)

urlpatterns = [
    # Generation endpoints
    path('generate/', GenerateView.as_view(), name='generate'),
    path('generate/multitrack/', MultitrackGenerateView.as_view(), name='generate-multitrack'),
    path('generate/add-track/', AddTrackView.as_view(), name='generate-add-track'),
    path('generate/replace-track/', ReplaceTrackView.as_view(), name='generate-replace-track'),
    path('generate/cover/', CoverView.as_view(), name='generate-cover'),

    # Pipeline endpoints
    path('data/browse/', DataBrowseView.as_view(), name='data-browse'),
    path('data/scan/', DataScanView.as_view(), name='data-scan'),
    path('data/stage/', DataStageView.as_view(), name='data-stage'),
    path('data/download/', DataDownloadView.as_view(), name='data-download'),
    path('pretokenize/', PretokenizeView.as_view(), name='pretokenize'),
    path('diagnosis/', DiagnosisView.as_view(), name='diagnosis'),
    path('training/start/', TrainingStartView.as_view(), name='training-start'),
    path('training/summary/', TrainingSummaryView.as_view(), name='training-summary'),
    path('training/autotune/', AutotuneView.as_view(), name='training-autotune'),

    # Task status
    path('tasks/<str:task_id>/', TaskStatusView.as_view(), name='task-status'),

    # File download
    path('download/<str:file_id>/', DownloadView.as_view(), name='download'),

    # MIDI to MP3 conversion
    path('convert/', ConvertView.as_view(), name='convert'),

    # Available tags
    path('tags/', TagsView.as_view(), name='tags'),

    # Available instruments (grouped by category)
    path('instruments/', InstrumentsView.as_view(), name='instruments'),

    # Instruments per track type (optionally genre-filtered)
    path('instruments/tracks/', TrackInstrumentsView.as_view(), name='track-instruments'),

    # Available models
    path('models/', ModelsView.as_view(), name='models'),

    # Health check
    path('health/', HealthView.as_view(), name='health'),
]
