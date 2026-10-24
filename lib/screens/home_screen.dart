import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/catalog.dart';
import '../widgets/brand.dart';
import '../widgets/enquiry_sheet.dart';
import '../widgets/floor_card.dart';

/// App home: logo bar, search, category tabs and a grid of designs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Catalog> _catalog = Catalog.load();
  final _search = TextEditingController();

  String _query = '';

  /// Selected category id, or null for "All".
  String? _filter;

  /// How many designs each category previews on the "All" tab.
  static const _previewCount = 4;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  /// True when every word typed appears somewhere in the design's name/category.
  bool _matches(FloorItem item) {
    if (_query.isEmpty) return true;
    final haystack = '${item.title} ${item.id} ${item.category.title} ${item.category.subtitle}'.toLowerCase();
    return _query.toLowerCase().split(RegExp(r'\s+')).every(haystack.contains);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 20,
        title: const BrandLockup(onDark: false, markSize: 32),
        actions: [
          IconButton(
            tooltip: 'Contact us',
            icon: const Icon(Icons.support_agent_rounded, size: 26),
            color: KColors.blue,
            onPressed: () => showEnquirySheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        // Tapping anywhere outside the search box closes the keyboard.
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: FutureBuilder<Catalog>(
          future: _catalog,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Could not load designs.\n${snap.error}', textAlign: TextAlign.center));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final catalog = snap.data!;
            return Column(
              children: [
                _searchField(),
                _categoryChips(catalog),
                Expanded(child: _results(catalog)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _searchField() {
    const radius = BorderRadius.all(Radius.circular(14));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v.trim()),
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: KColors.navy),
        decoration: InputDecoration(
          hintText: 'Search courts & floors',
          hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(color: KColors.slateLight),
          prefixIcon: const Icon(Icons.search_rounded, color: KColors.slateLight),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, color: KColors.slateLight),
                  onPressed: _clearSearch,
                ),
          filled: true,
          fillColor: KColors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: KColors.paperDim),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: KColors.paperDim),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: KColors.blue, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _categoryChips(Catalog catalog) {
    Widget chip(String label, String? id) => ChoiceChip(
      label: Text(label),
      selected: _filter == id,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = id),
    );

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All', null),
          for (final c in catalog.categories) ...[const SizedBox(width: 8), chip(c.title, c.id)],
        ],
      ),
    );
  }

  Widget _results(Catalog catalog) {
    final text = Theme.of(context).textTheme;
    const grid = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.84,
    );
    final slivers = <Widget>[];

    if (_query.isEmpty && _filter == null) {
      // "All" tab: a short preview of each category with "See all".
      for (final c in catalog.categories) {
        slivers
          ..add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 0, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: text.titleMedium),
                          Text('${c.items.length} designs', style: text.bodySmall),
                        ],
                      ),
                    ),
                    if (c.items.length > _previewCount)
                      TextButton(onPressed: () => setState(() => _filter = c.id), child: const Text('See all')),
                  ],
                ),
              ),
            ),
          )
          ..add(
            SliverGrid.builder(
              gridDelegate: grid,
              itemCount: c.items.length < _previewCount ? c.items.length : _previewCount,
              itemBuilder: (_, i) => FloorCard(item: c.items[i]),
            ),
          );
      }
    } else {
      // A single category and/or a search.
      final source = _filter == null
          ? catalog.categories.expand((c) => c.items)
          : catalog.categories.firstWhere((c) => c.id == _filter).items;
      final items = source.where(_matches).toList();

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
            child: Text(
              _query.isEmpty ? '${items.length} designs' : '${items.length} result${items.length == 1 ? '' : 's'}',
              style: text.labelMedium,
            ),
          ),
        ),
      );
      if (items.isEmpty) {
        slivers.add(SliverFillRemaining(hasScrollBody: false, child: _emptyState()));
      } else {
        slivers.add(
          SliverGrid.builder(
            gridDelegate: grid,
            itemCount: items.length,
            itemBuilder: (_, i) => FloorCard(item: items[i]),
          ),
        );
      }
    }

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        for (final s in slivers) SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: s),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _emptyState() {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: KColors.slateLight),
          const SizedBox(height: 12),
          Text('No designs match "$_query"', style: text.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Try "badminton", "track" or "playground".', style: text.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: _clearSearch, child: const Text('Clear search')),
        ],
      ),
    );
  }
}
