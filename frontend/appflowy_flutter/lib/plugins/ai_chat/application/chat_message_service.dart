import 'dart:convert';

import 'package:appflowy/plugins/ai_chat/application/chat_entity.dart';
import 'package:appflowy_backend/log.dart';

/// Indicate file source from appflowy document
const appflowySource = "appflowy";

List<ChatFile> fileListFromMessageMetadata(
  Map<String, dynamic>? map,
) {
  final List<ChatFile> metadata = [];
  if (map != null) {
    for (final entry in map.entries) {
      if (entry.value is ChatFile) {
        metadata.add(entry.value);
      }
    }
  }

  return metadata;
}

List<ChatFile> chatFilesFromMetadataString(String? s) {
  if (s == null || s.isEmpty || s == "null") {
    return [];
  }

  final metadataJson = jsonDecode(s);
  if (metadataJson is Map<String, dynamic>) {
    final file = chatFileFromMap(metadataJson);
    if (file != null) {
      return [file];
    } else {
      return [];
    }
  } else if (metadataJson is List) {
    return metadataJson
        .map((e) => e as Map<String, dynamic>)
        .map(chatFileFromMap)
        .where((file) => file != null)
        .cast<ChatFile>()
        .toList();
  } else {
    Log.error("Invalid metadata: $metadataJson");
    return [];
  }
}

ChatFile? chatFileFromMap(Map<String, dynamic>? map) {
  if (map == null) return null;
  if (map.isEmpty) return null;

  final filePath = map['id'] as String?;
  final fileName = map['name'] as String?;

  if (filePath == null || fileName == null) {
    return null;
  }
  return ChatFile.fromFilePath(filePath);
}

class MetadataCollection {
  MetadataCollection({
    required this.sources,
    this.progress,
  });
  final List<ChatMessageRefSource> sources;
  final AIChatProgress? progress;
}

MetadataCollection parseMetadata(String? s) {
  if (s == null || s.trim().isEmpty || s.toLowerCase() == "null") {
    return MetadataCollection(sources: []);
  }

  final List<ChatMessageRefSource> metadata = [];
  AIChatProgress? progress;

  try {
    final dynamic decodedJson = jsonDecode(s);
    if (decodedJson == null) {
      return MetadataCollection(sources: []);
    }

    void processMap(Map<String, dynamic> map) {
      if (map.containsKey("step") && map["step"] != null) {
        progress = AIChatProgress.fromJson(map);
      } else if (map.containsKey("id") && map["id"] != null) {
        metadata.add(ChatMessageRefSource.fromJson(map));
      } else {
        Log.info("Unsupported metadata format: $map");
      }
    }

    if (decodedJson is Map<String, dynamic>) {
      processMap(decodedJson);
    } else if (decodedJson is List) {
      for (final element in decodedJson) {
        if (element is Map<String, dynamic>) {
          processMap(element);
        } else {
          Log.error("Invalid metadata element: $element");
        }
      }
    } else {
      Log.error("Invalid metadata format: $decodedJson");
    }
  } catch (e, stacktrace) {
    Log.error("Failed to parse metadata: $e, input: $s");
    Log.debug(stacktrace.toString());
  }

  return MetadataCollection(sources: metadata, progress: progress);
}

List<ChatFile> chatFilesFromMessageMetadata(
  Map<String, dynamic>? map,
) {
  final List<ChatFile> metadata = [];
  if (map != null) {
    for (final entry in map.entries) {
      if (entry.value is ChatFile) {
        metadata.add(entry.value);
      }
    }
  }

  return metadata;
}
