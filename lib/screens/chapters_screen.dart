import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/bookmark_service.dart';
import '../services/download_service.dart';
import '../services/data_repository.dart'; // Add this import
import '../widgets/search_bar.dart' as custom;

class ChaptersScreen extends StatefulWidget {
  const ChaptersScreen({Key? key}) : super(key: key);

  @override
  _ChaptersScreenState createState() => _ChaptersScreenState();
}

class _ChaptersScreenState extends State<ChaptersScreen> {
  final _supabase = Supabase.instance.client;
  final _bookmarkService = BookmarkService();
  final _downloadService = DownloadService();
  final _dataRepository =
      DataRepository.instance; // Add DataRepository instance

  bool _isLoading = true;
  List<Map<String, dynamic>> _chapters = [];
  List<Map<String, dynamic>> _filteredChapters = [];
  String _searchQuery = '';

  // User preferences from registration
  Map<String, dynamic>? _selectedCurriculum;
  Map<String, dynamic>? _selectedGrade;
  Map<String, dynamic>? _selectedSubject;
  Map<String, dynamic>? _selectedSemester;
  Map<String, dynamic>? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = _supabase.auth.currentUser;
      if (user != null) {
        // Get user profile using the DataRepository
        final userData = await _dataRepository.getUserProfile();

        if (userData == null) {
          debugPrint('No user profile found');
          return;
        }

        // Get curriculum, grade, subject preferences
        if (userData['curriculum_id'] != null) {
          final curricula = await _dataRepository.getCurricula();
          _selectedCurriculum = curricula.firstWhere(
            (c) => c['id'] == userData['curriculum_id'],
            orElse: () => {},
          );
        }

        if (userData['grade_id'] != null) {
          final grades = await _dataRepository.getGrades();
          _selectedGrade = grades.firstWhere(
            (g) => g['id'] == userData['grade_id'],
            orElse: () => {},
          );
        }

        if (userData['subject_id'] != null) {
          final subjects = await _dataRepository.getSubjects();
          _selectedSubject = subjects.firstWhere(
            (s) => s['id'] == userData['subject_id'],
            orElse: () => {},
          );
        }

        if (userData['semester_id'] != null) {
          final semesters = await _dataRepository.getSemesters();
          _selectedSemester = semesters.firstWhere(
            (s) => s['id'] == userData['semester_id'],
            orElse: () => {},
          );
        }

        if (userData['language_id'] != null) {
          final languages = await _dataRepository.getLanguages();
          _selectedLanguage = languages.firstWhere(
            (l) => l['id'] == userData['language_id'],
            orElse: () => {},
          );
        }

        // Load chapters based on preferences
        await _loadChapters();
      }
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading preferences: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChapters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Build filter parameters for getChapters method
      String? curriculumId = _selectedCurriculum?['id'];
      String? gradeId = _selectedGrade?['id'];
      String? subjectId = _selectedSubject?['id'];
      String? semesterId = _selectedSemester?['id'];
      String? languageId = _selectedLanguage?['id'];
      String? searchQuery = _searchQuery.isNotEmpty ? _searchQuery : null;

      // Use DataRepository instead of direct Supabase query
      final chapters = await _dataRepository.getChapters(
        curriculumId: curriculumId,
        gradeId: gradeId,
        subjectId: subjectId,
        semesterId: semesterId,
        languageId: languageId,
        searchQuery: searchQuery,
      );

      setState(() {
        _chapters = chapters;
        _filteredChapters = _chapters;
      });

      debugPrint(
        'Loaded ${_chapters.length} chapters with search: "$_searchQuery"',
      );
    } catch (e) {
      debugPrint('Error loading chapters: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading chapters: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterChapters() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredChapters = List.from(_chapters);
      } else {
        final query = _searchQuery.toLowerCase();
        _filteredChapters =
            _chapters.where((chapter) {
              final title = chapter['title']?.toString().toLowerCase() ?? '';
              final number = chapter['number']?.toString() ?? '';

              return title.contains(query) || number.contains(query);
            }).toList();
      }
    });
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    // Instead of filtering locally, trigger a new server query with the search term
    _loadChapters();
  }

  Future<void> _toggleBookmark(Map<String, dynamic> chapter) async {
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

  Future<void> _refreshChapters() async {
    await _loadChapters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chapters')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: custom.SearchBar(
              hintText: 'Search chapters...',
              onSearch: _handleSearch,
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredChapters.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No chapters found'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshChapters,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _refreshChapters,
                      child: CustomScrollView(
                        slivers: [
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final chapter = _filteredChapters[index];
                              return FutureBuilder<bool>(
                                future: _bookmarkService.isChapterBookmarked(
                                  chapter['id'],
                                ),
                                builder: (context, bookmarkSnapshot) {
                                  final isBookmarked =
                                      bookmarkSnapshot.data ?? false;

                                  return FutureBuilder<bool>(
                                    future: _downloadService
                                        .isChapterDownloaded(chapter['id']),
                                    builder: (context, downloadSnapshot) {
                                      final isDownloaded =
                                          downloadSnapshot.data ?? false;

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            chapter['title'] ??
                                                'Untitled Chapter',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Chapter ${chapter['number'] ?? '?'}',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  isBookmarked
                                                      ? Icons.bookmark
                                                      : Icons.bookmark_border,
                                                  color:
                                                      isBookmarked
                                                          ? Colors.blue
                                                          : null,
                                                ),
                                                onPressed:
                                                    () => _toggleBookmark(
                                                      chapter,
                                                    ),
                                                tooltip:
                                                    isBookmarked
                                                        ? 'Remove from bookmarks'
                                                        : 'Add to bookmarks',
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  isDownloaded
                                                      ? Icons.download_done
                                                      : Icons.download_outlined,
                                                  color:
                                                      isDownloaded
                                                          ? Colors.green
                                                          : null,
                                                ),
                                                onPressed:
                                                    () => _downloadChapter(
                                                      chapter,
                                                    ),
                                                tooltip:
                                                    isDownloaded
                                                        ? 'Remove download'
                                                        : 'Download for offline use',
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            // Navigate to chapter details
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
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
                              );
                            }, childCount: _filteredChapters.length),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
