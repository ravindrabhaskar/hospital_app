import 'package:flutter/material.dart' hide Page;

import '../../models/json.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import 'state_views.dart';

/// Cursor pagination on top of a provider's first page: keeps the pages
/// loaded with "Load more" (`nextCursor`) and resets them whenever the first
/// page changes (refresh, invalidation, patient switch).
class PagedItems<T> extends StatefulWidget {
  const PagedItems({
    super.key,
    required this.first,
    required this.nextCursor,
    required this.fetch,
    required this.builder,
  });

  final List<T> first;
  final String? nextCursor;
  final Future<Page<T>> Function(String cursor) fetch;

  /// [footer] is the "Load more" control, or null when there is nothing more.
  final Widget Function(BuildContext context, List<T> items, Widget? footer) builder;

  @override
  State<PagedItems<T>> createState() => _PagedItemsState<T>();
}

class _PagedItemsState<T> extends State<PagedItems<T>> {
  final List<T> _more = [];
  String? _cursor;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _cursor = widget.nextCursor;
  }

  @override
  void didUpdateWidget(covariant PagedItems<T> old) {
    super.didUpdateWidget(old);
    if (!identical(old.first, widget.first) || old.nextCursor != widget.nextCursor) {
      _more.clear();
      _cursor = widget.nextCursor;
      _error = null;
      _loading = false;
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.fetch(cursor);
      if (!mounted || _cursor != cursor) return;
      setState(() {
        _more.addAll(page.items);
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.first, ..._more];
    Widget? footer;
    if (_cursor != null) {
      final l = context.l10n;
      footer = Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Center(
          child: _loading
              ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.xs),
                        child: Text(errorMessage(context, _error!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                      ),
                    OutlinedButton.icon(
                      key: const Key('load-more'),
                      onPressed: _loadMore,
                      icon: const Icon(Icons.expand_more),
                      label: Text(_error != null ? l.retry : l.loadMore),
                    ),
                  ],
                ),
        ),
      );
    }
    return widget.builder(context, items, footer);
  }
}
