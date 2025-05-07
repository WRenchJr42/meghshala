import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'sync_service.dart';

class DataRepository {
  // Singleton pattern
  static final DataRepository instance = DataRepository._internal();

  factory DataRepository() {
    return instance;
  }

  DataRepository._internal();

  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper.instance;
  final _syncService = SyncService.instance;

  // Flag to determine if we should use local data first
  bool _useLocalDataFirst = true;

  // Initialize the repository
  Future<void> initialize() async {
    debugPrint('Initializing DataRepository');

    // Check settings
    final prefs = await SharedPreferences.getInstance();
    _useLocalDataFirst = prefs.getBool('useLocalDataFirst') ?? true;

    debugPrint(
      'DataRepository initialized, useLocalDataFirst: $_useLocalDataFirst',
    );
  }

  // Set the data source preference
  Future<void> setUseLocalDataFirst(bool value) async {
    _useLocalDataFirst = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useLocalDataFirst', value);
  }

  // Check if we're using local data first
  bool get useLocalDataFirst => _useLocalDataFirst;

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      if (_useLocalDataFirst) {
        // Try to get from local DB first
        final localProfiles = await _dbHelper.queryRows(
          'user_profiles',
          'id = ?',
          [user.id],
        );

        if (localProfiles.isNotEmpty) {
          return localProfiles.first;
        }
      }

      // If not found locally or we prefer remote, fetch from Supabase
      if (await _isOnline()) {
        final data =
            await _supabase
                .from('user_profiles')
                .select('*, languages:language_id(*), schools:school_id(*)')
                .eq('id', user.id)
                .single();

        return data;
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
    }

    return null;
  }

  // Get curricula data
  Future<List<Map<String, dynamic>>> getCurricula() async {
    return await _getTableData('curricula');
  }

  // Get grades data
  Future<List<Map<String, dynamic>>> getGrades() async {
    return await _getTableData('grades');
  }

  // Get subjects data
  Future<List<Map<String, dynamic>>> getSubjects() async {
    return await _getTableData('subjects');
  }

  // Get semesters data
  Future<List<Map<String, dynamic>>> getSemesters() async {
    return await _getTableData('semesters');
  }

  // Get languages data
  Future<List<Map<String, dynamic>>> getLanguages() async {
    return await _getTableData('languages');
  }

  // Get chapters with filters
  Future<List<Map<String, dynamic>>> getChapters({
    String? curriculumId,
    String? gradeId,
    String? subjectId,
    String? semesterId,
    String? languageId,
    String? searchQuery,
    List<String>? gradeIds,
    List<String>? subjectIds,
  }) async {
    try {
      // Build the where clauses and arguments for local database
      List<String> whereClauses = [];
      List<dynamic> whereArgs = [];

      if (curriculumId != null) {
        whereClauses.add('curriculum_id = ?');
        whereArgs.add(curriculumId);
      }

      if (gradeIds != null && gradeIds.isNotEmpty) {
        // Handle multiple grade IDs
        final gradeIdPlaceholders = List.filled(gradeIds.length, '?').join(',');
        whereClauses.add('grade_id IN ($gradeIdPlaceholders)');
        whereArgs.addAll(gradeIds);
      } else if (gradeId != null) {
        // Handle single grade ID
        whereClauses.add('grade_id = ?');
        whereArgs.add(gradeId);
      }

      if (subjectIds != null && subjectIds.isNotEmpty) {
        // Handle multiple subject IDs
        final subjectIdPlaceholders = List.filled(
          subjectIds.length,
          '?',
        ).join(',');
        whereClauses.add('subject_id IN ($subjectIdPlaceholders)');
        whereArgs.addAll(subjectIds);
      } else if (subjectId != null) {
        // Handle single subject ID
        whereClauses.add('subject_id = ?');
        whereArgs.add(subjectId);
      }

      if (semesterId != null) {
        whereClauses.add('semester_id = ?');
        whereArgs.add(semesterId);
      }

      if (languageId != null) {
        whereClauses.add('language_id = ?');
        whereArgs.add(languageId);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClauses.add('title LIKE ?');
        whereArgs.add('%$searchQuery%');
      }

      // Combine where clauses
      final whereClause =
          whereClauses.isEmpty ? null : whereClauses.join(' AND ');

      if (_useLocalDataFirst) {
        // Try to get from local DB first
        List<Map<String, dynamic>> localChapters;

        if (whereClause != null) {
          localChapters = await _dbHelper.queryRows(
            'chapters',
            whereClause,
            whereArgs,
          );
        } else {
          localChapters = await _dbHelper.queryAllRows('chapters');
        }

        if (localChapters.isNotEmpty) {
          return localChapters;
        }
      }

      // If not found locally or we prefer remote, fetch from Supabase
      if (await _isOnline()) {
        var query = _supabase.from('chapters').select('*');

        if (curriculumId != null) {
          query = query.eq('curriculum_id', curriculumId);
        }

        if (gradeIds != null && gradeIds.isNotEmpty) {
          // Can't directly do "IN" with Supabase, so we'll use a chain of .or() calls
          if (gradeIds.length == 1) {
            query = query.eq('grade_id', gradeIds[0]);
          } else {
            // For simplicity, just get all and filter later
            // In production, you would use a proper approach for handling IN clauses
          }
        } else if (gradeId != null) {
          query = query.eq('grade_id', gradeId);
        }

        if (subjectIds != null && subjectIds.isNotEmpty) {
          // Similar approach as grade_ids
          if (subjectIds.length == 1) {
            query = query.eq('subject_id', subjectIds[0]);
          }
          // Otherwise, filter after fetching
        } else if (subjectId != null) {
          query = query.eq('subject_id', subjectId);
        }

        if (semesterId != null) {
          query = query.eq('semester_id', semesterId);
        }

        if (languageId != null) {
          query = query.eq('language_id', languageId);
        }

        if (searchQuery != null && searchQuery.isNotEmpty) {
          query = query.ilike('title', '%$searchQuery%');
        }

        // Execute query
        final chapters = await query.order('number').limit(500);
        final chaptersList = List<Map<String, dynamic>>.from(chapters);

        // Additional filtering for multiple grade_ids and subject_ids if needed
        List<Map<String, dynamic>> filteredChapters = chaptersList;

        if (gradeIds != null && gradeIds.length > 1) {
          filteredChapters =
              filteredChapters
                  .where((chapter) => gradeIds.contains(chapter['grade_id']))
                  .toList();
        }

        if (subjectIds != null && subjectIds.length > 1) {
          filteredChapters =
              filteredChapters
                  .where(
                    (chapter) => subjectIds.contains(chapter['subject_id']),
                  )
                  .toList();
        }

        return filteredChapters;
      }
    } catch (e) {
      debugPrint('Error getting chapters: $e');
    }

    return [];
  }

  // Get lessons for a chapter
  Future<List<Map<String, dynamic>>> getLessonsForChapter(
    String? chapterId,
  ) async {
    try {
      if (_useLocalDataFirst) {
        // Try to get from local DB first
        List<Map<String, dynamic>> localLessons;

        if (chapterId != null) {
          // Get lessons for a specific chapter
          localLessons = await _dbHelper.queryRows(
            'lessons',
            'chapter_id = ?',
            [chapterId],
          );
        } else {
          // Get all lessons if no chapter ID is provided
          localLessons = await _dbHelper.queryAllRows('lessons');
        }

        if (localLessons.isNotEmpty) {
          return localLessons;
        }
      }

      // If not found locally or we prefer remote, fetch from Supabase
      if (await _isOnline()) {
        if (chapterId != null) {
          // Get lessons for a specific chapter
          final lessons = await _supabase
              .from('lessons')
              .select('*')
              .eq('chapter_id', chapterId)
              .order('number');
          return List<Map<String, dynamic>>.from(lessons);
        } else {
          // Get all lessons if no chapter ID is provided
          final lessons = await _supabase
              .from('lessons')
              .select('*')
              .order('number')
              .limit(1000);
          return List<Map<String, dynamic>>.from(lessons);
        }
      }
    } catch (e) {
      debugPrint('Error getting lessons for chapter: $e');
    }

    return [];
  }

  // Get slides for a lesson
  Future<List<Map<String, dynamic>>> getSlidesForLesson(String lessonId) async {
    try {
      if (_useLocalDataFirst) {
        // Try to get from local DB first
        final localSlides = await _dbHelper.queryRows(
          'slides',
          'lesson_id = ?',
          [lessonId],
        );

        if (localSlides.isNotEmpty) {
          return localSlides;
        }
      }

      // If not found locally or we prefer remote, fetch from Supabase
      if (await _isOnline()) {
        final slides = await _supabase
            .from('slides')
            .select('*')
            .eq('lesson_id', lessonId)
            .order('number');

        return List<Map<String, dynamic>>.from(slides);
      }
    } catch (e) {
      debugPrint('Error getting slides for lesson: $e');
    }

    return [];
  }

  // Generic method to get table data
  Future<List<Map<String, dynamic>>> _getTableData(String table) async {
    try {
      if (_useLocalDataFirst) {
        // Try to get from local DB first
        final localData = await _dbHelper.queryAllRows(table);

        if (localData.isNotEmpty) {
          return localData;
        }
      }

      // If not found locally or we prefer remote, fetch from Supabase
      if (await _isOnline()) {
        final data = await _supabase.from(table).select().order('title');

        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('Error getting data from $table: $e');
    }

    return [];
  }

  // Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  // Check if bookmarks exist for a lesson or chapter
  Future<bool> isBookmarked(String id, String type) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      if (_useLocalDataFirst) {
        // Check local DB first
        final localBookmarks = await _dbHelper.queryRows(
          'bookmarks',
          'user_id = ? AND ${type}_id = ?',
          [user.id, id],
        );

        if (localBookmarks.isNotEmpty) {
          return true;
        }
      }

      // Check Supabase if online
      if (await _isOnline()) {
        final bookmarks = await _supabase
            .from('bookmarks')
            .select()
            .eq('user_id', user.id)
            .eq('${type}_id', id);

        return bookmarks.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error checking bookmarks: $e');
    }

    return false;
  }

  // Trigger a sync operation
  Future<bool> syncData() async {
    return await _syncService.syncAllData();
  }

  // Get last sync time formatted for display
  Future<String> getLastSyncTimeFormatted() async {
    return await _syncService.getLastSyncTimeFormatted();
  }
}
