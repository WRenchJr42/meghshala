import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';

class SyncService {
  // Singleton pattern
  static final SyncService instance = SyncService._internal();

  factory SyncService() {
    return instance;
  }

  SyncService._internal();

  final _supabase = Supabase.instance.client;
  final _dbHelper = DatabaseHelper.instance;

  // Tables to sync - order matters for foreign key relationships
  final List<String> _tables = [
    'countries',
    'states',
    'schools',
    'languages',
    'curricula',
    'grades',
    'subjects',
    'semesters',
    'subtypes',
    'chapters',
    'lessons',
    'chapter_lessons',
    'slides',
    // 'user_profiles', // Removed as we don't want to sync user profiles locally
    'bookmarks',
    'downloads',
    'lesson_feedbacks',
  ];

  // Stream controller for sync status
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  // Current sync status
  SyncStatus _currentStatus = SyncStatus(
    isRunning: false,
    progress: 0,
    message: 'Ready to sync',
    error: null,
  );

  // Connectivity status
  bool _isOnline = false;

  // Flag to check if initial sync has been done
  bool _initialSyncDone = false;

  // Initialize the sync service
  Future<void> initialize() async {
    debugPrint('Initializing SyncService');

    // Setup connectivity monitoring
    Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);

    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;

    // Check if initial sync is needed
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _initialSyncDone = prefs.getBool('initialSyncDone') ?? false;

    if (_isOnline && !_initialSyncDone) {
      // Do initial sync if online and not done yet
      debugPrint('Performing initial sync...');
      await syncAllData();

      // Set flag to indicate initial sync is done
      await prefs.setBool('initialSyncDone', true);
    }

    debugPrint(
      'SyncService initialized, online: $_isOnline, initialSyncDone: $_initialSyncDone',
    );
  }

  // Check if device is online
  bool get isOnline => _isOnline;

  // Update connection status
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    _isOnline = result != ConnectivityResult.none;
    debugPrint('Connectivity status changed: $_isOnline');
  }

  // Get current sync status
  SyncStatus get currentStatus => _currentStatus;

  // Update sync status
  void _updateSyncStatus({
    bool? isRunning,
    double? progress,
    String? message,
    String? error,
  }) {
    _currentStatus = SyncStatus(
      isRunning: isRunning ?? _currentStatus.isRunning,
      progress: progress ?? _currentStatus.progress,
      message: message ?? _currentStatus.message,
      error: error,
    );
    _syncStatusController.add(_currentStatus);
  }

  // Sync all data
  Future<bool> syncAllData() async {
    if (!_isOnline) {
      _updateSyncStatus(
        isRunning: false,
        progress: 0,
        message: 'Cannot sync, offline',
        error: 'No internet connection',
      );
      return false;
    }

    if (_currentStatus.isRunning) {
      debugPrint('Sync already running, skipping request');
      return false;
    }

    try {
      _updateSyncStatus(
        isRunning: true,
        progress: 0,
        message: 'Starting sync...',
        error: null,
      );

      // Ensure user is authenticated
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _updateSyncStatus(
          isRunning: false,
          progress: 0,
          message: 'Authentication required',
          error: 'User not logged in',
        );
        return false;
      }

      // Sync all tables
      int tableCount = _tables.length;
      for (int i = 0; i < tableCount; i++) {
        final table = _tables[i];
        double progress = i / tableCount;

        _updateSyncStatus(progress: progress, message: 'Syncing $table...');

        await _syncTable(table);
      }

      _updateSyncStatus(
        isRunning: false,
        progress: 1.0,
        message: 'Sync completed successfully',
      );

      // Save the timestamp of the sync
      final now = DateTime.now().toIso8601String();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSyncTime', now);

      return true;
    } catch (e) {
      debugPrint('Error during sync: $e');
      _updateSyncStatus(
        isRunning: false,
        progress: 0,
        message: 'Sync failed',
        error: e.toString(),
      );
      return false;
    }
  }

  // Sync a specific table
  Future<void> _syncTable(String table) async {
    try {
      // Skip user_profiles since we don't store it locally anymore
      if (table == 'user_profiles') {
        debugPrint('Skipping sync for user_profiles table as requested');
        return;
      }

      debugPrint('Syncing table: $table');

      // Get last sync time for this table
      String? lastSyncTime = await _dbHelper.getLastSyncTime(table);

      // Get data from Supabase (if we have a lastSyncTime, only get newer records)
      List<Map<String, dynamic>> supabaseData;

      try {
        if (lastSyncTime != null) {
          debugPrint(
            'Fetching new/updated records for $table since $lastSyncTime',
          );
          supabaseData = await _supabase
              .from(table)
              .select()
              .gt('updated_at', lastSyncTime)
              .order('updated_at')
              .limit(1000)
              .then((value) => List<Map<String, dynamic>>.from(value));
        } else {
          debugPrint('Fetching all records for $table (first sync)');
          supabaseData = await _supabase
              .from(table)
              .select()
              .order('updated_at')
              .limit(1000)
              .then((value) => List<Map<String, dynamic>>.from(value));
        }

        debugPrint(
          'Fetched ${supabaseData.length} records from Supabase for $table',
        );
      } catch (e) {
        debugPrint('Error fetching data for $table: $e');
        // If table doesn't exist yet in Supabase, just skip
        if (e.toString().contains('does not exist')) {
          debugPrint('Table $table does not exist in Supabase, skipping');
          return;
        }
        rethrow;
      }

      // Process and store the data in SQLite
      if (supabaseData.isNotEmpty) {
        try {
          // Start a transaction for better performance
          final db = await _dbHelper.database;
          await db.transaction((txn) async {
            var batch = txn.batch();

            for (var row in supabaseData) {
              // Convert any PostgreSQL specific types or formats
              Map<String, dynamic> sqliteRow = _convertToSqliteFormat(row);

              // Check if record exists
              final existingRecords = await txn.query(
                table,
                where: 'id = ?',
                whereArgs: [sqliteRow['id']],
                limit: 1,
              );

              if (existingRecords.isEmpty) {
                // Insert new record
                batch.insert(
                  table,
                  sqliteRow,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              } else {
                // Update existing record
                batch.update(
                  table,
                  sqliteRow,
                  where: 'id = ?',
                  whereArgs: [sqliteRow['id']],
                );
              }
            }

            await batch.commit(noResult: true);
          });
        } catch (e) {
          debugPrint('Error storing data for $table: $e');

          // Check for schema mismatch errors
          if (e.toString().contains('no column named')) {
            // This is a schema mismatch error, log it clearly
            String errorMsg =
                'Schema mismatch detected in table $table: ${e.toString()}';
            debugPrint(errorMsg);

            // Try to extract the problematic column name
            RegExp regex = RegExp(r'no column named (\w+)');
            var match = regex.firstMatch(e.toString());
            if (match != null && match.groupCount >= 1) {
              String columnName = match.group(1)!;
              debugPrint('Problematic column: $columnName');
            }
          }
          rethrow;
        }
      }

      // Update the last sync time
      final now = DateTime.now().toIso8601String();
      await _dbHelper.updateLastSyncTime(table, now);

      debugPrint('Finished syncing table: $table');
    } catch (e) {
      debugPrint('Error syncing table $table: $e');
      throw Exception('Failed to sync $table: $e');
    }
  }

  // Special handling for user profiles
  Future<void> _syncUserProfiles(String? lastSyncTime) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Get the current user's profile
      final userData =
          await _supabase
              .from('user_profiles')
              .select('*, languages:language_id(*), schools:school_id(*)')
              .eq('id', user.id)
              .single();

      if (userData != null) {
        // Convert to SQLite format
        Map<String, dynamic> sqliteRow = _convertToSqliteFormat(userData);

        // Remove nested objects from the main row but keep their IDs
        if (sqliteRow.containsKey('languages')) {
          sqliteRow.remove('languages');
        }
        if (sqliteRow.containsKey('schools')) {
          sqliteRow.remove('schools');
        }

        // Store in SQLite
        await _dbHelper.insert('user_profiles', sqliteRow);
      }

      // Update the last sync time
      final now = DateTime.now().toIso8601String();
      await _dbHelper.updateLastSyncTime('user_profiles', now);

      debugPrint('Finished syncing user profile');
    } catch (e) {
      debugPrint('Error syncing user profile: $e');
      throw Exception('Failed to sync user_profiles: $e');
    }
  }

  // Convert data to SQLite compatible format
  Map<String, dynamic> _convertToSqliteFormat(Map<String, dynamic> row) {
    Map<String, dynamic> converted = {};

    // List of columns to exclude (that exist in Supabase but not in SQLite)
    final columnsToExclude = [
      'created_by',
      'updated_by',
      // Add specific fields for schools table if we're in the middle of migration
      'type',
      'address_line_1',
      'address_line_2',
      'city',
      'pincode',
      'district',
      'phone',
      'email',
      'website',
      'established_date',
      'principal_name',
      'number_of_students',
    ];

    // Special handling for languages table - add default code if missing
    if (row['id'] != null &&
        row.containsKey('title') &&
        !row.containsKey('code') &&
        _tables.contains('languages')) {
      // Check if this is a language record (based on the current table being synced)
      String title = row['title']?.toString() ?? '';
      if (title.isNotEmpty) {
        // Use first two characters of title as code, or generate a code if too short
        String code =
            title.length >= 2
                ? title.substring(0, 2).toUpperCase()
                : title.padRight(2, 'X').toUpperCase();
        row = Map<String, dynamic>.from(row); // Create a copy
        row['code'] = code; // Add code field
      }
    }

    row.forEach((key, value) {
      // Skip columns that might exist in Supabase but not in SQLite
      if (columnsToExclude.contains(key)) {
        return; // Skip these columns entirely
      }

      if (value == null) {
        converted[key] = null;
      } else if (value is bool) {
        // SQLite doesn't have boolean, use 1/0 instead
        converted[key] = value ? 1 : 0;
      } else if (value is DateTime) {
        // Convert DateTime to ISO8601 string
        converted[key] = value.toIso8601String();
      } else if (value is Map || value is List) {
        // Convert Maps and Lists to JSON strings
        converted[key] = json.encode(value);
      } else {
        // Keep other types as is
        converted[key] = value;
      }
    });

    return converted;
  }

  // Get data from local database
  Future<List<Map<String, dynamic>>> getLocalData(
    String table, {
    String? whereClause,
    List<dynamic>? whereArgs,
  }) async {
    try {
      if (whereClause != null && whereArgs != null) {
        return await _dbHelper.queryRows(table, whereClause, whereArgs);
      } else {
        return await _dbHelper.queryAllRows(table);
      }
    } catch (e) {
      debugPrint('Error fetching local data from $table: $e');
      // Fallback to Supabase if local access fails
      if (_isOnline) {
        debugPrint('Falling back to Supabase for table: $table');
        if (whereClause != null && whereArgs != null) {
          // Simple handling for basic where clauses
          final fieldName = whereClause.split('=')[0].trim();
          final value = whereArgs[0];
          return await _supabase
              .from(table)
              .select()
              .eq(fieldName, value)
              .then((value) => List<Map<String, dynamic>>.from(value));
        } else {
          return await _supabase
              .from(table)
              .select()
              .then((value) => List<Map<String, dynamic>>.from(value));
        }
      }
      return [];
    }
  }

  // Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    Map<String, int> stats = {};
    for (var table in _tables) {
      try {
        final count = await _dbHelper.getCount(table);
        stats[table] = count;
      } catch (e) {
        debugPrint('Error getting count for table $table: $e');
        stats[table] = -1; // Error indicator
      }
    }
    return stats;
  }

  // Get last sync time formatted for display
  Future<String> getLastSyncTimeFormatted() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('lastSyncTime');

    if (lastSync == null) {
      return 'Never';
    }

    try {
      final lastSyncDate = DateTime.parse(lastSync);
      final formatter = DateFormat('MMM d, yyyy HH:mm');
      return formatter.format(lastSyncDate);
    } catch (e) {
      debugPrint('Error formatting sync time: $e');
      return 'Error';
    }
  }

  // Clean database (for troubleshooting)
  Future<void> resetDatabase() async {
    try {
      for (var table in _tables.reversed) {
        await _dbHelper.deleteAllRows(table);
      }
      await _dbHelper.deleteAllRows('sync_status');

      // Reset initial sync flag
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('initialSyncDone', false);
      await prefs.remove('lastSyncTime');

      debugPrint('Database reset completed');
    } catch (e) {
      debugPrint('Error resetting database: $e');
      throw Exception('Failed to reset database: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _syncStatusController.close();
  }
}

// Class to represent sync status
class SyncStatus {
  final bool isRunning;
  final double progress; // 0.0 to 1.0
  final String message;
  final String? error;

  SyncStatus({
    required this.isRunning,
    required this.progress,
    required this.message,
    this.error,
  });
}
