import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // Private constructor to enforce singleton pattern
  DatabaseHelper._init();

  // Get the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('meghshala.db');
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Increase version number to trigger upgrade
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Create database tables
  Future<void> _createDB(Database db, int version) async {
    debugPrint('Creating SQLite database tables...');

    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // Create countries table
    await db.execute('''
    CREATE TABLE countries (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      iso_code TEXT NOT NULL,
      code TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Create states table
    await db.execute('''
    CREATE TABLE states (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      country_id TEXT,
      code TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (country_id) REFERENCES countries (id)
    )
    ''');

    // Create schools table
    await db.execute('''
    CREATE TABLE schools (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      code TEXT,
      type TEXT,
      address_line_1 TEXT,
      address_line_2 TEXT,
      city TEXT,
      state TEXT,
      pincode TEXT,
      district TEXT,
      phone TEXT,
      email TEXT,
      website TEXT,
      established_date TEXT,
      principal_name TEXT,
      number_of_students INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (state) REFERENCES states (id)
    )
    ''');

    // Create languages table
    await db.execute('''
    CREATE TABLE languages (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      code TEXT DEFAULT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Create curricula table
    await db.execute('''
    CREATE TABLE curricula (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      code TEXT,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Create grades table
    await db.execute('''
    CREATE TABLE grades (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      code TEXT,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Create subjects table
    await db.execute('''
    CREATE TABLE subjects (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      code TEXT,
      color TEXT,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Create semesters table
    await db.execute('''
    CREATE TABLE semesters (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      code TEXT,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Create subtypes table
    await db.execute('''
    CREATE TABLE subtypes (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      code TEXT,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    ''');

    // Create chapters table
    await db.execute('''
    CREATE TABLE chapters (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      number INTEGER NOT NULL,
      is_published INTEGER NOT NULL DEFAULT 0,
      language_id TEXT NOT NULL,
      curriculum_id TEXT NOT NULL,
      grade_id TEXT NOT NULL,
      semester_id TEXT NOT NULL,
      subject_id TEXT NOT NULL,
      unit_plan_created INTEGER NOT NULL DEFAULT 0,
      unit_plan_reviewed INTEGER NOT NULL DEFAULT 0,
      unit_plan_finalised INTEGER NOT NULL DEFAULT 0,
      copy_written INTEGER NOT NULL DEFAULT 0,
      layout_created INTEGER NOT NULL DEFAULT 0,
      illustrations_created INTEGER NOT NULL DEFAULT 0,
      videos_created INTEGER NOT NULL DEFAULT 0,
      google_slides_created INTEGER NOT NULL DEFAULT 0,
      review_1_completed INTEGER NOT NULL DEFAULT 0,
      review_2_completed INTEGER NOT NULL DEFAULT 0,
      final_review_completed INTEGER NOT NULL DEFAULT 0,
      editing_status TEXT,
      code TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (language_id) REFERENCES languages (id),
      FOREIGN KEY (curriculum_id) REFERENCES curricula (id),
      FOREIGN KEY (grade_id) REFERENCES grades (id),
      FOREIGN KEY (semester_id) REFERENCES semesters (id),
      FOREIGN KEY (subject_id) REFERENCES subjects (id)
    )
    ''');

    // Create lessons table
    await db.execute('''
    CREATE TABLE lessons (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      number INTEGER NOT NULL,
      estimated_time INTEGER,
      objectives TEXT,
      is_published INTEGER NOT NULL DEFAULT 0,
      is_broken INTEGER NOT NULL DEFAULT 0,
      google_slides_link TEXT,
      google_slides_id TEXT,
      normal_pdf TEXT,
      encrypted_pdf TEXT,
      password TEXT,
      tags TEXT,
      code TEXT,
      chapter_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (chapter_id) REFERENCES chapters (id)
    )
    ''');

    // Create chapter_lessons table (junction table)
    await db.execute('''
    CREATE TABLE chapter_lessons (
      id TEXT PRIMARY KEY,
      chapter_id TEXT NOT NULL,
      lesson_id TEXT NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (chapter_id) REFERENCES chapters (id),
      FOREIGN KEY (lesson_id) REFERENCES lessons (id)
    )
    ''');

    // Create slides table
    await db.execute('''
    CREATE TABLE slides (
      id TEXT PRIMARY KEY,
      title TEXT,
      content TEXT,
      number INTEGER NOT NULL,
      slide_type TEXT,
      lesson_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (lesson_id) REFERENCES lessons (id)
    )
    ''');

    // Create lesson_feedbacks table
    await db.execute('''
    CREATE TABLE lesson_feedbacks (
      id TEXT PRIMARY KEY,
      rating INTEGER,
      comment TEXT,
      user_id TEXT NOT NULL,
      lesson_id TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (lesson_id) REFERENCES lessons (id)
    )
    ''');

    // Create bookmarks table (modified to use string user_id instead of foreign key)
    await db.execute('''
    CREATE TABLE bookmarks (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      chapter_id TEXT,
      lesson_id TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (chapter_id) REFERENCES chapters (id),
      FOREIGN KEY (lesson_id) REFERENCES lessons (id)
    )
    ''');

    // Create downloads table (modified to use string user_id instead of foreign key)
    await db.execute('''
    CREATE TABLE downloads (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      chapter_id TEXT,
      lesson_id TEXT,
      is_downloaded INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (chapter_id) REFERENCES chapters (id),
      FOREIGN KEY (lesson_id) REFERENCES lessons (id)
    )
    ''');

    // Create sync_status table to keep track of last sync times
    await db.execute('''
    CREATE TABLE sync_status (
      table_name TEXT PRIMARY KEY,
      last_synced_at TEXT NOT NULL
    )
    ''');

    debugPrint('SQLite database tables created successfully');
  }

  // Upgrade database schema if needed
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // Handle upgrade to version 2
      debugPrint('Upgrading to database version 2');

      // Check if schools table exists
      final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='schools'",
      );

      if (tablesResult.isNotEmpty) {
        try {
          // Create a backup of the current schools table
          await db.execute('ALTER TABLE schools RENAME TO schools_old');
          debugPrint('Renamed existing schools table to schools_old');

          // Create the new schools table with the updated schema
          await db.execute('''
          CREATE TABLE schools (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            code TEXT,
            type TEXT,
            address_line_1 TEXT,
            address_line_2 TEXT,
            city TEXT,
            state TEXT,
            pincode TEXT,
            district TEXT,
            phone TEXT,
            email TEXT,
            website TEXT,
            established_date TEXT,
            principal_name TEXT,
            number_of_students INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (state) REFERENCES states (id)
          )
          ''');
          debugPrint('Created new schools table with updated schema');

          // Copy data from the old table to the new one
          await db.execute('''
          INSERT INTO schools (id, title, code, created_at, updated_at) 
          SELECT id, title, code, created_at, updated_at FROM schools_old
          ''');
          debugPrint('Copied data from old schools table to new one');

          // Drop the old table
          await db.execute('DROP TABLE schools_old');
          debugPrint('Dropped old schools table');
        } catch (e) {
          debugPrint('Error upgrading schools table: $e');
          // If anything goes wrong, make sure we still have a schools table
          final schoolsExist = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='schools'",
          );

          if (schoolsExist.isEmpty) {
            // If schools table doesn't exist, create it
            await db.execute('''
            CREATE TABLE schools (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              code TEXT,
              type TEXT,
              address_line_1 TEXT,
              address_line_2 TEXT,
              city TEXT,
              state TEXT,
              pincode TEXT,
              district TEXT,
              phone TEXT,
              email TEXT,
              website TEXT,
              established_date TEXT,
              principal_name TEXT,
              number_of_students INTEGER DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (state) REFERENCES states (id)
            )
            ''');
            debugPrint('Created new schools table after error');
          }
        }
      }

      // Clear sync status to force a fresh sync
      try {
        await db.delete('sync_status');
        debugPrint('Cleared sync status for fresh sync');
      } catch (e) {
        debugPrint('Error clearing sync status: $e');
      }
    }
  }

  // Insert a row into a table
  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      table,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all rows from a table
  Future<List<Map<String, dynamic>>> queryAllRows(String table) async {
    final db = await instance.database;
    return await db.query(table);
  }

  // Get rows with specific condition
  Future<List<Map<String, dynamic>>> queryRows(
    String table,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    final db = await instance.database;
    return await db.query(table, where: whereClause, whereArgs: whereArgs);
  }

  // Update a row
  Future<int> update(
    String table,
    Map<String, dynamic> row,
    String idColumn,
    dynamic id,
  ) async {
    final db = await instance.database;
    return await db.update(table, row, where: '$idColumn = ?', whereArgs: [id]);
  }

  // Delete a row
  Future<int> delete(String table, String idColumn, dynamic id) async {
    final db = await instance.database;
    return await db.delete(table, where: '$idColumn = ?', whereArgs: [id]);
  }

  // Delete all rows from a table
  Future<int> deleteAllRows(String table) async {
    final db = await instance.database;
    return await db.delete(table);
  }

  // Execute a raw SQL query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await instance.database;
    return await db.rawQuery(sql, arguments);
  }

  // Execute a raw SQL command
  //Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
  //  final db = await instance.database;
  //  return await db.rawExecute(sql, arguments);
  //}

  // Insert multiple rows in a transaction
  Future<void> insertMany(String table, List<Map<String, dynamic>> rows) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var row in rows) {
      batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  // Check if a table exists
  Future<bool> tableExists(String tableName) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  // Get count of rows in a table
  Future<int> getCount(String table) async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Get the last sync time for a table
  Future<String?> getLastSyncTime(String tableName) async {
    final db = await instance.database;
    final result = await db.query(
      'sync_status',
      where: 'table_name = ?',
      whereArgs: [tableName],
    );

    if (result.isNotEmpty) {
      return result.first['last_synced_at'] as String?;
    }
    return null;
  }

  // Update the last sync time for a table
  Future<void> updateLastSyncTime(String tableName, String syncTime) async {
    final db = await instance.database;
    await db.insert('sync_status', {
      'table_name': tableName,
      'last_synced_at': syncTime,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Delete the database file completely to force recreation
  Future<void> clearDatabase() async {
    try {
      // Close the database if it's open
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Get the database path
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'meghshala.db');

      // Delete the file
      if (await databaseExists(path)) {
        await deleteDatabase(path);
        debugPrint('Database file deleted successfully');
      }
    } catch (e) {
      debugPrint('Error deleting database file: $e');
      throw Exception('Failed to delete database file: $e');
    }
  }

  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }
}
