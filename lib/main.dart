import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'registration.dart';
import 'authentication.dart';
import 'subscription_service.dart';
import 'screens/chapters_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/downloads_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import for persistence
import 'dart:convert'; // Import for JSON encoding/decoding
import 'dart:math' as math; // Import for min function
import 'services/bookmark_service.dart'; // Import for bookmark service
import 'services/download_service.dart'; // Import for download service
import 'services/sync_service.dart'; // Import for sync service
import 'services/database_helper.dart'; // Import for database helper
import 'services/data_repository.dart'; // Import for data repository

// Removed unused imports for BookmarkService and DownloadService

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with standard settings
  try {
    await Supabase.initialize(
      url: 'https://wcbgyhgfqazujftqxmez.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndjYmd5aGdmcWF6dWpmdHF4bWV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU5MDM4MzQsImV4cCI6MjA2MTQ3OTgzNH0.KVWaXdQt-vDduTlWENKTduZRiJyMemIp3Tmz2K8OiLA',
    );
    debugPrint('Supabase initialized successfully');

    // Initialize the SyncService and DataRepository
    await SyncService.instance.initialize();
    await DataRepository.instance.initialize();
    debugPrint('Services initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize services: $e');
    // Continue anyway as we'll handle this in the app
  }

  runApp(const MeghshalaApp());
}

class MeghshalaApp extends StatefulWidget {
  const MeghshalaApp({Key? key}) : super(key: key);

  @override
  _MeghshalaAppState createState() => _MeghshalaAppState();
}

class _MeghshalaAppState extends State<MeghshalaApp> {
  bool _isLoading = true;
  bool _authenticated = false;
  final _authService = AuthenticationService();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the simplified authentication check method
      final isAuthenticated = await _authService.isAuthenticated();

      setState(() {
        _authenticated = isAuthenticated;
        _isLoading = false;
      });

      debugPrint('Authentication check complete: $_authenticated');
    } catch (e) {
      debugPrint('Auth check error: $e');
      setState(() {
        _isLoading = false;
        _authenticated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meghshala',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home:
          _isLoading
              ? const SplashScreen()
              : _authenticated
              ? const HomeScreen()
              : const AuthScreen(),
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final _supabase = Supabase.instance.client;
  final DataRepository _dataRepository = DataRepository.instance;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // State variables
  List<Map<String, dynamic>> _filteredChapters = [];
  List<Map<String, dynamic>> _filteredLessons = [];
  Map<String, dynamic>? _selectedCurriculum;
  Map<String, dynamic>? _selectedGrade; // Keep for backward compatibility
  Map<String, dynamic>? _selectedSubject; // Keep for backward compatibility
  Map<String, dynamic>? _selectedSemester;
  String _searchQuery = '';

  // Updated filter-related state variables
  Map<String, dynamic>? _selectedLanguage;
  List<Map<String, dynamic>> _selectedGrades = []; // List for multiple grades
  List<Map<String, dynamic>> _selectedSubjects =
      []; // List for multiple subjects

  bool _hasAppliedFilters = false;

  // List to store curricula for filtering
  List<Map<String, dynamic>> _curricula = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _subscriptionService.subscribeToUserProfileChanges((payload) {
      _loadUserProfile();
    });
    _loadSavedFilters(); // Add this line to load saved filters
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use DataRepository to get user profile from SQLite or Supabase
      final userData = await _dataRepository.getUserProfile();

      if (userData != null) {
        setState(() {
          _profileData = userData;
        });
        debugPrint('Successfully loaded user profile');
      } else {
        debugPrint('No user profile found');
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _signOut() async {
    try {
      // Get the singleton instance of AuthenticationService
      final authService = AuthenticationService();

      // Cancel any existing auth subscriptions before logout to prevent multiple events
      authService.cancelAuthSubscription();

      // Perform the logout
      await authService.logout();

      if (mounted) {
        // Explicitly navigate to the auth screen after logout
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    } catch (e) {
      debugPrint('Error during sign out: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meghshala'),
        actions: [
          // Add filter button
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => FilterScreen(
                        onFiltersApplied: _applyFilters,
                        selectedCurriculum: _selectedCurriculum,
                        selectedGrade: _selectedGrade,
                        selectedSubject: _selectedSubject,
                        selectedSemester: _selectedSemester,
                        selectedLanguage: _selectedLanguage,
                        selectedGrades: _selectedGrades, // Pass selected grades
                        selectedSubjects:
                            _selectedSubjects, // Pass selected subjects
                      ),
                ),
              );
            },
            tooltip: 'Filter content',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child:
                _profileData != null
                    ? CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        _getInitials(_profileData),
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                    : const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child:
                        _profileData != null
                            ? Text(
                              _getInitials(_profileData),
                              style: TextStyle(
                                fontSize: 24,
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                            : const Icon(Icons.person),
                  ),
                  const SizedBox(height: 10),
                  if (_profileData != null) ...[
                    Text(
                      '${_profileData!['first_name']} ${_profileData!['last_name']}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      _profileData!['email'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ] else
                    const Text(
                      'Welcome',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _selectedTabIndex == 0,
              onTap: () {
                setState(() {
                  _selectedTabIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Chapters'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChaptersScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Lessons'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LessonsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Bookmarks'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BookmarksScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Downloads'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Database'),
              subtitle: FutureBuilder<String>(
                future: DataRepository.instance.getLastSyncTimeFormatted(),
                builder: (context, snapshot) {
                  return Text(
                    'Last sync: ${snapshot.data ?? 'Never'}',
                    style: TextStyle(fontSize: 12),
                  );
                },
              ),
              onTap: () {
                Navigator.pop(context);
                _syncData();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: _selectedTabIndex == 2,
              onTap: () {
                setState(() {
                  _selectedTabIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildHomeContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Lessons'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
      ),
    );
  }

  // Use _searchResults and _isSearching in the _buildHomeContent method
  Widget _buildHomeContent() {
    // If we're currently searching, show search results
    if (_isSearching) {
      return _buildSearchResults();
    }

    switch (_selectedTabIndex) {
      case 0: // Home tab
        if (_hasAppliedFilters) {
          return _buildFilteredContent();
        } else {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_profileData != null)
                  Text(
                    'Welcome, ${_profileData!['first_name']} ${_profileData!['last_name']}!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Your learning journey awaits!',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => FilterScreen(
                              onFiltersApplied: _applyFilters,
                              selectedCurriculum: _selectedCurriculum,
                              selectedGrade: _selectedGrade,
                              selectedSubject: _selectedSubject,
                              selectedSemester: _selectedSemester,
                              selectedLanguage: _selectedLanguage,
                              selectedGrades:
                                  _selectedGrades, // Pass selected grades
                              selectedSubjects:
                                  _selectedSubjects, // Pass selected subjects
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter Content'),
                ),
              ],
            ),
          );
        }
      case 1: // Lessons tab
        return _hasAppliedFilters
            ? _buildFilteredContent()
            : const Center(child: Text('Please use filters to view content'));
      case 2: // Profile tab
        return _buildProfileContent();
      default:
        return const Center(child: Text('Coming soon!'));
    }
  }

  Widget _buildFilteredContent() {
    return Column(
      children: [
        // Add search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search for chapters and lessons...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _isSearching = false;
                          _searchResults = [];
                        });
                      },
                    ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchContent,
                      tooltip: 'Search',
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                // Don't search automatically
                _isSearching = false;
              });
            },
            onSubmitted: (value) {
              // Only search when user presses Enter
              if (value.isNotEmpty) {
                setState(() {
                  _searchContent();
                });
              }
            },
          ),
        ),

        // Display empty state message when no chapters found
        Expanded(
          child:
              _filteredChapters.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _searchQuery.isNotEmpty
                            ? Text(
                              'No content found matching "${_searchQuery}"',
                            )
                            : const Text(
                              'No content found for the selected filters',
                            ),
                        const SizedBox(height: 16),
                        if (_searchQuery.isNotEmpty)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _loadFilteredContent();
                              });
                            },
                            child: const Text('Clear Search'),
                          ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    itemCount: _filteredChapters.length,
                    itemBuilder: (context, index) {
                      final chapter = _filteredChapters[index];

                      // Find all lessons that belong to this chapter
                      final chapterLessons = _getLessonsForChapter(
                        chapter['id'],
                      );

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
                              // Bookmark button for chapter
                              FutureBuilder<bool>(
                                future: BookmarkService().isChapterBookmarked(
                                  chapter['id'],
                                ),
                                builder: (context, snapshot) {
                                  final isBookmarked =
                                      snapshot.data ??
                                      chapter['is_bookmarked'] ??
                                      false;

                                  return IconButton(
                                    icon: Icon(
                                      isBookmarked
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      color: isBookmarked ? Colors.blue : null,
                                    ),
                                    tooltip:
                                        isBookmarked
                                            ? 'Remove bookmark'
                                            : 'Bookmark this chapter',
                                    onPressed: () async {
                                      // Use BookmarkService to toggle bookmark status
                                      final bookmarkService = BookmarkService();
                                      final newStatus = await bookmarkService
                                          .toggleChapterBookmark(chapter);

                                      // Force UI refresh
                                      chapter['is_bookmarked'] = newStatus;
                                      setState(() {});

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            newStatus
                                                ? 'Chapter "${chapter['title']}" bookmarked'
                                                : 'Bookmark removed',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              // Download button for chapter
                              FutureBuilder<bool>(
                                future: _isChapterDownloaded(chapter['id']),
                                builder: (context, snapshot) {
                                  final isDownloaded =
                                      snapshot.data ??
                                      chapter['is_downloaded'] ??
                                      false;

                                  return IconButton(
                                    icon: Icon(
                                      isDownloaded
                                          ? Icons.download_done
                                          : Icons.download,
                                      color: isDownloaded ? Colors.green : null,
                                    ),
                                    tooltip:
                                        isDownloaded
                                            ? 'Remove download'
                                            : 'Download this chapter',
                                    onPressed: () async {
                                      _toggleChapterDownload(
                                        chapter,
                                        !isDownloaded,
                                      );

                                      // Force UI refresh
                                      chapter['is_downloaded'] = !isDownloaded;
                                      setState(() {});

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isDownloaded
                                                ? 'Chapter "${chapter['title']}" downloaded'
                                                : 'Download removed',
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              // Arrow icon for navigation
                              const Icon(Icons.arrow_forward_ios),
                            ],
                          ),
                          onTap: () {
                            // Show popup with lessons for this chapter
                            _showLessonsPopup(context, chapter);
                          },
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildProfileContent() {
    if (_profileData == null) {
      return const Center(child: Text('Profile data not available'));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blue,
            child: Text(
              _getInitials(_profileData),
              style: const TextStyle(color: Colors.white, fontSize: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_profileData!['first_name']} ${_profileData!['last_name']}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _formatUserType(_profileData!['user_type'] ?? ''),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          // Show any saved preferences
          if (_hasAppliedFilters) ...[
            const Text(
              'Current Preferences:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('Curriculum: ${_selectedCurriculum?['title'] ?? 'None'}'),
            Text('Grade: ${_selectedGrade?['title'] ?? 'None'}'),
            Text('Subject: ${_selectedSubject?['title'] ?? 'None'}'),
            Text('Semester: ${_selectedSemester?['title'] ?? 'None'}'),
            Text('Language: ${_selectedLanguage?['title'] ?? 'None'}'),
          ],
        ],
      ),
    );
  }

  String _getInitials(Map<String, dynamic>? profile) {
    if (profile == null) return '';

    final firstName = profile['first_name'] as String? ?? '';
    final lastName = profile['last_name'] as String? ?? '';

    String initials = '';
    if (firstName.isNotEmpty) {
      initials += firstName[0];
    }
    if (lastName.isNotEmpty) {
      initials += lastName[0];
    }

    return initials.toUpperCase();
  }

  // Method to handle applying filters
  void _applyFilters(Map<String, dynamic> filters) {
    setState(() {
      _selectedCurriculum = filters['curriculum'];

      // Store the multi-select values for grade and subject
      _selectedGrades = filters['grades'] ?? [];
      _selectedSubjects = filters['subjects'] ?? [];

      // Keep the single selection objects for backwards compatibility
      _selectedGrade = _selectedGrades.isNotEmpty ? _selectedGrades[0] : null;
      _selectedSubject =
          _selectedSubjects.isNotEmpty ? _selectedSubjects[0] : null;

      _selectedSemester = filters['semester'];
      _selectedLanguage = filters['language'];

      _hasAppliedFilters = true;
      _loadFilteredContent();
      _saveFilterSelections(); // Save filter selections
    });
  }

  // Method to load filtered content
  Future<void> _loadFilteredContent() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Store chapter ids that match our multi-selection criteria
      Set<String> matchingChapterIds = {};

      // Check if we need to handle multiple grades/subjects
      bool hasMultipleGrades = _selectedGrades.length > 1;
      bool hasMultipleSubjects = _selectedSubjects.length > 1;

      // Build filter parameters
      String? curriculumId = _selectedCurriculum?['id'];

      // For single selection, use simple parameters
      String? gradeId =
          _selectedGrades.isNotEmpty && !hasMultipleGrades
              ? _selectedGrades[0]['id']
              : null;
      String? subjectId =
          _selectedSubjects.isNotEmpty && !hasMultipleSubjects
              ? _selectedSubjects[0]['id']
              : null;

      // For multiple selection, prepare the IDs
      List<String>? gradeIds =
          hasMultipleGrades
              ? _selectedGrades.map((g) => g['id'] as String).toList()
              : null;
      List<String>? subjectIds =
          hasMultipleSubjects
              ? _selectedSubjects.map((s) => s['id'] as String).toList()
              : null;

      String? semesterId = _selectedSemester?['id'];
      String? languageId = _selectedLanguage?['id'];
      String? searchQuery = _searchQuery.isNotEmpty ? _searchQuery : null;

      // Use DataRepository to get chapters with filters
      final chapters = await _dataRepository.getChapters(
        curriculumId: curriculumId,
        gradeId: gradeId,
        subjectId: subjectId,
        semesterId: semesterId,
        languageId: languageId,
        searchQuery: searchQuery,
        gradeIds: gradeIds,
        subjectIds: subjectIds,
      );

      debugPrint('Found ${chapters.length} chapters after filtering');

      // Add all matching chapter ids to our set
      for (var chapter in chapters) {
        matchingChapterIds.add(chapter['id']);
      }

      setState(() {
        _filteredChapters = chapters;
      });

      // Now fetch lessons for all matching chapters
      List<Map<String, dynamic>> allLessons = [];

      if (matchingChapterIds.isNotEmpty) {
        // Load lessons for each chapter
        for (final chapterId in matchingChapterIds) {
          final chapterLessons = await _dataRepository.getLessonsForChapter(
            chapterId,
          );
          allLessons.addAll(chapterLessons);
        }
      }

      setState(() {
        _filteredLessons = allLessons;
        _isLoading = false;
      });

      debugPrint(
        'Loaded ${_filteredChapters.length} chapters and ${_filteredLessons.length} lessons with filters',
      );
    } catch (e) {
      debugPrint('Error loading filtered content: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToLessonDetails(Map<String, dynamic> lesson) {
    // Implementation for navigating to lesson details
    debugPrint('Navigating to lesson: ${lesson['title']}');
    // TODO: Implement actual navigation to lesson details screen
    // This is where you would navigate to a detailed lesson view
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No content found matching "${_searchQuery}"'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _isSearching = false;
                });
              },
              child: const Text('Clear Search'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
          child: Text(
            'Search Results for "${_searchQuery}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final item = _searchResults[index];
              final isChapter = item['type'] == 'chapter';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    isChapter ? Icons.menu_book : Icons.book,
                    color: isChapter ? Colors.blue : Colors.green,
                  ),
                  title: Text(
                    item['title'] ?? 'Untitled',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isChapter
                        ? 'Chapter ${item['number'] ?? '?'}'
                        : 'Lesson ${item['number'] ?? '?'} ${item['chapter'] != null ? '• ${item['chapter']['title']}' : ''}',
                  ),
                  trailing:
                      isChapter
                          ? IconButton(
                            icon: const Icon(Icons.filter_list),
                            onPressed: () => _applySearchResultAsFilter(item),
                            tooltip: 'Apply as filter',
                          )
                          : null,
                  onTap: () {
                    if (isChapter) {
                      _applySearchResultAsFilter(item);
                    } else {
                      // For lesson taps, navigate to lesson details
                      _navigateToLessonDetails(item);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _applySearchResultAsFilter(Map<String, dynamic> item) {
    // Use the selected search result to set filters
    if (item['type'] == 'chapter') {
      setState(() {
        // Extract curriculum if available
        if (item['curriculum_id'] != null) {
          for (var curriculum in _curricula) {
            if (curriculum['id'] == item['curriculum_id']) {
              _selectedCurriculum = curriculum;
              break;
            }
          }
        }

        // Extract other filters similarly if needed

        // Reset search
        _searchQuery = '';
        _isSearching = false;
      });

      // Create a filters map to pass to _applyFilters
      final filters = {
        'curriculum': _selectedCurriculum,
        'grades': _selectedGrades,
        'subjects': _selectedSubjects,
        'semester': _selectedSemester,
        'language': _selectedLanguage,
      };

      // Apply filters with the required filter map
      _applyFilters(filters);
    }
  }

  // Method to search for content with the current search query
  Future<void> _searchContent() async {
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      // Search in chapters using ilike query
      final chaptersQuery = await _supabase
          .from('chapters')
          .select('*')
          .ilike('title', '%${_searchQuery}%')
          .limit(10);

      // Search in lessons using ilike query
      final lessonsQuery = await _supabase
          .from('lessons')
          .select('*, chapter:chapter_id(*)')
          .ilike('title', '%${_searchQuery}%')
          .limit(10);

      // Convert to proper list types
      final chapters = List<Map<String, dynamic>>.from(chaptersQuery);
      final lessons = List<Map<String, dynamic>>.from(lessonsQuery);

      setState(() {
        _searchResults = [
          ...chapters.map((chapter) => {...chapter, 'type': 'chapter'}),
          ...lessons.map((lesson) => {...lesson, 'type': 'lesson'}),
        ];
        _isLoading = false;
      });

      debugPrint(
        'Found ${chapters.length} chapters and ${lessons.length} lessons matching "${_searchQuery}"',
      );
    } catch (e) {
      debugPrint('Error searching content: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching content: ${e.toString()}')),
      );
      setState(() {
        _isSearching = false;
        _isLoading = false;
      });
    }
  }

  // Add this method to load saved filters from SharedPreferences
  Future<void> _loadSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load curriculum
      final curriculumStr = prefs.getString('selectedCurriculum');
      if (curriculumStr != null) {
        final curriculumMap = json.decode(curriculumStr);
        _selectedCurriculum = Map<String, dynamic>.from(curriculumMap);
      }

      // Load grades
      final gradesStr = prefs.getString('selectedGrades');
      if (gradesStr != null) {
        final gradesList = json.decode(gradesStr) as List;
        _selectedGrades =
            gradesList.map((item) => Map<String, dynamic>.from(item)).toList();

        // Set single grade for backward compatibility
        _selectedGrade = _selectedGrades.isNotEmpty ? _selectedGrades[0] : null;
      }

      // Load subjects
      final subjectsStr = prefs.getString('selectedSubjects');
      if (subjectsStr != null) {
        final subjectsList = json.decode(subjectsStr) as List;
        _selectedSubjects =
            subjectsList
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

        // Set single subject for backward compatibility
        _selectedSubject =
            _selectedSubjects.isNotEmpty ? _selectedSubjects[0] : null;
      }

      // Load semester
      final semesterStr = prefs.getString('selectedSemester');
      if (semesterStr != null) {
        final semesterMap = json.decode(semesterStr);
        _selectedSemester = Map<String, dynamic>.from(semesterMap);
      }

      // Load language
      final languageStr = prefs.getString('selectedLanguage');
      if (languageStr != null) {
        final languageMap = json.decode(languageStr);
        _selectedLanguage = Map<String, dynamic>.from(languageMap);
      }

      // Set has applied filters flag if at least one filter is set
      _hasAppliedFilters =
          _selectedCurriculum != null ||
          _selectedGrades.isNotEmpty ||
          _selectedSubjects.isNotEmpty ||
          _selectedSemester != null ||
          _selectedLanguage != null;

      // Load filtered content if filters were applied
      if (_hasAppliedFilters) {
        _loadFilteredContent();
      }

      debugPrint('Loaded saved filters: $_hasAppliedFilters');
    } catch (e) {
      debugPrint('Error loading saved filters: $e');
      // If there's an error, we'll just start with no filters
    }
  }

  // Method to save filter selections to SharedPreferences
  Future<void> _saveFilterSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save curriculum
      if (_selectedCurriculum != null) {
        await prefs.setString(
          'selectedCurriculum',
          json.encode(_selectedCurriculum),
        );
      } else {
        await prefs.remove('selectedCurriculum');
      }

      // Save grades list
      if (_selectedGrades.isNotEmpty) {
        await prefs.setString('selectedGrades', json.encode(_selectedGrades));
      } else {
        await prefs.remove('selectedGrades');
      }

      // Save subjects list
      if (_selectedSubjects.isNotEmpty) {
        await prefs.setString(
          'selectedSubjects',
          json.encode(_selectedSubjects),
        );
      } else {
        await prefs.remove('selectedSubjects');
      }

      // Save semester
      if (_selectedSemester != null) {
        await prefs.setString(
          'selectedSemester',
          json.encode(_selectedSemester),
        );
      } else {
        await prefs.remove('selectedSemester');
      }

      // Save language
      if (_selectedLanguage != null) {
        await prefs.setString(
          'selectedLanguage',
          json.encode(_selectedLanguage),
        );
      } else {
        await prefs.remove('selectedLanguage');
      }

      debugPrint('Saved filter preferences to SharedPreferences');
    } catch (e) {
      debugPrint('Error saving filter preferences: $e');
    }
  }

  // Get lessons for a specific chapter
  List<Map<String, dynamic>> _getLessonsForChapter(String chapterId) {
    // Simple approach: just return lessons where chapter_id matches this chapter's id
    return _filteredLessons
        .where((lesson) => lesson['chapter_id'] == chapterId)
        .toList();
  }

  // Get lessons for a specific chapter by fetching them on demand
  Future<List<Map<String, dynamic>>> _fetchLessonsForChapter(
    String chapterId,
  ) async {
    try {
      debugPrint('Fetching lessons for chapter ID: $chapterId');

      // Query the lessons table for lessons with this chapter_id
      final lessonsData = await _supabase
          .from('lessons')
          .select('*')
          .eq('chapter_id', chapterId);

      final lessons = List<Map<String, dynamic>>.from(lessonsData);
      debugPrint('Found ${lessons.length} lessons for chapter ID: $chapterId');

      if (lessons.isEmpty) {
        // Create placeholder lessons for demo purposes
        return [
          {
            'id': 'placeholder-1',
            'chapter_id': chapterId,
            'title': 'Sample Lesson 1',
            'number': 1,
            'is_published': true,
          },
          {
            'id': 'placeholder-2',
            'chapter_id': chapterId,
            'title': 'Sample Lesson 2',
            'number': 2,
            'is_published': true,
          },
        ];
      }

      return lessons;
    } catch (e) {
      debugPrint('Error fetching lessons for chapter: $e');
      return [];
    }
  }

  // Show a popup dialog with lessons for a specific chapter
  void _showLessonsPopup(BuildContext context, Map<String, dynamic> chapter) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Lessons for ${chapter['title']}'),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchLessonsForChapter(chapter['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              final lessons = snapshot.data ?? [];

              if (lessons.isEmpty) {
                return const Text('No lessons found for this chapter');
              }

              return SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    // Track bookmark state with a local variable
                    bool isBookmarked = lesson['is_bookmarked'] ?? false;
                    bool isDownloaded = lesson['is_downloaded'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.book),
                        title: Text(lesson['title'] ?? 'Untitled Lesson'),
                        subtitle:
                            lesson['number'] != null
                                ? Text('Lesson ${lesson['number']}')
                                : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bookmark button
                            StatefulBuilder(
                              builder: (context, setState) {
                                return IconButton(
                                  icon: Icon(
                                    isBookmarked
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    color: isBookmarked ? Colors.blue : null,
                                  ),
                                  tooltip:
                                      isBookmarked
                                          ? 'Remove bookmark'
                                          : 'Bookmark this lesson',
                                  onPressed: () {
                                    setState(() {
                                      isBookmarked = !isBookmarked;
                                      // Save bookmark status
                                      _toggleBookmark(lesson, isBookmarked);
                                    });
                                    // Show feedback to user
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isBookmarked
                                              ? 'Lesson "${lesson['title']}" bookmarked'
                                              : 'Bookmark removed',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            // Download button
                            StatefulBuilder(
                              builder: (context, setState) {
                                return IconButton(
                                  icon: Icon(
                                    isDownloaded
                                        ? Icons.download_done
                                        : Icons.download,
                                    color: isDownloaded ? Colors.green : null,
                                  ),
                                  tooltip:
                                      isDownloaded
                                          ? 'Remove download'
                                          : 'Download this lesson',
                                  onPressed: () {
                                    setState(() {
                                      isDownloaded = !isDownloaded;
                                      // Save download status
                                      _toggleDownload(lesson, isDownloaded);
                                    });
                                    // Show feedback to user
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isDownloaded
                                              ? 'Lesson "${lesson['title']}" downloaded'
                                              : 'Download removed',
                                        ),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(context); // Close the dialog
                          _navigateToLessonDetails(lesson);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Toggle bookmark status for a lesson
  void _toggleBookmark(Map<String, dynamic> lesson, bool isBookmarked) async {
    try {
      // Use the BookmarkService instead of directly manipulating SharedPreferences
      final bookmarkService = BookmarkService();
      final result = await bookmarkService.toggleLessonBookmark(lesson);

      debugPrint('Lesson "${lesson['title']}" bookmark status: $result');
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }

  // Toggle download status for a lesson
  void _toggleDownload(Map<String, dynamic> lesson, bool isDownloaded) async {
    try {
      // For a real implementation, you would download the lesson content or delete local files
      debugPrint(
        '${isDownloaded ? "Downloading" : "Removing download for"} lesson: ${lesson['title']}',
      );

      // Here you could call a service to handle the actual download
      // For now, we'll just update the lesson in memory
      lesson['is_downloaded'] = isDownloaded;

      // Example of how you would save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      final downloads = prefs.getStringList('downloadedLessons') ?? [];

      if (isDownloaded && !downloads.contains(lesson['id'])) {
        downloads.add(lesson['id']);
      } else if (!isDownloaded && downloads.contains(lesson['id'])) {
        downloads.remove(lesson['id']);
      }

      await prefs.setStringList('downloadedLessons', downloads);
    } catch (e) {
      debugPrint('Error toggling download: $e');
    }
  }

  // Toggle bookmark status for a chapter
  void _toggleChapterBookmark(
    Map<String, dynamic> chapter,
    bool isBookmarked,
  ) async {
    try {
      // Use the BookmarkService to handle chapter bookmarks
      final bookmarkService = BookmarkService();
      final result = await bookmarkService.toggleChapterBookmark(chapter);

      debugPrint('Chapter "${chapter['title']}" bookmark status: $result');
    } catch (e) {
      debugPrint('Error toggling chapter bookmark: $e');
    }
  }

  // Toggle download status for a chapter
  Future<bool> _toggleChapterDownload(
    Map<String, dynamic> chapter,
    bool isDownloaded,
  ) async {
    try {
      // For a real implementation, you would download all lessons in the chapter
      debugPrint(
        '${isDownloaded ? "Downloading" : "Removing download for"} chapter: ${chapter['title']}',
      );

      // Here you could call a service to handle the actual download
      // For now, we'll just update the chapter in memory
      chapter['is_downloaded'] = isDownloaded;

      // Example of how you would save to shared preferences
      final prefs = await SharedPreferences.getInstance();
      final downloads = prefs.getStringList('downloadedChapters') ?? [];

      if (isDownloaded && !downloads.contains(chapter['id'])) {
        downloads.add(chapter['id']);
      } else if (!isDownloaded && downloads.contains(chapter['id'])) {
        downloads.remove(chapter['id']);
      }

      await prefs.setStringList('downloadedChapters', downloads);

      // Return the new download status
      return isDownloaded;
    } catch (e) {
      debugPrint('Error toggling chapter download: $e');
      return false;
    }
  }

  // Check if a chapter is downloaded
  Future<bool> _isChapterDownloaded(String chapterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloads = prefs.getStringList('downloadedChapters') ?? [];
      return downloads.contains(chapterId);
    } catch (e) {
      debugPrint('Error checking chapter download status: $e');
      return false;
    }
  }

  // Method to sync data between SQLite and Supabase
  Future<void> _syncData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Ask user if they want to reset the database to fix schema issues
      bool resetDatabase =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Sync Options'),
                  content: const Text(
                    'Do you want to clear the local database and perform a full resync? '
                    'This is recommended if you\'re experiencing schema errors or data inconsistencies. '
                    'Note: Your local changes will be lost.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Normal Sync'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Clear & Resync'),
                    ),
                  ],
                ),
          ) ??
          false;

      // Clear database if user chose to reset
      if (resetDatabase) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const AlertDialog(
                title: Text('Clearing Database'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Clearing local database...'),
                  ],
                ),
              ),
        );

        // Call the clearDatabase method we added earlier
        await DatabaseHelper.instance.clearDatabase();

        // Pop the dialog
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database cleared successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Show a dialog to indicate sync is in progress
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('Syncing Data'),
              content: StreamBuilder<SyncStatus>(
                stream: SyncService.instance.syncStatus,
                builder: (context, snapshot) {
                  final status =
                      snapshot.data ?? SyncService.instance.currentStatus;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: status.progress),
                      const SizedBox(height: 16),
                      Text(status.message),
                      if (status.error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          status.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
      );

      // Start the sync process
      final success = await DataRepository.instance.syncData();

      // Close the dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show result message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Sync completed successfully' : 'Sync failed',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Refresh the UI if needed
      if (success && _hasAppliedFilters) {
        _loadFilteredContent();
      }
    } catch (e) {
      // Close the dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during sync: $e'),
          duration: const Duration(seconds: 3),
        ),
      );

      debugPrint('Error during sync: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// The FilterScreen implementation
class FilterScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onFiltersApplied;
  // Add parameters for passing in the currently selected filters
  final Map<String, dynamic>? selectedCurriculum;
  final Map<String, dynamic>? selectedGrade; // Keep for backward compatibility
  final Map<String, dynamic>?
  selectedSubject; // Keep for backward compatibility
  final Map<String, dynamic>? selectedSemester;
  final Map<String, dynamic>? selectedLanguage;
  final List<Map<String, dynamic>>?
  selectedGrades; // New parameter for multi-selection
  final List<Map<String, dynamic>>?
  selectedSubjects; // New parameter for multi-selection

  const FilterScreen({
    Key? key,
    required this.onFiltersApplied,
    this.selectedCurriculum,
    this.selectedGrade,
    this.selectedSubject,
    this.selectedSemester,
    this.selectedLanguage,
    this.selectedGrades,
    this.selectedSubjects,
  }) : super(key: key);

  @override
  _FilterScreenState createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  final _supabase = Supabase.instance.client;
  final _dataRepository =
      DataRepository.instance; // Add DataRepository instance
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Data lists
  List<Map<String, dynamic>> _curricula = [];
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _languages = [];

  // Selected values - using lists for multiple selection
  Map<String, dynamic>? _selectedCurriculum;
  List<Map<String, dynamic>> _selectedGrades = [];
  List<Map<String, dynamic>> _selectedSubjects = [];
  Map<String, dynamic>? _selectedSemester;
  Map<String, dynamic>? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    // Initialize selected values from widget properties to maintain persistence
    _selectedCurriculum = widget.selectedCurriculum;

    // Initialize multi-select lists properly
    if (widget.selectedGrades != null && widget.selectedGrades!.isNotEmpty) {
      _selectedGrades = List.from(widget.selectedGrades!);
    } else if (widget.selectedGrade != null) {
      // Backward compatibility - add single grade to list
      _selectedGrades = [widget.selectedGrade!];
    }

    if (widget.selectedSubjects != null &&
        widget.selectedSubjects!.isNotEmpty) {
      _selectedSubjects = List.from(widget.selectedSubjects!);
    } else if (widget.selectedSubject != null) {
      // Backward compatibility - add single subject to list
      _selectedSubjects = [widget.selectedSubject!];
    }

    _selectedSemester = widget.selectedSemester;
    _selectedLanguage = widget.selectedLanguage;
    _loadFilterData();
  }

  Future<void> _loadFilterData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use DataRepository to get filter data from SQLite instead of direct Supabase queries
      _curricula = await _dataRepository.getCurricula();
      _grades = await _dataRepository.getGrades();
      _subjects = await _dataRepository.getSubjects();
      _semesters = await _dataRepository.getSemesters();
      _languages = await _dataRepository.getLanguages();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading filter data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading filter options: ${e.toString()}'),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Content'),
        actions: [
          // Apply button
          TextButton(
            onPressed: _isLoading || !_canApplyFilters() ? null : _applyFilters,
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Add search bar for searching content directly
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search for chapters and lessons...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _isSearching = false;
                                    _searchResults = [];
                                  });
                                },
                              ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _searchContent,
                                tooltip: 'Search',
                              ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          // Don't search automatically
                          _isSearching = false;
                        });
                      },
                      onSubmitted: (value) {
                        // Only search when user presses Enter
                        if (value.isNotEmpty) {
                          setState(() {
                            _searchContent();
                          });
                        }
                      },
                    ),
                  ),

                  // Show search results or filter options
                  Expanded(
                    child:
                        _isSearching
                            ? _buildSearchResults()
                            : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16.0,
                                0,
                                16.0,
                                16.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header
                                  const Text(
                                    'Select your filters',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Curriculum buttons
                                  _buildFilterSection(
                                    title: 'Curriculum',
                                    items: _curricula,
                                    selectedItems:
                                        _selectedCurriculum != null
                                            ? [_selectedCurriculum!]
                                            : [],
                                    onSelectionChanged: (selected) {
                                      // Single selection for curriculum
                                      setState(() {
                                        _selectedCurriculum =
                                            selected.isNotEmpty
                                                ? selected.first
                                                : null;
                                      });
                                    },
                                    multiSelect: false,
                                  ),
                                  const SizedBox(height: 16),

                                  // Grade buttons (multi-select)
                                  _buildFilterSection(
                                    title: 'Grade',
                                    items: _grades,
                                    selectedItems: _selectedGrades,
                                    onSelectionChanged: (selected) {
                                      setState(() {
                                        _selectedGrades = selected;
                                      });
                                    },
                                    multiSelect: true,
                                  ),
                                  const SizedBox(height: 16),

                                  // Subject buttons (multi-select)
                                  _buildFilterSection(
                                    title: 'Subject',
                                    items: _subjects,
                                    selectedItems: _selectedSubjects,
                                    onSelectionChanged: (selected) {
                                      setState(() {
                                        _selectedSubjects = selected;
                                      });
                                    },
                                    multiSelect: true,
                                  ),
                                  const SizedBox(height: 16),

                                  // Semester buttons
                                  _buildFilterSection(
                                    title: 'Semester',
                                    items: _semesters,
                                    selectedItems:
                                        _selectedSemester != null
                                            ? [_selectedSemester!]
                                            : [],
                                    onSelectionChanged: (selected) {
                                      // Single selection for semester
                                      setState(() {
                                        _selectedSemester =
                                            selected.isNotEmpty
                                                ? selected.first
                                                : null;
                                      });
                                    },
                                    multiSelect: false,
                                  ),
                                  const SizedBox(height: 16),

                                  // Language buttons
                                  _buildFilterSection(
                                    title: 'Language',
                                    items: _languages,
                                    selectedItems:
                                        _selectedLanguage != null
                                            ? [_selectedLanguage!]
                                            : [],
                                    onSelectionChanged: (selected) {
                                      // Single selection for language
                                      setState(() {
                                        _selectedLanguage =
                                            selected.isNotEmpty
                                                ? selected.first
                                                : null;
                                      });
                                    },
                                    multiSelect: false,
                                  ),
                                  const SizedBox(height: 32),

                                  // Apply button
                                  ElevatedButton(
                                    onPressed:
                                        _canApplyFilters()
                                            ? _applyFilters
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: const Text('Apply Filters'),
                                  ),

                                  // Reset button
                                  if (_anyFilterSelected())
                                    TextButton(
                                      onPressed: _resetFilters,
                                      child: const Text('Reset Filters'),
                                    ),
                                ],
                              ),
                            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> selectedItems,
    required Function(List<Map<String, dynamic>>) onSelectionChanged,
    required bool multiSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children:
              items.map((item) {
                final isSelected = selectedItems.any(
                  (selected) => selected['id'] == item['id'],
                );

                return FilterChip(
                  label: Text(item['title'] ?? 'Unnamed'),
                  selected: isSelected,
                  onSelected: (selected) {
                    List<Map<String, dynamic>> newSelection = List.from(
                      selectedItems,
                    );

                    if (multiSelect) {
                      // For multi-select filters (grades and subjects)
                      if (selected) {
                        // Add to selection if not already selected
                        if (!isSelected) {
                          newSelection.add(item);
                        }
                      } else {
                        // Remove from selection
                        newSelection.removeWhere(
                          (selected) => selected['id'] == item['id'],
                        );
                      }
                    } else {
                      // For single select filters (curriculum, semester, language)
                      if (selected) {
                        newSelection = [item];
                      } else {
                        newSelection = [];
                      }
                    }

                    onSelectionChanged(newSelection);
                  },
                  selectedColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.2),
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                );
              }).toList(),
        ),
      ],
    );
  }

  bool _canApplyFilters() {
    // At least one filter must be selected
    return _selectedCurriculum != null ||
        _selectedGrades.isNotEmpty ||
        _selectedSubjects.isNotEmpty ||
        _selectedSemester != null ||
        _selectedLanguage != null;
  }

  bool _anyFilterSelected() {
    // Check if any filter is selected
    return _selectedCurriculum != null ||
        _selectedGrades.isNotEmpty ||
        _selectedSubjects.isNotEmpty ||
        _selectedSemester != null ||
        _selectedLanguage != null;
  }

  void _applyFilters() {
    if (!_canApplyFilters()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one filter')),
      );
      return;
    }

    // Create filters map
    final filters = {
      'curriculum': _selectedCurriculum,
      'grades': _selectedGrades,
      'subjects': _selectedSubjects,
      'semester': _selectedSemester,
      'language': _selectedLanguage,
    };

    // Call the callback function
    widget.onFiltersApplied(filters);

    // Navigate back
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _selectedCurriculum = null;
      _selectedGrades = [];
      _selectedSubjects = [];
      _selectedSemester = null;
      _selectedLanguage = null;
    });
  }

  Future<void> _searchContent() async {
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      // Search in chapters using ilike query
      final chaptersQuery = await _supabase
          .from('chapters')
          .select('*')
          .ilike('title', '%${_searchQuery}%')
          .limit(10);

      // Search in lessons using ilike query
      final lessonsQuery = await _supabase
          .from('lessons')
          .select('*, chapter:chapter_id(*)')
          .ilike('title', '%${_searchQuery}%')
          .limit(10);

      // Convert to proper list types
      final chapters = List<Map<String, dynamic>>.from(chaptersQuery);
      final lessons = List<Map<String, dynamic>>.from(lessonsQuery);

      setState(() {
        _searchResults = [
          ...chapters.map((chapter) => {...chapter, 'type': 'chapter'}),
          ...lessons.map((lesson) => {...lesson, 'type': 'lesson'}),
        ];
        _isLoading = false;
      });

      debugPrint(
        'Found ${chapters.length} chapters and ${lessons.length} lessons matching "${_searchQuery}"',
      );
    } catch (e) {
      debugPrint('Error searching content: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching content: ${e.toString()}')),
      );
      setState(() {
        _isSearching = false;
        _isLoading = false;
      });
    }
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No content found matching "${_searchQuery}"'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _isSearching = false;
                });
              },
              child: const Text('Clear Search'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
          child: Text(
            'Search Results for "${_searchQuery}"',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          // Using CustomScrollView with SliverList for better performance
          child: CustomScrollView(
            slivers: [
              SliverList(
                // Using SliverChildBuilderDelegate for on-demand rendering
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _searchResults[index];
                    final isChapter = item['type'] == 'chapter';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isChapter ? Icons.menu_book : Icons.book,
                          color: isChapter ? Colors.blue : Colors.green,
                        ),
                        title: Text(
                          item['title'] ?? 'Untitled',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isChapter
                              ? 'Chapter ${item['number'] ?? '?'}'
                              : 'Lesson ${item['number'] ?? '?'} ${item['chapter'] != null ? '• ${item['chapter']['title']}' : ''}',
                        ),
                        trailing:
                            isChapter
                                ? IconButton(
                                  icon: const Icon(Icons.filter_list),
                                  onPressed:
                                      () => _applySearchResultAsFilter(item),
                                  tooltip: 'Apply as filter',
                                )
                                : null,
                        onTap: () {
                          if (isChapter) {
                            _applySearchResultAsFilter(item);
                          } else {
                            // For lesson taps, simply show a message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Selected: ${item['title']}'),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  // Only create the children that are actually visible
                  childCount: _searchResults.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _applySearchResultAsFilter(Map<String, dynamic> item) {
    // Use the selected search result to set filters
    if (item['type'] == 'chapter') {
      setState(() {
        // Extract curriculum if available
        if (item['curriculum_id'] != null) {
          for (var curriculum in _curricula) {
            if (curriculum['id'] == item['curriculum_id']) {
              _selectedCurriculum = curriculum;
              break;
            }
          }
        }

        // Extract other filters similarly if needed

        // Reset search
        _searchQuery = '';
        _isSearching = false;
      });

      // Create a filters map to pass to _applyFilters
      final filters = {
        'curriculum': _selectedCurriculum,
        'grades': _selectedGrades,
        'subjects': _selectedSubjects,
        'semester': _selectedSemester,
        'language': _selectedLanguage,
      };

      // Apply filters with the required filter map
      widget.onFiltersApplied(filters);
      Navigator.pop(context);
    }
  }
}

String _formatUserType(String userType) {
  // Split by underscore, capitalize first letter of each word, then join with space
  return userType
      .split('_')
      .map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}
