import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/relationship_model.dart';

const _storageKey = 'relationships';

class RelationshipNotifier extends StateNotifier<List<PersonNode>> {
  RelationshipNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      final list = (jsonDecode(data) as List)
          .map((e) => PersonNode.fromMap(e as Map<String, dynamic>))
          .toList();
      state = list;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(state.map((r) => r.toMap()).toList()),
    );
  }

  Future<void> addRelationship(PersonNode person) async {
    state = [...state, person];
    await _save();
  }

  Future<void> removeRelationship(String id) async {
    state = state.where((p) => p.id != id).toList();
    await _save();
  }

  List<PersonNode> get familyMembers => state.where((p) => !p.isUser).toList();

  PersonNode? get self => state.isEmpty
      ? null
      : state.firstWhere((p) => p.isUser, orElse: () => state.first);
}

final relationshipProvider =
    StateNotifierProvider<RelationshipNotifier, List<PersonNode>>((ref) {
      return RelationshipNotifier();
    });
