import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/document_model.dart';
import '../../core/providers/document_provider.dart';
import '../../core/theme/app_text_styles.dart';

class VirtualIdScreen extends ConsumerWidget {
  final String documentId;
  const VirtualIdScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentProvider);
    final doc = docs.where((d) => d.id == documentId).firstOrNull;
    if (doc == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: const Center(child: Text('Document not found')),
      );
    }

    final fields = {for (final f in doc.extractedFields) f.label: f.value};

    final name = fields['Full Name'] ?? doc.ownerName;
    final idNumber =
        fields['Aadhaar Number'] ??
        fields['PAN Number'] ??
        fields['Voter ID (EPIC)'] ??
        fields['Driving License'] ??
        fields['Passport Number'] ??
        '';
    final dob = fields['Date of Birth'] ?? '';
    final gender = fields['Gender'] ?? '';
    final address = fields['Address'] ?? '';
    final fatherName = fields["Father's Name"] ?? '';
    final phone = fields['Phone Number'] ?? '';
    final email = fields['Email'] ?? '';

    final typeName = doc.detectedType.isNotEmpty ? doc.detectedType : doc.type;
    final color = _typeColor(typeName);
    final hasImage =
        doc.imagePath.isNotEmpty && File(doc.imagePath).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Digital ID',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCard(
                context: context,
                doc: doc,
                typeName: typeName,
                color: color,
                hasImage: hasImage,
                name: name,
                idNumber: idNumber,
                dob: dob,
                gender: gender,
                address: address,
                fatherName: fatherName,
                phone: phone,
                email: email,
              ),
              const SizedBox(height: 24),
              _buildActions(context, doc, color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required DocumentModel doc,
    required String typeName,
    required Color color,
    required bool hasImage,
    required String name,
    required String idNumber,
    required String dob,
    required String gender,
    required String address,
    required String fatherName,
    required String phone,
    required String email,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 40;
    final cardHeight = cardWidth / 1.35;

    return Container(
      width: cardWidth,
      constraints: BoxConstraints(minHeight: cardHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // --- Blurred background image ---
          if (hasImage)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  File(doc.imagePath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
          // Dark scrim over the image
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.7),
                    const Color(0xFF0F0F1A).withValues(alpha: 0.85),
                    const Color(0xFF0F0F1A),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // --- Card content ---
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== HEADER STRIP =====
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _typeIcon(typeName),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Virtual ID Card',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(doc.confidence * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // ===== NAME + AVATAR =====
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _initials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (fatherName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  's/o $fatherName',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== ID NUMBER =====
                  if (idNumber.isNotEmpty) ...[
                    Text(
                      idNumber,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.9),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],

                  const SizedBox(height: 8),

                  // ===== DETAILS GRID =====
                  _buildDetailsGrid(
                    dob: dob,
                    gender: gender,
                    address: address,
                    phone: phone,
                    email: email,
                    color: color,
                  ),

                  const SizedBox(height: 12),

                  // ===== FOOTER =====
                  Row(
                    children: [
                      const Spacer(),
                      Text(
                        'Powered by Vardio',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsGrid({
    required String dob,
    required String gender,
    required String address,
    required String phone,
    required String email,
    required Color color,
  }) {
    final hasRow1 = dob.isNotEmpty || gender.isNotEmpty;
    final hasAddress = address.isNotEmpty;
    final hasRow3 = phone.isNotEmpty || email.isNotEmpty;
    if (!hasRow1 && !hasAddress && !hasRow3) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          if (hasRow1)
            Row(
              children: [
                if (dob.isNotEmpty) Expanded(child: _infoChip('DOB', dob)),
                if (dob.isNotEmpty && gender.isNotEmpty)
                  const SizedBox(width: 8),
                if (gender.isNotEmpty)
                  Expanded(child: _infoChip('Gender', gender)),
              ],
            ),
          if (hasRow1 && hasAddress) const SizedBox(height: 8),
          if (hasAddress) _infoRow('Address', address),
          if (hasAddress && hasRow3) const SizedBox(height: 8),
          if (hasRow3)
            Row(
              children: [
                if (phone.isNotEmpty)
                  Expanded(child: _infoChip('Phone', phone)),
                if (phone.isNotEmpty && email.isNotEmpty)
                  const SizedBox(width: 8),
                if (email.isNotEmpty)
                  Expanded(
                    child: _infoChip(
                      'Email',
                      email.length > 24
                          ? '${email.substring(0, 22)}...'
                          : email,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, DocumentModel doc, Color color) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Back to Details',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Share ID',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  Color _typeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('aadhaar')) {
      return const Color(0xFFE8B30B);
    }
    if (t.contains('pan')) {
      return const Color(0xFF4FC3F7);
    }
    if (t.contains('voter')) {
      return const Color(0xFFFF8A65);
    }
    if (t.contains('driving') || t.contains('license')) {
      return const Color(0xFF66BB6A);
    }
    if (t.contains('passport')) {
      return const Color(0xFF7E57C2);
    }
    if (t.contains('sslc') || t.contains('marks') || t.contains('hsc')) {
      return const Color(0xFF26C6DA);
    }
    if (t.contains('birth')) {
      return const Color(0xFFEC407A);
    }
    if (t.contains('ration')) {
      return const Color(0xFFAB47BC);
    }
    return const Color(0xFF6366F1);
  }

  IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('aadhaar')) {
      return Icons.fingerprint;
    }
    if (t.contains('pan')) {
      return Icons.receipt_long;
    }
    if (t.contains('voter')) {
      return Icons.how_to_vote;
    }
    if (t.contains('driving') || t.contains('license')) {
      return Icons.directions_car;
    }
    if (t.contains('passport')) {
      return Icons.flight;
    }
    if (t.contains('marks') || t.contains('grade') || t.contains('sslc')) {
      return Icons.school;
    }
    if (t.contains('birth')) {
      return Icons.child_care;
    }
    if (t.contains('ration')) {
      return Icons.food_bank;
    }
    return Icons.badge;
  }
}
