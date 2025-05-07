import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

final supabase = Supabase.instance.client;

// Custom enums matching Supabase database types
enum UserType { TEACHER, HEADMASTER, TUITION_TEACHER, PARENT, OTHERS, STUDENT }

enum Qualification { BACHELORS, MASTERS, PHD }

enum Experience {
  // Using Supabase's exact values
  @JsonValue('1-5 YEARS')
  ONE_TO_FIVE_YEARS,
  @JsonValue('5-10 YEARS')
  FIVE_TO_TEN_YEARS,
  @JsonValue('10-15 YEARS')
  TEN_TO_FIFTEEN_YEARS,
  @JsonValue('15-20 YEARS')
  FIFTEEN_TO_TWENTY_YEARS,
  @JsonValue('20+ YEARS')
  TWENTY_PLUS_YEARS,
}

enum Gender { MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY }

enum SchoolType { GOVERNMENT, PRIVATE }

enum ContentType { VIDEO, PDF }

enum SlideType {
  STUDENT_SLIDE,
  TEACHER_INSTRUCTION,
  ASSESSMENT,
  ACTIVITY_SLIDE,
  VIDEO,
}

enum EditingStatus {
  NEW,
  UNIT_PLAN,
  CREATION,
  INTERNAL_REVIEW,
  EXTERNAL_REVIEW,
  READY_FOR_EDITING,
  COPY_EDITING,
  LAYOUT,
  MEDIAS,
  VIDEOS,
  FINAL_CHECK,
  READY_FOR_UPLOAD,
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // User data
  final Map<String, dynamic> _userData = {
    'first_name': '',
    'last_name': '',
    'dob': '',
    'phone': '',
    'school_id': null,
    'user_type': UserType.TEACHER,
    'qualification': null,
    'experience': null,
    'gender': null,
    'language_id': null,
    'assessment_enabled': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        actions: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _previousStep,
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[300],
          ),

          // Step title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _getStepTitle(_currentStep),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          // Main content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                PersonalInfoStep(userData: _userData, onComplete: _nextStep),
                RoleSelectionStep(userData: _userData, onComplete: _nextStep),
                SchoolSelectionStep(userData: _userData, onComplete: _nextStep),
                CurriculumSelectionStep(
                  userData: _userData,
                  onComplete: _completeRegistration,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Profile Setup';
      case 1:
        return 'Who are you?';
      case 2:
        return 'Find my School';
      case 3:
        return 'Learning Preferences';
    }
    return 'Registration';
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeRegistration() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get current user and session
      User? user = supabase.auth.currentUser;
      Session? session = await supabase.auth.currentSession;

      // If there is no session, prompt the user to log in
      if (session == null || user == null) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in before completing registration.'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      // Create base profile data
      final Map<String, dynamic> profileData = {
        'id': user.id,
        'phone': _userData['phone'] ?? '', // Ensure phone is never null
        'first_name':
            _userData['first_name'] ?? '', // Ensure first_name is never null
        'last_name':
            _userData['last_name'] ?? '', // Make last_name empty string if null
        'assessment_enabled': _userData['assessment_enabled'] ?? false,
      };

      // Convert enum values to strings that match the database's expected format
      if (_userData['user_type'] != null) {
        profileData['user_type'] =
            _userData['user_type'].toString().split('.').last;
      } else {
        // Default to TEACHER if not specified
        profileData['user_type'] = 'TEACHER';
      }

      // Add school_id if present
      if (_userData['school_id'] != null) {
        profileData['school_id'] = _userData['school_id'];
      }

      // Add date of birth if present
      if (_userData['dob'] != null && _userData['dob'].toString().isNotEmpty) {
        profileData['dob'] = _userData['dob'];
      }

      // Add qualification if present
      if (_userData['qualification'] != null) {
        profileData['qualification'] =
            _userData['qualification'].toString().split('.').last;
      }

      // Add experience if present
      if (_userData['experience'] != null) {
        // Make sure we're using the correct format for experience values
        final experienceValue =
            _userData['experience'].toString().split('.').last;
        switch (experienceValue) {
          case 'ONE_TO_FIVE_YEARS':
            profileData['experience'] = '1-5 YEARS';
            break;
          case 'FIVE_TO_TEN_YEARS':
            profileData['experience'] = '5-10 YEARS';
            break;
          case 'TEN_TO_FIFTEEN_YEARS':
            profileData['experience'] = '10-15 YEARS';
            break;
          case 'FIFTEEN_TO_TWENTY_YEARS':
            profileData['experience'] = '15-20 YEARS';
            break;
          case 'TWENTY_PLUS_YEARS':
            profileData['experience'] = '20+ YEARS';
            break;
          default:
            profileData['experience'] = experienceValue;
        }
      }

      // Add gender if present
      if (_userData['gender'] != null) {
        profileData['gender'] = _userData['gender'].toString().split('.').last;
      }

      // Handle language selection
      if (_userData['selected_language'] != null &&
          _userData['selected_language']['id'] != null) {
        profileData['language_id'] = _userData['selected_language']['id'];
      } else if (_userData['language_id'] != null) {
        profileData['language_id'] = _userData['language_id'];
      }

      // Log the exact data we're trying to insert for debugging
      debugPrint('Attempting to insert user profile with data: $profileData');

      // Use upsert to handle both insertion and updates
      final response =
          await supabase.from('user_profiles').upsert(profileData).select();
      debugPrint('Upsert response: $response');

      // Mark registration as successful since primary profile data is saved
      bool preferencesError = false;
      List<String> errorMessages = [];

      // Get a list of available tables to check if preference tables exist
      try {
        // Check if tables exist before trying to insert data
        final availableTables = await supabase.rpc('list_tables').select();
        debugPrint('Available tables: $availableTables');

        final tableNames = List<String>.from(
          availableTables.map((table) => table['tablename'] ?? '').toList(),
        );

        // Handle student-specific preferences
        if (_userData['user_type'] == UserType.STUDENT) {
          // Only save curriculum preferences if the table exists
          if (tableNames.contains('user_curriculum_preferences')) {
            try {
              if (_userData['selected_curriculum'] != null &&
                  _userData['selected_curriculum']['id'] != null) {
                debugPrint(
                  'Saving curriculum preference: ${_userData['selected_curriculum']['id']}',
                );

                await supabase.from('user_curriculum_preferences').upsert({
                  'user_id': user.id,
                  'curriculum_id': _userData['selected_curriculum']['id'],
                  'is_primary': true,
                  'created_at': DateTime.now().toIso8601String(),
                });
              }
            } catch (e) {
              debugPrint('Error saving curriculum preference: $e');
              preferencesError = true;
              errorMessages.add('Curriculum preference: ${e.toString()}');
            }
          } else {
            debugPrint(
              'Table user_curriculum_preferences does not exist, skipping',
            );
          }

          // Only save grade preferences if the table exists
          if (tableNames.contains('user_grade_preferences')) {
            try {
              if (_userData['selected_grade'] != null &&
                  _userData['selected_grade']['id'] != null) {
                debugPrint(
                  'Saving grade preference: ${_userData['selected_grade']['id']}',
                );

                await supabase.from('user_grade_preferences').upsert({
                  'user_id': user.id,
                  'grade_id': _userData['selected_grade']['id'],
                  'is_primary': true,
                  'created_at': DateTime.now().toIso8601String(),
                });
              }
            } catch (e) {
              debugPrint('Error saving grade preference: $e');
              preferencesError = true;
              errorMessages.add('Grade preference: ${e.toString()}');
            }
          } else {
            debugPrint('Table user_grade_preferences does not exist, skipping');
          }

          // Only save semester preferences if the table exists
          if (tableNames.contains('user_semester_preferences')) {
            try {
              if (_userData['selected_semester'] != null &&
                  _userData['selected_semester']['id'] != null) {
                debugPrint(
                  'Saving semester preference: ${_userData['selected_semester']['id']}',
                );

                await supabase.from('user_semester_preferences').upsert({
                  'user_id': user.id,
                  'semester_id': _userData['selected_semester']['id'],
                  'is_primary': true,
                  'created_at': DateTime.now().toIso8601String(),
                });
              }
            } catch (e) {
              debugPrint('Error saving semester preference: $e');
              preferencesError = true;
              errorMessages.add('Semester preference: ${e.toString()}');
            }
          } else {
            debugPrint(
              'Table user_semester_preferences does not exist, skipping',
            );
          }
        } else {
          // For non-student users, save curriculum preferences if provided
          if (tableNames.contains('user_curriculum_preferences')) {
            try {
              if (_userData['curriculum']?.isNotEmpty == true) {
                final List<Map<String, dynamic>> curriculumPrefs = [];
                for (var curriculum in _userData['curriculum']) {
                  if (curriculum != null && curriculum['id'] != null) {
                    curriculumPrefs.add({
                      'user_id': user.id,
                      'curriculum_id': curriculum['id'],
                      'is_primary':
                          curriculumPrefs.isEmpty, // First one is primary
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  }
                }

                if (curriculumPrefs.isNotEmpty) {
                  debugPrint(
                    'Saving curriculum preferences for non-student: $curriculumPrefs',
                  );
                  await supabase
                      .from('user_curriculum_preferences')
                      .upsert(curriculumPrefs);
                }
              }
            } catch (e) {
              debugPrint(
                'Error saving curriculum preferences for non-student: $e',
              );
              preferencesError = true;
              errorMessages.add('Curriculum preferences: ${e.toString()}');
            }
          } else {
            debugPrint(
              'Table user_curriculum_preferences does not exist, skipping',
            );
          }
        }
      } catch (e) {
        // If we can't list tables, just skip all preference saving
        debugPrint('Error checking available tables, skipping preferences: $e');
      }

      // Log success of profile creation
      debugPrint(
        'User profile saved successfully: ${profileData['first_name']} ${profileData['last_name']}',
      );

      // Show warning about preferences if needed, but don't block registration completion
      if (preferencesError) {
        debugPrint(
          'Some preferences could not be saved: ${errorMessages.join(', ')}',
        );

        // Only show the warning if we're still in the context
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // Close loading dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Your profile was created, but some preferences could not be saved.',
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Ok',
                onPressed: () {
                  // Navigate to home screen after acknowledgment
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
            ),
          );
        } else {
          // If we can't show the dialog, just navigate to home
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // No preference errors, navigate directly to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      debugPrint('Detailed error saving profile: $e');

      // Extract more information from the error for debugging
      String errorMessage = 'Error saving profile information.';

      if (e is PostgrestException) {
        final postgrestError = e as PostgrestException;
        errorMessage =
            'Database error: ${postgrestError.message}. Code: ${postgrestError.code}';
        debugPrint(
          'PostgrestException details: code=${postgrestError.code}, message=${postgrestError.message}, details=${postgrestError.details}',
        );
      }

      // Close loading dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _completeRegistration,
          ),
        ),
      );
      return;
    }
  }
}

// Step 1: Personal Information
class PersonalInfoStep extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onComplete;

  const PersonalInfoStep({
    Key? key,
    required this.userData,
    required this.onComplete,
  }) : super(key: key);

  @override
  _PersonalInfoStepState createState() => _PersonalInfoStepState();
}

class _PersonalInfoStepState extends State<PersonalInfoStep> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _dobController;
  late TextEditingController _phoneController;
  Gender? _selectedGender;
  String? _profilePicturePath;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.userData['first_name'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.userData['last_name'] ?? '',
    );
    _dobController = TextEditingController(text: widget.userData['dob'] ?? '');
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );
    _selectedGender = widget.userData['gender'];
    _profilePicturePath = widget.userData['profile_picture_path'];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile picture picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        _profilePicturePath != null
                            ? FileImage(File(_profilePicturePath!))
                            : null,
                    child:
                        _profilePicturePath == null
                            ? const Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey,
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().subtract(
                      const Duration(days: 365 * 18),
                    ),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dobController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(pickedDate);
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your date of birth';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Gender Dropdown
              DropdownButtonFormField<Gender>(
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                value: _selectedGender,
                items:
                    Gender.values.map((gender) {
                      return DropdownMenuItem<Gender>(
                        value: gender,
                        child: Text(_formatGender(gender)),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedGender = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select your gender';
                  }
                  return null;
                },
                hint: const Text('Select Gender'),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Save data
                    widget.userData['first_name'] = _firstNameController.text;
                    widget.userData['last_name'] = _lastNameController.text;
                    widget.userData['dob'] = _dobController.text;
                    widget.userData['phone'] = _phoneController.text;
                    widget.userData['gender'] = _selectedGender;
                    widget.userData['profile_picture_path'] =
                        _profilePicturePath;

                    // Move to next step
                    widget.onComplete();
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pick image from gallery or camera
  Future<void> _pickImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      _profilePicturePath = pickedFile.path;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      _profilePicturePath = pickedFile.path;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Format gender enum for display
  String _formatGender(Gender gender) {
    switch (gender) {
      case Gender.MALE:
        return 'Male';
      case Gender.FEMALE:
        return 'Female';
      case Gender.OTHER:
        return 'Other';
      case Gender.PREFER_NOT_TO_SAY:
        return 'Prefer not to say';
      default:
        return gender.toString().split('.').last.replaceAll('_', ' ');
    }
  }
}

// Step 2: School Selection
class SchoolSelectionStep extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onComplete;

  const SchoolSelectionStep({
    Key? key,
    required this.userData,
    required this.onComplete,
  }) : super(key: key);

  @override
  _SchoolSelectionStepState createState() => _SchoolSelectionStepState();
}

class _SchoolSelectionStepState extends State<SchoolSelectionStep> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _schoolResults = [];
  bool _isSearching = false;
  bool _showAddNewForm = false;
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _schoolAddressController =
      TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // New state-related variables
  List<Map<String, dynamic>> _states = [];
  Map<String, dynamic>? _selectedState;
  bool _loadingStates = false;

  // New school type-related variables
  SchoolType? _selectedSchoolType;

  @override
  void initState() {
    super.initState();
    // Load states when the widget initializes
    _loadStates();
  }

  // Load states from the database
  Future<void> _loadStates() async {
    setState(() {
      _loadingStates = true;
    });

    try {
      final data = await supabase.from('states').select().order('title');

      setState(() {
        _states = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading states: $e');
    } finally {
      setState(() {
        _loadingStates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_showAddNewForm) ...[
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search for your school',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _schoolResults = [];
                    });
                  },
                ),
              ),
              onChanged: _searchSchools,
            ),
            const SizedBox(height: 16),
            // Search results
            Expanded(
              child:
                  _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _schoolResults.isEmpty &&
                          _searchController.text.isNotEmpty
                      ? _buildNoResultsFound()
                      : ListView.builder(
                        itemCount: _schoolResults.length,
                        itemBuilder: (context, index) {
                          final school = _schoolResults[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                school['title'],
                              ), // Changed from 'name' to 'title'
                              subtitle: Text(
                                school['address_line_1'] ?? '',
                              ), // Changed from 'address' to 'address_line_1'
                              onTap: () {
                                setState(() {
                                  widget.userData['school_id'] = school['id'];
                                });
                                widget.onComplete();
                              },
                            ),
                          );
                        },
                      ),
            ),
          ] else ...[
            // Add new school form
            _buildAddNewSchoolForm(),
          ],

          // Bottom button
          if (!_showAddNewForm)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAddNewForm = true;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add New School'),
            ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No schools found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different search or add a new school',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showAddNewForm = true;
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add New School'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewSchoolForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Add New School',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _schoolNameController,
          decoration: const InputDecoration(
            labelText: 'School Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _schoolAddressController,
          decoration: const InputDecoration(
            labelText: 'School Address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child:
                  _loadingStates
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedState,
                        items:
                            _states.map((state) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: state,
                                child: Text(state['title'] ?? 'Unknown'),
                              );
                            }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedState = newValue;
                          });
                        },
                        hint: const Text('Select State'),
                        isExpanded: true,
                      ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<SchoolType>(
          decoration: const InputDecoration(
            labelText: 'School Type',
            border: OutlineInputBorder(),
          ),
          value: _selectedSchoolType,
          items:
              SchoolType.values.map((type) {
                return DropdownMenuItem<SchoolType>(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedSchoolType = newValue;
            });
          },
          hint: const Text('Select School Type'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showAddNewForm = false;
                    _selectedState = null;
                  });
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitNewSchool,
                child: const Text('Save School'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _searchSchools(String query) async {
    if (query.isEmpty) {
      setState(() {
        _schoolResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await supabase
          .from('schools')
          .select()
          .ilike('title', '%$query%') // Using 'title' instead of 'name'
          .limit(10);

      setState(() {
        _schoolResults = List<Map<String, dynamic>>.from(results);
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Error searching schools: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _submitNewSchool() async {
    if (_schoolNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('School name is required')));
      return;
    }

    if (_selectedState == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a state')));
      return;
    }

    if (_selectedSchoolType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a school type')),
      );
      return;
    }

    // Show loading indicator
    setState(() {
      _isSearching = true;
    });

    try {
      // Create new school in the database
      final result =
          await supabase.from('schools').insert({
            'title': _schoolNameController.text,
            'address_line_1': _schoolAddressController.text,
            'city': _cityController.text,
            'state':
                _selectedState!['id'], // Using the ID from the selected state
            'type':
                _selectedSchoolType
                    .toString()
                    .split('.')
                    .last, // Using the enum value for school type
            'created_at': DateTime.now().toIso8601String(),
          }).select();

      if (result.isNotEmpty) {
        final newSchool = result[0];

        // Save school to user data
        setState(() {
          widget.userData['school_id'] = newSchool['id'];
        });

        // Move to next step
        widget.onComplete();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding school: $e')));
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
}

// Step 3: Role Selection
class RoleSelectionStep extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onComplete;

  const RoleSelectionStep({
    Key? key,
    required this.userData,
    required this.onComplete,
  }) : super(key: key);

  @override
  _RoleSelectionStepState createState() => _RoleSelectionStepState();
}

class _RoleSelectionStepState extends State<RoleSelectionStep> {
  // Track if we're showing the qualification form
  bool _showQualificationForm = false;
  Qualification? _selectedQualification;
  Experience? _selectedExperience;

  // Mapping Supabase user_types enum to UI elements
  final List<Map<String, dynamic>> roleOptions = [
    {
      'type': UserType.TEACHER,
      'title': 'Teacher',
      'icon': Icons.school,
      'needsQualification': true,
    },
    {
      'type': UserType.STUDENT,
      'title': 'Student',
      'icon': Icons.person,
      'needsQualification': false,
    },
    {
      'type': UserType.HEADMASTER,
      'title': 'Headmaster',
      'icon': Icons.admin_panel_settings,
      'needsQualification': true,
    },
    {
      'type': UserType.TUITION_TEACHER,
      'title': 'Tuition Teacher',
      'icon': Icons.cast_for_education,
      'needsQualification': true,
    },
    {
      'type': UserType.PARENT,
      'title': 'Parent',
      'icon': Icons.family_restroom,
      'needsQualification': false,
    },
    {
      'type': UserType.OTHERS,
      'title': 'Others',
      'icon': Icons.more_horiz,
      'needsQualification': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_showQualificationForm) {
      return _buildQualificationForm();
    }

    return _buildRoleSelection();
  }

  Widget _buildRoleSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Who are you?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: roleOptions.length,
              itemBuilder: (context, index) {
                final role = roleOptions[index];
                final bool isSelected =
                    widget.userData['user_type'] == role['type'];

                return InkWell(
                  onTap: () {
                    setState(() {
                      widget.userData['user_type'] = role['type'];

                      // If this role requires qualification details, show the form
                      if (role['needsQualification'] == true) {
                        _showQualificationForm = true;
                      } else {
                        // Otherwise, skip to the next step
                        widget.onComplete();
                      }
                    });
                  },
                  child: Card(
                    color:
                        isSelected
                            ? Theme.of(context).primaryColor.withOpacity(0.1)
                            : null,
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side:
                          isSelected
                              ? BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              )
                              : BorderSide.none,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          role['icon'] as IconData,
                          size: 40,
                          color:
                              isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          role['title'] as String,
                          style: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                isSelected
                                    ? Theme.of(context).primaryColor
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualificationForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Professional Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Qualification dropdown
          DropdownButtonFormField<Qualification>(
            decoration: const InputDecoration(
              labelText: 'Highest Qualification',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.school),
            ),
            value: _selectedQualification,
            items:
                Qualification.values.map((qualification) {
                  return DropdownMenuItem<Qualification>(
                    value: qualification,
                    child: Text(_formatEnum(qualification.toString())),
                  );
                }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedQualification = newValue;
                widget.userData['qualification'] = newValue;
              });
            },
            hint: const Text('Select your qualification'),
          ),

          const SizedBox(height: 16),

          // Experience dropdown
          DropdownButtonFormField<Experience>(
            decoration: const InputDecoration(
              labelText: 'Years of Experience',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.work),
            ),
            value: _selectedExperience,
            items:
                Experience.values.map((experience) {
                  return DropdownMenuItem<Experience>(
                    value: experience,
                    child: Text(_formatExperience(experience)),
                  );
                }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedExperience = newValue;
                widget.userData['experience'] = newValue;
              });
            },
            hint: const Text('Select your experience'),
          ),

          const SizedBox(height: 24),

          // Gender selection with radio buttons
          const Text(
            'Gender',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 16,
            children:
                Gender.values.map((gender) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<Gender>(
                        value: gender,
                        groupValue: widget.userData['gender'],
                        onChanged: (value) {
                          setState(() {
                            widget.userData['gender'] = value;
                          });
                        },
                      ),
                      Text(_formatEnum(gender.toString())),
                    ],
                  );
                }).toList(),
          ),

          const Spacer(),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showQualificationForm = false;
                    });
                  },
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Validate that required fields are filled
                    if (_selectedQualification == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select your qualification'),
                        ),
                      );
                      return;
                    }

                    if (_selectedExperience == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select your experience'),
                        ),
                      );
                      return;
                    }

                    if (widget.userData['gender'] == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select your gender'),
                        ),
                      );
                      return;
                    }

                    // Move to next step
                    widget.onComplete();
                  },
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to format enum values for display
  String _formatEnum(String enumValue) {
    // Get the part after the dot
    final parts = enumValue.split('.');
    if (parts.length > 1) {
      String value = parts[1];

      // Replace underscores with spaces
      value = value.replaceAll('_', ' ');

      // Convert to title case
      return value[0] + value.substring(1).toLowerCase();
    }
    return enumValue;
  }

  // Helper method to format experience enum values
  String _formatExperience(Experience experience) {
    switch (experience) {
      case Experience.ONE_TO_FIVE_YEARS:
        return '1-5 Years';
      case Experience.FIVE_TO_TEN_YEARS:
        return '5-10 Years';
      case Experience.TEN_TO_FIFTEEN_YEARS:
        return '10-15 Years';
      case Experience.FIFTEEN_TO_TWENTY_YEARS:
        return '15-20 Years';
      case Experience.TWENTY_PLUS_YEARS:
        return '20+ Years';
      default:
        return experience.toString().split('.').last.replaceAll('_', ' ');
    }
  }
}

// Step 4: Curriculum, Grades, Subjects, Lessons Selection
class CurriculumSelectionStep extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onComplete;

  const CurriculumSelectionStep({
    Key? key,
    required this.userData,
    required this.onComplete,
  }) : super(key: key);

  @override
  _CurriculumSelectionStepState createState() =>
      _CurriculumSelectionStepState();
}

class _CurriculumSelectionStepState extends State<CurriculumSelectionStep>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Data lists
  List<Map<String, dynamic>> _curricula = [];
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _lessons = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _languages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurricula();
    _loadLanguages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if the user is a student, show appropriate curriculum selection
    if (widget.userData['user_type'] == UserType.STUDENT) {
      return _buildStudentCurriculumSelection();
    }

    // Default curriculum selection for other user types
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Curriculum'),
            Tab(text: 'Grades'),
            Tab(text: 'Subjects'),
            Tab(text: 'Lessons'),
          ],
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCurriculumTab(),
                      _buildGradesTab(),
                      _buildSubjectsTab(),
                      _buildLessonsTab(),
                    ],
                  ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: widget.onComplete,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Complete Registration'),
          ),
        ),
      ],
    );
  }

  // Special curriculum selection flow for students
  Widget _buildStudentCurriculumSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Student Learning Preferences',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Curriculum selection
          _isLoading || _curricula.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Map<String, dynamic>>(
                key: const ValueKey('curriculum-dropdown'),
                decoration: const InputDecoration(
                  labelText: 'Select Curriculum',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
                value: widget.userData['selected_curriculum'],
                items:
                    _curricula.map((curriculum) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: curriculum,
                        child: Text(curriculum['title'] ?? ''),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  try {
                    setState(() {
                      widget.userData['selected_curriculum'] = newValue;
                      widget.userData['curriculum'] =
                          newValue != null ? [newValue] : [];
                      widget.userData['selected_grade'] = null;
                      widget.userData['grades'] = [];
                      widget.userData['selected_semester'] = null;
                      _loadGrades();
                    });
                  } catch (e) {
                    debugPrint('Error changing curriculum: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error selecting curriculum: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                },
                hint: const Text('Select your curriculum'),
              ),

          const SizedBox(height: 16),

          // Grade selection
          _isLoading || _grades.isEmpty
              ? widget.userData['selected_curriculum'] == null
                  ? const SizedBox() // Don't show anything if curriculum not selected
                  : const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Map<String, dynamic>>(
                key: const ValueKey('grade-dropdown'),
                decoration: const InputDecoration(
                  labelText: 'Select Grade',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grade),
                ),
                value: widget.userData['selected_grade'],
                items:
                    _grades.map((grade) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: grade,
                        child: Text(grade['title'] ?? ''),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  try {
                    setState(() {
                      widget.userData['selected_grade'] = newValue;
                      widget.userData['grades'] =
                          newValue != null ? [newValue] : [];
                      _loadSemesters();
                    });
                  } catch (e) {
                    debugPrint('Error changing grade: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error selecting grade: ${e.toString()}'),
                      ),
                    );
                  }
                },
                hint: const Text('Select your grade'),
              ),

          const SizedBox(height: 16),

          // Semester selection
          _isLoading || _semesters.isEmpty
              ? widget.userData['selected_grade'] == null
                  ? const SizedBox() // Don't show anything if grade not selected
                  : const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Map<String, dynamic>>(
                key: const ValueKey('semester-dropdown'),
                decoration: const InputDecoration(
                  labelText: 'Select Semester',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                value: widget.userData['selected_semester'],
                items:
                    _semesters.map((semester) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: semester,
                        child: Text(semester['title'] ?? ''),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  try {
                    setState(() {
                      widget.userData['selected_semester'] = newValue;
                      _loadSubjects();
                    });
                  } catch (e) {
                    debugPrint('Error changing semester: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error selecting semester: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                },
                hint: const Text('Select your semester'),
              ),

          const SizedBox(height: 16),

          // Language selection
          _isLoading || _languages.isEmpty
              ? const SizedBox()
              : DropdownButtonFormField<Map<String, dynamic>>(
                key: const ValueKey('language-dropdown'),
                decoration: const InputDecoration(
                  labelText: 'Select Language',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
                value: widget.userData['selected_language'],
                items:
                    _languages.map((language) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: language,
                        child: Text(language['title'] ?? ''),
                      );
                    }).toList(),
                onChanged: (newValue) {
                  try {
                    setState(() {
                      widget.userData['selected_language'] = newValue;
                      widget.userData['language_id'] = newValue?['id'];
                    });
                  } catch (e) {
                    debugPrint('Error changing language: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Error selecting language: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                },
                hint: const Text('Select your preferred language'),
              ),

          const Spacer(),

          ElevatedButton(
            onPressed: () {
              // Validate required fields
              if (widget.userData['selected_curriculum'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a curriculum')),
                );
                return;
              }

              if (widget.userData['selected_grade'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a grade')),
                );
                return;
              }

              if (widget.userData['selected_semester'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a semester')),
                );
                return;
              }

              if (widget.userData['selected_language'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a language')),
                );
                return;
              }

              // Complete registration
              widget.onComplete();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Complete Registration'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumTab() {
    return _curricula.isEmpty
        ? _buildEmptyList('No curricula available')
        : _buildSelectionList(
          title: 'Select Curriculum',
          items: _curricula,
          selectedItems: widget.userData['curriculum'],
          allowMultiple: true,
          onSelectionChanged: (selected) {
            setState(() {
              widget.userData['curriculum'] = selected;
              _loadGrades();
            });
          },
        );
  }

  Widget _buildGradesTab() {
    return _grades.isEmpty
        ? _buildEmptyList('Select a curriculum first')
        : _buildSelectionList(
          title: 'Select Grades',
          items: _grades,
          selectedItems: widget.userData['grades'],
          allowMultiple: true,
          onSelectionChanged: (selected) {
            setState(() {
              widget.userData['grades'] = selected;
              _loadSubjects();
            });
          },
        );
  }

  Widget _buildSubjectsTab() {
    return _subjects.isEmpty
        ? _buildEmptyList('Select a grade first')
        : _buildSelectionList(
          title: 'Select Subjects',
          items: _subjects,
          selectedItems: widget.userData['subjects'],
          allowMultiple: true,
          onSelectionChanged: (selected) {
            setState(() {
              widget.userData['subjects'] = selected;
              _loadLessons();
            });
          },
        );
  }

  Widget _buildLessonsTab() {
    return _lessons.isEmpty
        ? _buildEmptyList('Select a subject first')
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search lessons',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Implement lesson search
                },
              ),
            ),
            Expanded(
              child: _buildSelectionList(
                title: 'Available Lessons',
                items: _lessons,
                selectedItems: widget.userData['lessons'],
                allowMultiple: true,
                onSelectionChanged: (selected) {
                  setState(() {
                    widget.userData['lessons'] = selected;
                  });
                },
              ),
            ),
          ],
        );
  }

  Widget _buildEmptyList(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSelectionList({
    required String title,
    required List<Map<String, dynamic>> items,
    required List<dynamic> selectedItems,
    required Function(List<Map<String, dynamic>>) onSelectionChanged,
    bool allowMultiple = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selectedItems.any(
                (selected) => selected['id'] == item['id'],
              );

              return ListTile(
                title: Text(item['title']), // Changed from 'name' to 'title'
                subtitle:
                    item['description'] != null
                        ? Text(item['description'])
                        : null,
                leading:
                    isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.circle_outlined),
                onTap: () {
                  List<Map<String, dynamic>> updatedSelection = [];

                  if (allowMultiple) {
                    // For multiple selection
                    updatedSelection = List<Map<String, dynamic>>.from(
                      selectedItems,
                    );
                    if (isSelected) {
                      updatedSelection.removeWhere(
                        (selected) => selected['id'] == item['id'],
                      );
                    } else {
                      updatedSelection.add(item);
                    }
                  } else {
                    // For single selection
                    updatedSelection = [item];
                  }

                  onSelectionChanged(updatedSelection);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Data loading methods
  void _loadCurricula() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await supabase.from('curricula').select().order('title');
      setState(() {
        _curricula = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading curricula: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadGrades() async {
    if (widget.userData['curriculum'].isEmpty) {
      setState(() {
        _grades = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Changed from ordering by 'sequence' to 'title' since 'sequence' column doesn't exist
      final data = await supabase.from('grades').select().order('title');

      setState(() {
        _grades = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading grades: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadSubjects() async {
    if (widget.userData['grades'].isEmpty) {
      setState(() {
        _subjects = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Remove the grade_id filter since that column doesn't exist in the subjects table
      final data = await supabase.from('subjects').select().order('title');

      setState(() {
        _subjects = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading subjects: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadLessons() async {
    if (widget.userData['subjects'].isEmpty) {
      setState(() {
        _lessons = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final subjectIds = widget.userData['subjects']
          .map((s) => s['id'])
          .join(',');

      final data = await supabase
          .from('lessons')
          .select()
          .contains('subject_id', [subjectIds])
          .order('sequence');

      setState(() {
        _lessons = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading lessons: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadSemesters() async {
    if (widget.userData['selected_grade'] == null) {
      setState(() {
        _semesters = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Remove the grade_id filter since that column doesn't exist in the semesters table
      final data = await supabase.from('semesters').select().order('title');

      setState(() {
        _semesters = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading semesters: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadLanguages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await supabase.from('languages').select().order('title');
      setState(() {
        _languages = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error loading languages: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
