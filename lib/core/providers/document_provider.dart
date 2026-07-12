import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import '../services/image_vault.dart';
import '../services/notification_service.dart';
import 'service_providers.dart';

/// All documents in the vault, newest first, backed by the encrypted DB.
class DocumentsNotifier extends StateNotifier<List<DocumentModel>> {
  DocumentsNotifier(this._repo) : super(const []) {
    refresh();
  }

  final DocumentRepository _repo;

  Future<void> refresh() async {
    state = await _repo.getAll();
  }

  Future<void> add(DocumentModel doc) async {
    await _repo.insert(doc);
    await refresh();
  }

  Future<void> update(DocumentModel doc) async {
    await _repo.update(doc);
    await refresh();
  }

  Future<void> remove(String id) async {
    final doc = state.where((d) => d.id == id).firstOrNull;
    if (doc != null) {
      await ImageVault.instance.delete(doc.imageFile);
      await ImageVault.instance.delete(doc.thumbFile);
      for (final page in doc.extraPages) {
        await ImageVault.instance.delete(page);
      }
    }
    await NotificationService.instance.cancelForDocument(id);
    await _repo.delete(id);
    await refresh();
  }

  DocumentModel? byId(String id) {
    for (final d in state) {
      if (d.id == id) return d;
    }
    return null;
  }
}

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, List<DocumentModel>>(
      (ref) => DocumentsNotifier(ref.watch(documentRepositoryProvider)),
    );

/// Documents grouped for the vault tabs.
final documentsByCategoryProvider =
    Provider.family<List<DocumentModel>, DocumentCategory?>((ref, category) {
      final docs = ref.watch(documentsProvider);
      if (category == null) return docs;
      return docs.where((d) => d.category == category).toList();
    });

final recentDocumentsProvider = Provider<List<DocumentModel>>((ref) {
  final docs = ref.watch(documentsProvider);
  return docs.take(5).toList();
});

/// Fields worth reviewing: low-confidence and not yet user-verified.
final needsReviewProvider = Provider<List<(DocumentModel, ExtractedField)>>((
  ref,
) {
  final docs = ref.watch(documentsProvider);
  final result = <(DocumentModel, ExtractedField)>[];
  for (final doc in docs) {
    for (final field in doc.extractedFields) {
      if (!field.verified && field.confidence < 0.6) {
        result.add((doc, field));
      }
    }
  }
  return result;
});
