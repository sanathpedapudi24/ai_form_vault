import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/person_model.dart';
import '../repositories/person_repository.dart';
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
    await _repo.setRelationshipStatus(
      relationshipId,
      RelationshipStatus.confirmed,
      type: type,
    );
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
