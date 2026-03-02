"""
WebSocket consumers for real-time task status updates.
"""

import logging
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from celery.result import AsyncResult

logger = logging.getLogger(__name__)


class TaskStatusConsumer(AsyncJsonWebsocketConsumer):
    """
    Clients connect and subscribe to task IDs.
    When a Celery task sends an update via the channel layer,
    this consumer forwards it to the WebSocket client.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.subscribed_tasks = set()

    async def connect(self):
        await self.accept()

    async def disconnect(self, close_code):
        for task_id in list(self.subscribed_tasks):
            await self.channel_layer.group_discard(
                f'task_{task_id}', self.channel_name
            )
        self.subscribed_tasks.clear()

    async def receive_json(self, content):
        action = content.get('action')
        task_id = content.get('task_id')

        if not task_id:
            await self.send_json({'error': 'task_id required'})
            return

        if action == 'subscribe':
            await self.channel_layer.group_add(
                f'task_{task_id}', self.channel_name
            )
            self.subscribed_tasks.add(task_id)

            # Send current status immediately so client doesn't wait
            status_data = _get_current_task_status(task_id)
            await self.send_json(status_data)

        elif action == 'unsubscribe':
            await self.channel_layer.group_discard(
                f'task_{task_id}', self.channel_name
            )
            self.subscribed_tasks.discard(task_id)

    async def task_status_update(self, event):
        """Handler for messages sent to the task group."""
        await self.send_json(event['data'])


def _get_current_task_status(task_id):
    """Check current Celery task state and return status dict."""
    result = AsyncResult(task_id)

    data = {'task_id': task_id}

    if result.state == 'PENDING':
        data['status'] = 'pending'
    elif result.state == 'STARTED':
        data['status'] = 'processing'
    elif result.state == 'SUCCESS':
        data['status'] = 'complete'
        task_result = result.result
        if task_result:
            file_id = task_result.get('file_id')
            if task_result.get('midi_path'):
                data['download_url'] = f'/api/download/{file_id}/'
            if task_result.get('mp3_path'):
                data['mp3_download_url'] = f'/api/download/{file_id}.mp3/'
            if task_result.get('expires_at'):
                data['expires_at'] = task_result['expires_at']
    elif result.state == 'FAILURE':
        data['status'] = 'failed'
        data['error'] = str(result.result) if result.result else 'Unknown error'
    else:
        data['status'] = 'processing'

    return data
