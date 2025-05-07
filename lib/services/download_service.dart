import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Download service to manage downloaded chapters and lessons
class DownloadService {
  static const String _downloadedChaptersKey = 'downloaded_chapters';
  static const String _downloadedLessonsKey = 'downloaded_lessons';

  // Singleton pattern
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  // Get all downloaded chapters
  Future<List<Map<String, dynamic>>> getDownloadedChapters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedChapters =
          prefs.getStringList(_downloadedChaptersKey) ?? [];

      List<Map<String, dynamic>> chapters = [];

      for (String chapterId in downloadedChapters) {
        final String? chapterData = prefs.getString(
          'downloaded_chapter_$chapterId',
        );
        if (chapterData != null) {
          chapters.add(json.decode(chapterData));
        }
      }

      return chapters;
    } catch (e) {
      debugPrint('Error getting downloaded chapters: $e');
      return [];
    }
  }

  // Get all downloaded lessons
  Future<List<Map<String, dynamic>>> getDownloadedLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedLessons =
          prefs.getStringList(_downloadedLessonsKey) ?? [];

      List<Map<String, dynamic>> lessons = [];

      for (String lessonId in downloadedLessons) {
        final String? lessonData = prefs.getString(
          'downloaded_lesson_$lessonId',
        );
        if (lessonData != null) {
          lessons.add(json.decode(lessonData));
        }
      }

      return lessons;
    } catch (e) {
      debugPrint('Error getting downloaded lessons: $e');
      return [];
    }
  }

  // Download a chapter for offline access
  Future<bool> downloadChapter(Map<String, dynamic> chapter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedChapters =
          prefs.getStringList(_downloadedChaptersKey) ?? [];

      final String chapterId = chapter['id'];

      if (!downloadedChapters.contains(chapterId)) {
        downloadedChapters.add(chapterId);
        await prefs.setStringList(_downloadedChaptersKey, downloadedChapters);

        // Save the chapter data
        await prefs.setString(
          'downloaded_chapter_$chapterId',
          json.encode(chapter),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error downloading chapter: $e');
      return false;
    }
  }

  // Download a lesson for offline access
  Future<bool> downloadLesson(Map<String, dynamic> lesson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedLessons =
          prefs.getStringList(_downloadedLessonsKey) ?? [];

      final String lessonId = lesson['id'];

      if (!downloadedLessons.contains(lessonId)) {
        downloadedLessons.add(lessonId);
        await prefs.setStringList(_downloadedLessonsKey, downloadedLessons);

        // Save the lesson data
        await prefs.setString(
          'downloaded_lesson_$lessonId',
          json.encode(lesson),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error downloading lesson: $e');
      return false;
    }
  }

  // Check if a chapter is downloaded
  Future<bool> isChapterDownloaded(String chapterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedChapters =
          prefs.getStringList(_downloadedChaptersKey) ?? [];

      return downloadedChapters.contains(chapterId);
    } catch (e) {
      debugPrint('Error checking if chapter is downloaded: $e');
      return false;
    }
  }

  // Check if a lesson is downloaded
  Future<bool> isLessonDownloaded(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedLessons =
          prefs.getStringList(_downloadedLessonsKey) ?? [];

      return downloadedLessons.contains(lessonId);
    } catch (e) {
      debugPrint('Error checking if lesson is downloaded: $e');
      return false;
    }
  }

  // Remove a downloaded chapter
  Future<bool> removeDownloadedChapter(String chapterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedChapters =
          prefs.getStringList(_downloadedChaptersKey) ?? [];

      if (downloadedChapters.contains(chapterId)) {
        downloadedChapters.remove(chapterId);
        await prefs.setStringList(_downloadedChaptersKey, downloadedChapters);
        await prefs.remove('downloaded_chapter_$chapterId');
      }

      return true;
    } catch (e) {
      debugPrint('Error removing downloaded chapter: $e');
      return false;
    }
  }

  // Remove a downloaded lesson
  Future<bool> removeDownloadedLesson(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedLessons =
          prefs.getStringList(_downloadedLessonsKey) ?? [];

      if (downloadedLessons.contains(lessonId)) {
        downloadedLessons.remove(lessonId);
        await prefs.setStringList(_downloadedLessonsKey, downloadedLessons);
        await prefs.remove('downloaded_lesson_$lessonId');
      }

      return true;
    } catch (e) {
      debugPrint('Error removing downloaded lesson: $e');
      return false;
    }
  }
}
