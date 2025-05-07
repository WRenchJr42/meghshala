import 'package:flutter/material.dart';
import '../services/bookmark_service.dart';
import '../services/download_service.dart';
import '../widgets/search_bar.dart' as custom;

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({Key? key}) : super(key: key);

  @override
  _BookmarksScreenState createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _bookmarkService = BookmarkService();
  final _downloadService = DownloadService();

  bool _isLoading = true;
  bool _showChapters = true; // Toggle between chapters and lessons

  List<Map<String, dynamic>> _bookmarkedChapters = [];
  List<Map<String, dynamic>> _bookmarkedLessons = [];
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredBookmarkedChapters = [];
  List<Map<String, dynamic>> _filteredBookmarkedLessons = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load both bookmarked chapters and lessons
      final chapters = await _bookmarkService.getBookmarkedChapters();
      final lessons = await _bookmarkService.getBookmarkedLessons();

      setState(() {
        _bookmarkedChapters = chapters;
        _bookmarkedLessons = lessons;
        // Initialize filtered lists
        _filteredBookmarkedChapters = List.from(chapters);
        _filteredBookmarkedLessons = List.from(lessons);
        _isLoading = false;
      });

      debugPrint(
        'Loaded ${chapters.length} bookmarked chapters and ${lessons.length} bookmarked lessons',
      );
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading bookmarks: $e')));
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

    // Reload bookmarks to refresh the list
    _loadBookmarks();
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

    // Reload bookmarks to refresh the list
    _loadBookmarks();
  }

  Future<void> _downloadChapter(Map<String, dynamic> chapter) async {
    final isDownloaded = await _downloadService.isChapterDownloaded(
      chapter['id'],
    );

    if (isDownloaded) {
      await _downloadService.removeDownloadedChapter(chapter['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chapter removed from downloads'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      await _downloadService.downloadChapter(chapter);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chapter downloaded for offline use'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {});
  }

  Future<void> _downloadLesson(Map<String, dynamic> lesson) async {
    final isDownloaded = await _downloadService.isLessonDownloaded(
      lesson['id'],
    );

    if (isDownloaded) {
      await _downloadService.removeDownloadedLesson(lesson['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson removed from downloads'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      await _downloadService.downloadLesson(lesson);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lesson downloaded for offline use'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {});
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filterBookmarks();
    });
  }

  void _filterBookmarks() {
    if (_searchQuery.isEmpty) {
      _filteredBookmarkedChapters = List.from(_bookmarkedChapters);
      _filteredBookmarkedLessons = List.from(_bookmarkedLessons);
    } else {
      final query = _searchQuery.toLowerCase();

      // Filter chapters
      _filteredBookmarkedChapters =
          _bookmarkedChapters.where((chapter) {
            final title = chapter['title']?.toString().toLowerCase() ?? '';
            final number = chapter['number']?.toString() ?? '';

            return title.contains(query) || number.contains(query);
          }).toList();

      // Filter lessons
      _filteredBookmarkedLessons =
          _bookmarkedLessons.where((lesson) {
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
        title: const Text('Bookmarks'),
        actions: [
          // Toggle switch in the AppBar
          Row(
            children: [
              const Text('Lessons'),
              Switch(
                value: _showChapters,
                onChanged: (value) {
                  setState(() {
                    _showChapters = value;
                  });
                },
              ),
              const Text('Chapters'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Add search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: custom.SearchBar(
              hintText:
                  _showChapters
                      ? 'Search bookmarked chapters...'
                      : 'Search bookmarked lessons...',
              onSearch: _handleSearch,
              showRefreshButton: true,
              onRefresh: _loadBookmarks,
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _showChapters
                    ? _buildChaptersList()
                    : _buildLessonsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersList() {
    if (_filteredBookmarkedChapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _searchQuery.isNotEmpty
                ? Text('No chapters found matching "${_searchQuery}"')
                : const Text('No bookmarked chapters found'),
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _filterBookmarks();
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
              final chapter = _filteredBookmarkedChapters[index];
              return FutureBuilder<bool>(
                future: _downloadService.isChapterDownloaded(chapter['id']),
                builder: (context, snapshot) {
                  final isDownloaded = snapshot.data ?? false;

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
                            icon: const Icon(
                              Icons.bookmark,
                              color: Colors.blue,
                            ),
                            onPressed: () => _toggleChapterBookmark(chapter),
                            tooltip: 'Remove from bookmarks',
                          ),
                          IconButton(
                            icon: Icon(
                              isDownloaded
                                  ? Icons.download_done
                                  : Icons.download_outlined,
                              color: isDownloaded ? Colors.green : null,
                            ),
                            onPressed: () => _downloadChapter(chapter),
                            tooltip:
                                isDownloaded
                                    ? 'Remove download'
                                    : 'Download for offline use',
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
            childCount: _filteredBookmarkedChapters.length,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonsList() {
    if (_filteredBookmarkedLessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _searchQuery.isNotEmpty
                ? Text('No lessons found matching "${_searchQuery}"')
                : const Text('No bookmarked lessons found'),
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _filterBookmarks();
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
              final lesson = _filteredBookmarkedLessons[index];
              return FutureBuilder<bool>(
                future: _downloadService.isLessonDownloaded(lesson['id']),
                builder: (context, snapshot) {
                  final isDownloaded = snapshot.data ?? false;

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
                            icon: const Icon(
                              Icons.bookmark,
                              color: Colors.blue,
                            ),
                            onPressed: () => _toggleLessonBookmark(lesson),
                            tooltip: 'Remove from bookmarks',
                          ),
                          IconButton(
                            icon: Icon(
                              isDownloaded
                                  ? Icons.download_done
                                  : Icons.download_outlined,
                              color: isDownloaded ? Colors.green : null,
                            ),
                            onPressed: () => _downloadLesson(lesson),
                            tooltip:
                                isDownloaded
                                    ? 'Remove download'
                                    : 'Download for offline use',
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
            childCount: _filteredBookmarkedLessons.length,
          ),
        ),
      ],
    );
  }
}
