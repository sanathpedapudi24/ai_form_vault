import '../models/document_model.dart';
import '../models/person_model.dart';

/// The vocabulary the on-device intelligence layer reasons with: how everyday
/// words ("licence", "tax", "wife", "birthday") map onto the app's canonical
/// [FactKeys], [DocumentCategory] values, and [RelationshipType] values.
///
/// One place so search, the Q&A engine, and classification all speak the same
/// language. Everything is lowercase-keyed; callers normalize before lookup.
class VaultLexicon {
  VaultLexicon._();

  /// Query/word → canonical fact key. Order-independent; longest-phrase logic
  /// is handled by callers checking multi-word phrases first.
  static const Map<String, List<String>> _factSynonyms = {
    FactKeys.aadhaarNumber: ['aadhaar', 'aadhar', 'adhaar', 'uid', 'uidai'],
    FactKeys.panNumber: ['pan', 'permanent account'],
    FactKeys.passportNumber: ['passport'],
    FactKeys.voterId: ['voter', 'epic', 'election'],
    FactKeys.drivingLicense: [
      'licence', 'license', 'driving', 'dl', 'rto',
    ],
    FactKeys.vehicleRegistration: ['vehicle', 'registration', 'rc'],
    FactKeys.fullName: ['name', 'full name'],
    FactKeys.dob: ['dob', 'birthday', 'birthdate', 'born', 'date of birth'],
    FactKeys.gender: ['gender', 'sex'],
    FactKeys.fatherName: ["father", "father's name", 'dad', 'papa'],
    FactKeys.motherName: ["mother", "mother's name", 'mom', 'mummy'],
    FactKeys.spouseName: ['spouse', 'husband', 'wife'],
    FactKeys.phone: ['phone', 'mobile', 'contact', 'cell', 'contact number'],
    FactKeys.email: ['email', 'mail', 'e-mail'],
    FactKeys.address: ['address', 'residence', 'where i live'],
    FactKeys.pinCode: ['pincode', 'pin code', 'postal', 'zip'],
    FactKeys.bloodGroup: ['blood', 'blood group'],
    FactKeys.nationality: ['nationality', 'citizen'],
    FactKeys.rollNumber: ['roll', 'roll number', 'registration number'],
    FactKeys.institution: ['school', 'college', 'university', 'institution'],
    FactKeys.expiryDate: ['expiry', 'expires', 'expire', 'valid', 'validity',
      'valid till', 'valid until'],
    FactKeys.issueDate: ['issue', 'issued', 'issue date'],
  };

  /// Generic category words (e.g. "ID", "bank") → document category. Specific
  /// document types ("passport", "aadhaar") deliberately live in the fact
  /// synonyms and match documents directly rather than broadening to a whole
  /// category.
  static const Map<DocumentCategory, List<String>> _categorySynonyms = {
    DocumentCategory.identity: ['id', 'identity'],
    DocumentCategory.education: ['education', 'academic'],
    DocumentCategory.finance: ['finance', 'bank', 'insurance', 'tax'],
    DocumentCategory.medical: ['medical', 'health'],
    DocumentCategory.travel: ['travel'],
    DocumentCategory.family: ['family'],
  };

  /// Word → relationship type (for person-scoped queries like "wife's pan").
  static const Map<RelationshipType, List<String>> _relationSynonyms = {
    RelationshipType.father: ['father', 'dad', 'papa', 'daddy'],
    RelationshipType.mother: ['mother', 'mom', 'mum', 'mummy', 'ma'],
    RelationshipType.spouse: ['spouse', 'husband', 'wife', 'partner'],
    RelationshipType.son: ['son'],
    RelationshipType.daughter: ['daughter'],
    RelationshipType.brother: ['brother'],
    RelationshipType.sister: ['sister'],
    RelationshipType.guardian: ['guardian'],
  };

  /// Words that indicate the user is asking about themselves.
  static const Set<String> selfWords = {'my', 'mine', 'i', 'me', 'own'};

  /// Returns the canonical fact key a single word/phrase refers to, or null.
  static String? factKeyFor(String phrase) {
    final p = phrase.toLowerCase().trim();
    for (final entry in _factSynonyms.entries) {
      if (entry.value.contains(p)) return entry.key;
    }
    return null;
  }

  /// Scans a full (normalized) query for the first fact key mentioned, trying
  /// multi-word phrases before single words so "date of birth" beats "date".
  static String? factKeyInQuery(String query) {
    final q = query.toLowerCase();
    String? best;
    var bestLen = 0;
    for (final entry in _factSynonyms.entries) {
      for (final syn in entry.value) {
        if (q.contains(syn) && syn.length > bestLen) {
          best = entry.key;
          bestLen = syn.length;
        }
      }
    }
    return best;
  }

  /// The category implied by a word, or null.
  static DocumentCategory? categoryFor(String word) {
    final w = word.toLowerCase().trim();
    for (final entry in _categorySynonyms.entries) {
      if (entry.value.contains(w)) return entry.key;
    }
    return null;
  }

  /// The relationship type a word names (for "father's aadhaar"), or null.
  static RelationshipType? relationFor(String word) {
    final w = word.toLowerCase().trim();
    for (final entry in _relationSynonyms.entries) {
      if (entry.value.contains(w)) return entry.key;
    }
    return null;
  }

  /// All alias words for the given term's concept, including the term — used
  /// to expand a search term so "uid" also matches documents saying "aadhaar".
  static Set<String> expand(String term) {
    final t = term.toLowerCase().trim();
    final out = <String>{t};
    for (final list in _factSynonyms.values) {
      if (list.contains(t)) out.addAll(list);
    }
    for (final list in _categorySynonyms.values) {
      if (list.contains(t)) out.addAll(list);
    }
    return out;
  }
}
