import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../services/bookmark_service.dart';
import '../services/download_service.dart';
import '../services/data_repository.dart'; // Add DataRepository import
import '../widgets/search_bar.dart' as custom;

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({Key? key}) : super(key: key);

  @override
  _LessonsScreenState createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  final _supabase = Supabase.instance.client;
  final _bookmarkService = BookmarkService();
  final _downloadService = DownloadService();
  final _dataRepository = DataRepository.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _lessons = [];
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = _supabase.auth.currentUser;
      if (user != null) {
        // Get user profile using DataRepository
        final userData = await _dataRepository.getUserProfile();

        if (userData == null) {
          debugPrint('No user profile found');
          return;
        }

        // Get curriculum, grade, subject preferences using DataRepository
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

        // Load lessons based on preferences
        await _loadLessons();
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

  Future<void> _loadLessons() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _lessons = [];
    });

    try {
      // Get chapters that match our filter criteria
      String? curriculumId = _selectedCurriculum?['id'];
      String? gradeId = _selectedGrade?['id'];
      String? subjectId = _selectedSubject?['id'];
      String? semesterId = _selectedSemester?['id'];
      String? languageId = _selectedLanguage?['id'];
      String? searchQuery = _searchQuery.isNotEmpty ? _searchQuery : null;

      debugPrint(
        'Loading lessons with filters: curriculum=$curriculumId, grade=$gradeId, subject=$subjectId, semester=$semesterId, language=$languageId',
      );

      // First, try to get all lessons directly
      List<Map<String, dynamic>> allLessons = await _dataRepository
          .getLessonsForChapter(null);
      debugPrint('Retrieved ${allLessons.length} total lessons from database');

      // Debug the first few lessons to check the chapter_id format
      if (allLessons.isNotEmpty) {
        for (int i = 0; i < Math.min(3, allLessons.length); i++) {
          debugPrint(
            'Sample lesson ${i + 1}: id=${allLessons[i]['id']}, chapter_id=${allLessons[i]['chapter_id']}',
          );
        }
      }

      if (!mounted) return;

      // If no filters are applied, just show all lessons
      if (curriculumId == null &&
          gradeId == null &&
          subjectId == null &&
          semesterId == null &&
          languageId == null) {
        // Just apply search filter if needed
        if (searchQuery != null && searchQuery.isNotEmpty) {
          allLessons =
              allLessons.where((lesson) {
                final title = lesson['title']?.toString().toLowerCase() ?? '';
                final tags = lesson['tags']?.toString().toLowerCase() ?? '';
                final query = searchQuery.toLowerCase();
                return title.contains(query) || tags.contains(query);
              }).toList();
        }

        setState(() {
          _lessons = allLessons;
          _isLoading = false;
        });

        debugPrint('Loaded ${_lessons.length} lessons (unfiltered)');
        return;
      }

      // Otherwise, get chapters that match our criteria
      final chapters = await _dataRepository.getChapters(
        curriculumId: curriculumId,
        gradeId: gradeId,
        subjectId: subjectId,
        semesterId: semesterId,
        languageId: languageId,
      );

      if (!mounted) return;
      debugPrint('Found ${chapters.length} chapters for lesson filtering');

      // Debug the first few chapters to check their id format
      if (chapters.isNotEmpty) {
        for (int i = 0; i < Math.min(3, chapters.length); i++) {
          debugPrint('Sample chapter ${i + 1}: id=${chapters[i]['id']}');
        }
      }

      if (chapters.isEmpty) {
        setState(() {
          _lessons = [];
          _isLoading = false;
        });
        return;
      }

      // Get chapter IDs for filtering
      final chapterIds = chapters.map((c) => c['id'].toString()).toSet();
      debugPrint(
        'Chapter IDs for filtering: ${chapterIds.take(5).join(', ')}...',
      );

      // MODIFIED APPROACH: For each chapter ID, manually check if any lessons match
      int matchCount = 0;
      List<Map<String, dynamic>> filteredLessons = [];

      for (final lesson in allLessons) {
        if (lesson['chapter_id'] != null) {
          String lessonChapterId = lesson['chapter_id'].toString();

          // Try different formats of the chapter ID
          if (chapterIds.contains(lessonChapterId)) {
            filteredLessons.add(lesson);
            matchCount++;
          }
        }
      }

      debugPrint('Found $matchCount lessons matching chapter criteria');

      // Apply search filter if needed
      if (searchQuery != null && searchQuery.isNotEmpty) {
        filteredLessons =
            filteredLessons.where((lesson) {
              final title = lesson['title']?.toString().toLowerCase() ?? '';
              final tags = lesson['tags']?.toString().toLowerCase() ?? '';
              final query = searchQuery.toLowerCase();
              return title.contains(query) || tags.contains(query);
            }).toList();
      }

      if (!mounted) return;

      setState(() {
        _lessons = filteredLessons;
        _isLoading = false;
      });

      debugPrint('Loaded ${_lessons.length} filtered lessons');

      // If no lessons were found, try a fallback approach
      if (_lessons.isEmpty && allLessons.isNotEmpty) {
        debugPrint(
          'No lessons were found after filtering. Using fallback approach.',
        );

        // As a fallback, if we found no lessons but have a language filter,
        // show lessons without applying chapter filtering
        if (languageId != null) {
          setState(() {
            _isLoading = true;
          });

          // Simplified filter - just use the first 100 lessons for now
          _lessons = allLessons.take(100).toList();

          setState(() {
            _isLoading = false;
          });

          debugPrint(
            'Loaded ${_lessons.length} lessons using fallback approach',
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading lessons: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading lessons: $e')));

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBookmark(Map<String, dynamic> lesson) async {
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
    });
    // Trigger new search with the updated query
    _loadLessons();
  }

  Future<void> _refreshLessons() async {
    await _loadLessons();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lessons')),
      body: Column(
        children: [
          // Add search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: custom.SearchBar(
              hintText: 'Search lessons...',
              onSearch: _handleSearch,
              showRefreshButton: true,
              onRefresh: _refreshLessons,
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _lessons.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No lessons found'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshLessons,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _refreshLessons,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _lessons.length,
                        itemBuilder: (context, index) {
                          final lesson = _lessons[index];
                          return FutureBuilder<bool>(
                            future: _bookmarkService.isLessonBookmarked(
                              lesson['id'],
                            ),
                            builder: (context, bookmarkSnapshot) {
                              final isBookmarked =
                                  bookmarkSnapshot.data ?? false;

                              return FutureBuilder<bool>(
                                future: _downloadService.isLessonDownloaded(
                                  lesson['id'],
                                ),
                                builder: (context, downloadSnapshot) {
                                  final isDownloaded =
                                      downloadSnapshot.data ?? false;

                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.book),
                                      title: Text(
                                        lesson['title'] ?? 'Untitled Lesson',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle:
                                          lesson['number'] != null
                                              ? Text(
                                                'Lesson ${lesson['number']}',
                                              )
                                              : null,
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
                                                () => _toggleBookmark(lesson),
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
                                                () => _downloadLesson(lesson),
                                            tooltip:
                                                isDownloaded
                                                    ? 'Remove download'
                                                    : 'Download for offline use',
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        // Navigate to lesson details
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Opening lesson: ${lesson['title']}',
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
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
