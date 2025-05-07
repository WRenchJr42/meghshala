import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Bookmark service to manage bookmarked chapters and lessons
class BookmarkService {
  static const String _bookmarkedChaptersKey = 'bookmarked_chapters';
  static const String _bookmarkedLessonsKey = 'bookmarked_lessons';

  // Singleton pattern
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  // Toggle chapter bookmark status
  Future<bool> toggleChapterBookmark(Map<String, dynamic> chapter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> bookmarkedChapters =
          prefs.getStringList(_bookmarkedChaptersKey) ?? [];

      final String chapterId = chapter['id'];
      bool isBookmarked = false;

      if (bookmarkedChapters.contains(chapterId)) {
        // If already bookmarked, remove it
        bookmarkedChapters.remove(chapterId);
        isBookmarked = false;
      } else {
        // If not bookmarked, add it
        bookmarkedChapters.add(chapterId);
        isBookmarked = true;

        // Also save the chapter data
        await _saveChapterData(chapter);
      }

      await prefs.setStringList(_bookmarkedChaptersKey, bookmarkedChapters);
      return isBookmarked;
    } catch (e) {
      debugPrint('Error toggling chapter bookmark: $e');
      return false;
    }
  }

  // Toggle lesson bookmark status
  Future<bool> toggleLessonBookmark(Map<String, dynamic> lesson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> bookmarkedLessons =
          prefs.getStringList(_bookmarkedLessonsKey) ?? [];

      final String lessonId = lesson['id'];
      bool isBookmarked = false;

      if (bookmarkedLessons.contains(lessonId)) {
        // If already bookmarked, remove it
        bookmarkedLessons.remove(lessonId);
        isBookmarked = false;
      } else {
        // If not bookmarked, add it
        bookmarkedLessons.add(lessonId);
        isBookmarked = true;

        // Also save the lesson data
        await _saveLessonData(lesson);
      }

      await prefs.setStringList(_bookmarkedLessonsKey, bookmarkedLessons);
      return isBookmarked;
    } catch (e) {
      debugPrint('Error toggling lesson bookmark: $e');
      return false;
    }
  }

  // Check if a chapter is bookmarked
  Future<bool> isChapterBookmarked(String chapterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> bookmarkedChapters =
          prefs.getStringList(_bookmarkedChaptersKey) ?? [];

      return bookmarkedChapters.contains(chapterId);
    } catch (e) {
      debugPrint('Error checking chapter bookmark status: $e');
      return false;
    }
  }

  // Check if a lesson is bookmarked
  Future<bool> isLessonBookmarked(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> bookmarkedLessons =
          prefs.getStringList(_bookmarkedLessonsKey) ?? [];

      return bookmarkedLessons.contains(lessonId);
    } catch (e) {
      debugPrint('Error checking lesson bookmark status: $e');
      return false;
    }
  }

  // Get all bookmarked chapters
  Future<List<Map<String, dynamic>>> getBookmarkedChapters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> bookmarkedChapters =
          prefs.getStringList(_bookmarkedChaptersKey) ?? [];

      List<Map<String, dynamic>> chapters = [];

      for (String chapterId in bookmarkedChapters) {
        final String? chapterData = prefs.getString('chapter_$chapterId');
        if (chapterData != null) {
          chapters.add(json.decode(chapterData));
        }
      }

      return chapters;
    } catch (e) {
      debugPrint('Error getting bookmarked chapters: $e');
      return [];
    }
  }

  // Get all bookmarked lessons
  Future<List<Map<String, dynamic>>> getBookmarkedLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> bookmarkedLessons =
          prefs.getStringList(_bookmarkedLessonsKey) ?? [];

      List<Map<String, dynamic>> lessons = [];

      for (String lessonId in bookmarkedLessons) {
        final String? lessonData = prefs.getString('lesson_$lessonId');
        if (lessonData != null) {
          lessons.add(json.decode(lessonData));
        }
      }

      return lessons;
    } catch (e) {
      debugPrint('Error getting bookmarked lessons: $e');
      return [];
    }
  }

  // Save chapter data to SharedPreferences
  Future<void> _saveChapterData(Map<String, dynamic> chapter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String chapterId = chapter['id'];

      await prefs.setString('chapter_$chapterId', json.encode(chapter));
    } catch (e) {
      debugPrint('Error saving chapter data: $e');
    }
  }

  // Save lesson data to SharedPreferences
  Future<void> _saveLessonData(Map<String, dynamic> lesson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String lessonId = lesson['id'];

      await prefs.setString('lesson_$lessonId', json.encode(lesson));
    } catch (e) {
      debugPrint('Error saving lesson data: $e');
    }
  }
}
