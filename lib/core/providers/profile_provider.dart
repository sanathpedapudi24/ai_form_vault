import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';

const _storageKey = 'profile';

class ProfileNotifier extends StateNotifier<UserProfile> {
  ProfileNotifier() : super(const UserProfile(name: '', email: '')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data != null) {
      state = UserProfile.fromMap(jsonDecode(data) as Map<String, dynamic>);
    }
  }

  Future<void> _save() async {
    await SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_storageKey, jsonEncode(state.toMap())),
    );
  }

  Future<void> updateProfile(UserProfile profile) async {
    state = profile;
    await _save();
  }

  Future<void> updateCompleteness(double completeness) async {
    state = UserProfile(
      name: state.name,
      email: state.email,
      phone: state.phone,
      completeness: completeness,
      documentCount: state.documentCount,
      profileCount: state.profileCount,
      relationshipCount: state.relationshipCount,
      recentScans: state.recentScans,
      sections: state.sections,
    );
    await _save();
  }

  Future<void> setName(String name) async {
    state = UserProfile(
      name: name,
      email: state.email,
      phone: state.phone,
      completeness: _calculateCompleteness(name, state.email, state.phone),
      documentCount: state.documentCount,
      profileCount: state.profileCount,
      relationshipCount: state.relationshipCount,
      recentScans: state.recentScans,
      sections: state.sections,
    );
    await _save();
  }

  Future<void> setEmail(String email) async {
    state = UserProfile(
      name: state.name,
      email: email,
      phone: state.phone,
      completeness: _calculateCompleteness(state.name, email, state.phone),
      documentCount: state.documentCount,
      profileCount: state.profileCount,
      relationshipCount: state.relationshipCount,
      recentScans: state.recentScans,
      sections: state.sections,
    );
    await _save();
  }

  Future<void> setPhone(String phone) async {
    state = UserProfile(
      name: state.name,
      email: state.email,
      phone: phone,
      completeness: _calculateCompleteness(state.name, state.email, phone),
      documentCount: state.documentCount,
      profileCount: state.profileCount,
      relationshipCount: state.relationshipCount,
      recentScans: state.recentScans,
      sections: state.sections,
    );
    await _save();
  }

  /// Auto-fill profile fields from extracted document data.
  /// Only overwrites empty fields so manual edits are preserved.
  Future<void> autoFillFromDocument({
    required String name,
    String? email,
    String? phone,
  }) async {
    String newName = state.name.isNotEmpty ? state.name : name;
    String newEmail = state.email.isNotEmpty ? state.email : (email ?? '');
    String newPhone = state.phone.isNotEmpty ? state.phone : (phone ?? '');

    state = UserProfile(
      name: newName,
      email: newEmail,
      phone: newPhone,
      completeness: _calculateCompleteness(newName, newEmail, newPhone),
      documentCount: state.documentCount,
      profileCount: state.profileCount,
      relationshipCount: state.relationshipCount,
      recentScans: state.recentScans,
      sections: state.sections,
    );
    await _save();
  }

  double _calculateCompleteness(String name, String email, String phone) {
    var filled = 0;
    if (name.isNotEmpty) filled++;
    if (email.isNotEmpty) filled++;
    if (phone.isNotEmpty) filled++;
    return filled / 3;
  }

  Future<void> setFromGoogleSignIn({
    required String name,
    required String email,
  }) async {
    state = UserProfile(
      name: name,
      email: email,
      phone: state.phone,
      completeness: _calculateCompleteness(name, email, state.phone),
      documentCount: 0,
      profileCount: 1,
      relationshipCount: 0,
      recentScans: 0,
      sections: [
        ProfileSection(
          name: 'Personal Information',
          iconName: 'person',
          fieldCount: 1,
          isComplete: name.isNotEmpty,
        ),
        ProfileSection(
          name: 'Education',
          iconName: 'school',
          fieldCount: 0,
          isComplete: false,
        ),
        ProfileSection(
          name: 'Contact Information',
          iconName: 'phone',
          fieldCount: 1,
          isComplete: email.isNotEmpty,
        ),
        ProfileSection(
          name: 'Family & Relationships',
          iconName: 'people',
          fieldCount: 0,
          isComplete: false,
        ),
        ProfileSection(
          name: 'Documents Linked',
          iconName: 'description',
          fieldCount: 0,
          isComplete: false,
        ),
      ],
    );
    await _save();
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile>((
  ref,
) {
  return ProfileNotifier();
});
