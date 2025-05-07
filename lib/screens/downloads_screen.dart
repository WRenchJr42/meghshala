import 'package:flutter/material.dart';
import '../services/bookmark_service.dart';
import '../services/download_service.dart';
import '../widgets/search_bar.dart' as custom;

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  _DownloadsScreenState createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  final _bookmarkService = BookmarkService();
  final _downloadService = DownloadService();

  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _downloadedChapters = [];
  List<Map<String, dynamic>> _downloadedLessons = [];
  List<Map<String, dynamic>> _filteredDownloadedChapters = [];
  List<Map<String, dynamic>> _filteredDownloadedLessons = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDownloads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load both downloaded chapters and lessons
      final chapters = await _downloadService.getDownloadedChapters();
      final lessons = await _downloadService.getDownloadedLessons();

      setState(() {
        _downloadedChapters = chapters;
        _downloadedLessons = lessons;
        // Initialize filtered lists
        _filteredDownloadedChapters = List.from(chapters);
        _filteredDownloadedLessons = List.from(lessons);
        _isLoading = false;
      });

      debugPrint(
        'Loaded ${chapters.length} downloaded chapters and ${lessons.length} downloaded lessons',
      );
    } catch (e) {
      debugPrint('Error loading downloads: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading downloads: $e')));
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleChapterBookmark(Map<String, dynamic> chapter) async {
    final isBookmarked = await _bookmarkService.toggleChapterBookmark(chapter);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBookmarked
              ? 'Chapter added to bookmarks'
              : 'Chapter removed from bookmarks',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {});
  }

  Future<void> _toggleLessonBookmark(Map<String, dynamic> lesson) async {
    final isBookmarked = await _bookmarkService.toggleLessonBookmark(lesson);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isBookmarked
              ? 'Lesson added to bookmarks'
              : 'Lesson removed from bookmarks',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {});
  }

  Future<void> _removeDownloadedChapter(Map<String, dynamic> chapter) async {
    await _downloadService.removeDownloadedChapter(chapter['id']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chapter removed from downloads'),
        duration: Duration(seconds: 2),
      ),
    );

    // Reload downloads to update the list
    _loadDownloads();
  }

  Future<void> _removeDownloadedLesson(Map<String, dynamic> lesson) async {
    await _downloadService.removeDownloadedLesson(lesson['id']);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lesson removed from downloads'),
        duration: Duration(seconds: 2),
      ),
    );

    // Reload downloads to update the list
    _loadDownloads();
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filterDownloads();
    });
  }

  void _filterDownloads() {
    if (_searchQuery.isEmpty) {
      _filteredDownloadedChapters = List.from(_downloadedChapters);
      _filteredDownloadedLessons = List.from(_downloadedLessons);
    } else {
      final query = _searchQuery.toLowerCase();

      // Filter chapters
      _filteredDownloadedChapters =
          _downloadedChapters.where((chapter) {
            final title = chapter['title']?.toString().toLowerCase() ?? '';
            final number = chapter['number']?.toString() ?? '';

            return title.contains(query) || number.contains(query);
          }).toList();

      // Filter lessons
      _filteredDownloadedLessons =
          _downloadedLessons.where((lesson) {
            final title = lesson['title']?.toString().toLowerCase() ?? '';
            final content = lesson['content']?.toString().toLowerCase() ?? '';
            final number = lesson['number']?.toString() ?? '';

            return title.contains(query) ||
                content.contains(query) ||
                number.contains(query);
          }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Chapters'), Tab(text: 'Lessons')],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Add search bar with dynamic hint text based on active tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: custom.SearchBar(
                      hintText:
                          _tabController.index == 0
                              ? 'Search downloaded chapters...'
                              : 'Search downloaded lessons...',
                      onSearch: _handleSearch,
                      showRefreshButton: true,
                      onRefresh: _loadDownloads,
                    ),
                  ),
                  // TabBarView with lists
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildChaptersList(), _buildLessonsList()],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildChaptersList() {
    if (_filteredDownloadedChapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _searchQuery.isNotEmpty
                ? Text('No chapters found matching "${_searchQuery}"')
                : const Text('No downloaded chapters found'),
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _filterDownloads();
                  });
                },
                child: const Text('Clear Search'),
              ),
          ],
        ),
      );
    }

    // Using CustomScrollView with SliverList instead of ListView.builder
    return CustomScrollView(
      slivers: [
        SliverList(
          // Using SliverChildBuilderDelegate for on-demand rendering
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final chapter = _filteredDownloadedChapters[index];
              return FutureBuilder<bool>(
                future: _bookmarkService.isChapterBookmarked(chapter['id']),
                builder: (context, snapshot) {
                  final isBookmarked = snapshot.data ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(
                        chapter['title'] ?? 'Untitled Chapter',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Chapter ${chapter['number'] ?? '?'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: isBookmarked ? Colors.blue : null,
                            ),
                            onPressed: () => _toggleChapterBookmark(chapter),
                            tooltip:
                                isBookmarked
                                    ? 'Remove from bookmarks'
                                    : 'Add to bookmarks',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _removeDownloadedChapter(chapter),
                            tooltip: 'Remove download',
                          ),
                        ],
                      ),
                      onTap: () {
                        // Navigate to chapter details
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Opening chapter: ${chapter['title']}',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
            // Set the exact count to prevent unnecessary builds
            childCount: _filteredDownloadedChapters.length,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonsList() {
    if (_filteredDownloadedLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _searchQuery.isNotEmpty
                ? Text('No lessons found matching "${_searchQuery}"')
                : const Text('No downloaded lessons found'),
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _filterDownloads();
                  });
                },
                child: const Text('Clear Search'),
              ),
          ],
        ),
      );
    }

    // Using CustomScrollView with SliverList instead of ListView.builder
    return CustomScrollView(
      slivers: [
        SliverList(
          // Using SliverChildBuilderDelegate for on-demand rendering
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final lesson = _filteredDownloadedLessons[index];
              return FutureBuilder<bool>(
                future: _bookmarkService.isLessonBookmarked(lesson['id']),
                builder: (context, snapshot) {
                  final isBookmarked = snapshot.data ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.book),
                      title: Text(
                        lesson['title'] ?? 'Untitled Lesson',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          lesson['number'] != null
                              ? Text('Lesson ${lesson['number']}')
                              : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: isBookmarked ? Colors.blue : null,
                            ),
                            onPressed: () => _toggleLessonBookmark(lesson),
                            tooltip:
                                isBookmarked
                                    ? 'Remove from bookmarks'
                                    : 'Add to bookmarks',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _removeDownloadedLesson(lesson),
                            tooltip: 'Remove download',
                          ),
                        ],
                      ),
                      onTap: () {
                        // Navigate to lesson details
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Opening lesson: ${lesson['title']}'),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
            // Set the exact count to prevent unnecessary builds
            childCount: _filteredDownloadedLessons.length,
          ),
        ),
      ],
    );
  }
}
