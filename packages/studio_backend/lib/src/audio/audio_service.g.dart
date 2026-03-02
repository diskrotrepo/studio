// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$AudioServiceRouter(AudioService service) {
  final router = Router();
  router.add('GET', r'/health', service.health);
  router.add('GET', r'/<model>/defaults', service.modelDefaults);
  router.add('GET', r'/<model>/capabilities', service.modelCapabilities);
  router.add('GET', r'/songs', service.getSongs);
  router.add('GET', r'/songs/<songId>', service.getSong);
  router.add('GET', r'/songs/<songId>/download', service.downloadSong);
  router.add('PATCH', r'/songs/<songId>', service.updateSong);
  router.add('DELETE', r'/songs/<songId>', service.deleteSong);
  router.add('POST', r'/songs/batch-delete', service.batchDeleteSongs);
  router.add('POST', r'/upload', service.createUpload);
  router.add('PUT', r'/upload/finalize', service.finalizeUpload);
  router.add('POST', r'/generate', service.generate);
  router.add('GET', r'/tasks/<taskId>', service.getTaskStatus);
  router.add('GET', r'/lora/list', service.loraList);
  router.add('GET', r'/lora/status', service.loraStatus);
  router.add('POST', r'/lora/load', service.loadLora);
  router.add('POST', r'/lora/unload', service.unloadLora);
  router.add('POST', r'/lora/toggle', service.toggleLora);
  router.add('POST', r'/lora/scale', service.setLoraScale);
  return router;
}
