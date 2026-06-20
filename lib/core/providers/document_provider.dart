import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';

const _storageKey = 'documents';

class DocumentNotifier extends StateNotifier<List<DocumentModel>> {
  DocumentNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final list = (jsonDecode(data) as List)
          .map((e) => DocumentModel.fromMap(e as Map<String, dynamic>))
          .toList();
      state = list;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(state.map((d) => d.toMap()).toList());
    await prefs.setString(_storageKey, data);
  }

  Future<DocumentModel> addDocument({
    required String name,
    required String ownerName,
    required DocumentCategory category,
    required String type,
    String detectedType = '',
    double confidence = 0.9,
    List<ExtractedField> extractedFields = const [],
    String rawText = '',
    String imagePath = '',
  }) async {
    final doc = DocumentModel(
      id: const Uuid().v4(),
      name: name,
      ownerName: ownerName,
      category: category,
      type: type,
      detectedType: detectedType,
      uploadDate: DateTime.now(),
      confidence: confidence,
      extractedFields: extractedFields,
      rawText: rawText,
      imagePath: imagePath,
    );
    state = [...state, doc];
    await _save();
    return doc;
  }

  Future<void> deleteDocument(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _save();
  }

  Future<void> updateDocument(DocumentModel updated) async {
    state = state.map((d) => d.id == updated.id ? updated : d).toList();
    await _save();
  }

  DocumentModel? getById(String id) {
    try {
      return state.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}

final documentProvider =
    StateNotifierProvider<DocumentNotifier, List<DocumentModel>>((ref) {
      return DocumentNotifier();
    });
