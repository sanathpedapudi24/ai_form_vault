import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/search_provider.dart';
import '../../core/services/search_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/badges.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/fade_slide_in.dart';
import '../../shared/widgets/vault_image.dart';
import '../dashboard/widgets/category_visual.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static const _suggestions = [
    'Find my passport',
    'Aadhaar card',
    'When does my ID expire',
    'Bank documents',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSunken,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText: AppConfig.aiEnabled
                        ? 'Ask anything about your documents…'
                        : 'Search your documents…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiary,
                    ),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () {
                              _controller.clear();
                              ref.read(searchProvider.notifier).clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    ref.read(searchProvider.notifier).onQueryChanged(value);
                  },
                ),
              ),
            ),
            Expanded(
              child: state.query.isEmpty
                  ? _SuggestionsView(
                      onTap: (s) {
                        _controller.text = s;
                        ref.read(searchProvider.notifier).onQueryChanged(s);
                        setState(() {});
                      },
                    )
                  : _ResultsView(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsView extends StatelessWidget {
  final void Function(String) onTap;

  const _SuggestionsView({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRY ASKING',
              style: AppTextStyles.overline,
            ),
            const Gap(12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _SearchScreenState._suggestions)
                  GestureDetector(
                    onTap: () => onTap(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(s, style: AppTextStyles.label),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final SearchState state;

  const _ResultsView({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try a different word, or check the spelling.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: state.results.length,
      itemBuilder: (context, index) => FadeSlideIn(
        index: index,
        offset: 8,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ResultTile(result: state.results[index]),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;

  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final doc = result.document;
    return GestureDetector(
      onTap: () => context.push('/document/${doc.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            doc.thumbFile.isNotEmpty
                ? VaultImage(fileName: doc.thumbFile, width: 48, height: 48)
                : CategoryVisual(category: doc.category, size: 48),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.displayTitle,
                    style: AppTextStyles.itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(3),
                  Text(
                    result.matchedValue.isNotEmpty
                        ? '${result.matchedLabel}: ${result.matchedValue}'
                        : doc.ownerName,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (result.semantic)
              const TagChip(
                label: 'AI match',
                color: AppColors.info,
                icon: Icons.auto_awesome_rounded,
              ),
          ],
        ),
      ),
    );
  }
}
