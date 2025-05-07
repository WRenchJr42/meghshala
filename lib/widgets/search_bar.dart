import 'package:flutter/material.dart';

class SearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final String hintText;
  final bool autoFocus;
  final bool showRefreshButton;
  final VoidCallback? onRefresh;

  const SearchBar({
    Key? key,
    required this.onSearch,
    this.hintText = 'Search...',
    this.autoFocus = false,
    this.showRefreshButton = false,
    this.onRefresh,
  }) : super(key: key);

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _searchController = TextEditingController();
  String _currentSearchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    // Only perform search if text has changed
    if (_searchController.text != _currentSearchText) {
      _currentSearchText = _searchController.text;
      widget.onSearch(_currentSearchText);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _currentSearchText = '';
    widget.onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: widget.autoFocus,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                        : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              // Don't trigger search on every change
              onChanged: (value) {
                // Just update the text field, no search triggered
                setState(() {});
              },
              // Allow search when pressing Enter key
              onSubmitted: (value) {
                _performSearch();
              },
            ),
          ),
          // Add a search button
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _performSearch,
              tooltip: 'Search',
            ),
          if (widget.showRefreshButton && widget.onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: widget.onRefresh,
              tooltip: 'Refresh',
            ),
        ],
      ),
    );
  }
}
