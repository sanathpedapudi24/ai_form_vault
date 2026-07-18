import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/person_model.dart';
import '../repositories/person_repository.dart';
import '../services/identity_engine.dart';
import 'service_providers.dart';

/// The identity graph: persons + relationships, with confirm/reject actions.
class IdentityGraphState {
  final List<Person> persons;
  final List<Relationship> relationships;
  final bool loading;

  const IdentityGraphState({
    this.persons = const [],
    this.relationships = const [],
    this.loading = true,
  });

  Person? get user => persons.where((p) => p.isUser).firstOrNull;

  List<Relationship> get pending => relationships
      .where((r) => r.status == RelationshipStatus.pending)
      .toList();

  List<Relationship> get confirmed => relationships
      .where((r) => r.status == RelationshipStatus.confirmed)
      .toList();

  /// Confirmed relationships with reciprocal duplicates collapsed — one row
  /// per pair of people. Prefers the direction where the subject isn't the
  /// vault owner, so it reads "Ramesh is Father of You" rather than the
  /// reverse.
  List<Relationship> get confirmedUniquePairs {
    final userId = user?.id;
    final ordered = [...confirmed]..sort((a, b) {
      final aFromUser = a.fromPersonId == userId ? 1 : 0;
      final bFromUser = b.fromPersonId == userId ? 1 : 0;
      return aFromUser.compareTo(bFromUser);
    });
    final seen = <String>{};
    final result = <Relationship>[];
    for (final r in ordered) {
      final key = ([r.fromPersonId, r.toPersonId]..sort()).join('|');
      if (seen.add(key)) result.add(r);
    }
    return result;
  }

  Person? personById(String id) =>
      persons.where((p) => p.id == id).firstOrNull;

  IdentityGraphState copyWith({
    List<Person>? persons,
    List<Relationship>? relationships,
    bool? loading,
  }) => IdentityGraphState(
    persons: persons ?? this.persons,
    relationships: relationships ?? this.relationships,
    loading: loading ?? this.loading,
  );
}

class IdentityGraphNotifier extends StateNotifier<IdentityGraphState> {
  IdentityGraphNotifier(this._repo) : super(const IdentityGraphState()) {
    refresh();
  }

  final PersonRepository _repo;

  Future<void> refresh() async {
    final persons = await _repo.getAllPersons();
    final relationships = await _repo.getRelationships();
    state = IdentityGraphState(
      persons: persons,
      relationships: relationships,
      loading: false,
    );
  }

  Future<void> confirm(String relationshipId, {RelationshipType? type}) async {
    final rel = state.relationships
        .where((r) => r.id == relationshipId)
        .firstOrNull;
    await _repo.setRelationshipStatus(
      relationshipId,
      RelationshipStatus.confirmed,
      type: type,
    );
    // Fill in the reverse edge and suggest siblings among shared-parent people.
    if (rel != null) {
      final confirmed = rel.copyWith(
        status: RelationshipStatus.confirmed,
        type: type ?? rel.type,
      );
      await IdentityEngine(persons: _repo).propagateConfirmed(confirmed);
    }
    await refresh();
  }

  Future<void> reject(String relationshipId) async {
    await _repo.setRelationshipStatus(
      relationshipId,
      RelationshipStatus.rejected,
    );
    await refresh();
  }

  Future<void> renamePerson(String personId, String name) async {
    final person = state.personById(personId);
    if (person == null || name.trim().isEmpty) return;
    await _repo.updatePerson(person.copyWith(displayName: name.trim()));
    await refresh();
  }
}

final identityGraphProvider =
    StateNotifierProvider<IdentityGraphNotifier, IdentityGraphState>(
      (ref) => IdentityGraphNotifier(ref.watch(personRepositoryProvider)),
    );

/// Facts for one person (used by profile and person detail).
final personFactsProvider = FutureProvider.family<List<PersonFact>, String>((
  ref,
  personId,
) async {
  // Re-fetch when the graph refreshes (facts change alongside it).
  ref.watch(identityGraphProvider);
  return ref.watch(personRepositoryProvider).getFacts(personId);
});

/// The vault owner's facts as a key → value map (feeds snap-to-fill and
/// system autofill).
final userFactsProvider = FutureProvider<Map<String, String>>((ref) async {
  final graph = ref.watch(identityGraphProvider);
  final user = graph.user;
  if (user == null) return {};
  final facts = await ref.watch(personRepositoryProvider).getFacts(user.id);
  return {for (final f in facts) f.factKey: f.value};
});
