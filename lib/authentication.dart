import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// Get the Supabase client instance
final supabase = Supabase.instance.client;

// Simple class to handle authentication
class AuthenticationService {
  // Track the auth state subscription
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isHandlingSignOut = false;

  // Create a singleton instance to prevent multiple instances
  static final AuthenticationService _instance =
      AuthenticationService._internal();
  factory AuthenticationService() {
    return _instance;
  }
  AuthenticationService._internal();

  // A static variable to track if auth state change is already being listened to
  static bool _isListening = false;

  // Login with email and password
  Future<AuthResponse?> login(String email, String password) async {
    try {
      debugPrint('Attempting to login with email: $email');

      // Simple login with password
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // If login successful, store auth data in SharedPreferences
      if (response.session != null) {
        debugPrint('Login successful for user: ${response.user?.id}');
        await _storeAuthData(
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken ?? '',
          userId: response.user!.id,
          email: email,
        );
      } else {
        debugPrint(
          'Login response contained null session: ${response.toString()}',
        );
      }

      return response;
    } catch (e) {
      debugPrint('Login error: $e');
      debugPrint('Login error stacktrace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<AuthResponse?> signup(String email, String password) async {
    try {
      debugPrint('Attempting to signup with email: $email');

      // Sign up with basic parameters
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      // If sign up successful, store auth data
      if (response.session != null) {
        debugPrint('Signup successful for user: ${response.user?.id}');
        await _storeAuthData(
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken ?? '',
          userId: response.user!.id,
          email: email,
        );
      } else {
        debugPrint(
          'Signup response contained null session: ${response.toString()}',
        );
      }

      return response;
    } catch (e) {
      debugPrint('Signup error: $e');
      debugPrint('Signup error stacktrace: ${StackTrace.current}');
      rethrow;
    }
  }

  // Handle forgotten password
  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutterquickstart://reset-callback/',
      );
      debugPrint('Password reset email sent to $email');
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  // Store authentication data in SharedPreferences
  Future<void> _storeAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setString('user_id', userId);
      await prefs.setString('email', email);
      await prefs.setBool('is_authenticated', true);

      debugPrint('Auth data stored in SharedPreferences');
    } catch (e) {
      debugPrint('Error storing auth data: $e');
    }
  }

  // Recover session from SharedPreferences if possible
  Future<bool> recoverSession() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('No refresh token found in storage');
      return false;
    }
    try {
      final response = await supabase.auth.recoverSession(refreshToken);
      if (response.session != null) {
        debugPrint('Session recovered successfully');
        await _storeAuthData(
          accessToken: response.session!.accessToken,
          refreshToken: response.session!.refreshToken ?? '',
          userId: response.user!.id,
          email: response.user!.email ?? '',
        );
        return true;
      }
      debugPrint('Session recovery failed: session is null');
      return false;
    } catch (e) {
      debugPrint('User recovery error: $e');
      return false;
    }
  }

  // Check if user is authenticated, try to recover if not
  Future<bool> isAuthenticated() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      debugPrint('User is authenticated with active session');
      return true;
    }
    // Try to recover session
    return await recoverSession();
  }

  // Get current user profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final authenticated = await isAuthenticated();
    if (!authenticated) {
      throw Exception('No active session found. Please log in again.');
    }

    try {
      // Get current user
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No current user found');
        return null;
      }

      // Fetch user profile from database
      final data =
          await supabase
              .from('user_profiles')
              .select('*, languages:language_id(*), schools:school_id(*)')
              .eq('id', user.id)
              .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  // Check if user exists by email
  Future<bool> checkUserExists(String email) async {
    try {
      final users =
          await supabase
              .from('users')
              .select('id')
              .eq('email', email)
              .maybeSingle();

      return users != null;
    } catch (e) {
      debugPrint('Error checking if user exists: $e');
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      _isHandlingSignOut = true;
      // Clear stored auth data first
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_id');
      await prefs.remove('email');
      await prefs.remove('is_authenticated');

      // Then sign out from Supabase
      await supabase.auth.signOut();

      debugPrint('User logged out and auth data cleared');
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      _isHandlingSignOut = false;
    }
  }

  // Cancel existing auth subscription
  void cancelAuthSubscription() {
    if (_authStateSubscription != null) {
      debugPrint('Cancelling previous auth subscription');
      _authStateSubscription?.cancel();
      _authStateSubscription = null;
    }
  }

  // Setup auth state listener
  void setupAuthStateChange(BuildContext context) {
    // Guard against multiple listeners
    if (_isListening) {
      debugPrint('Auth state change listener already active, skipping setup');
      return;
    }

    // Cancel any existing subscription first
    cancelAuthSubscription();

    // Mark that we're now listening
    _isListening = true;

    // Create a new subscription
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;
      final session = data.session;

      debugPrint('Auth state changed: $event');

      if (event == AuthChangeEvent.signedIn) {
        if (session != null) {
          await _storeAuthData(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
            userId: session.user.id,
            email: session.user.email ?? '',
          );

          // Check if user has completed registration
          try {
            final userProfile = await getCurrentUserProfile();

            if (userProfile != null) {
              // User has completed registration, go to home
              Navigator.of(context).pushReplacementNamed('/home');
            } else {
              // User needs to complete registration
              Navigator.of(context).pushReplacementNamed('/registration');
            }
          } catch (e) {
            // If we can't determine profile status, default to registration
            debugPrint('Error checking profile: $e');
            Navigator.of(context).pushReplacementNamed('/registration');
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // Prevent multiple navigations and processing during sign out
        if (!_isHandlingSignOut) {
          _isHandlingSignOut = true;

          // For debugging
          debugPrint('Processing signout event, will navigate to auth screen');

          // Use a microtask to avoid navigation during build
          Future.microtask(() {
            // Check if the context is still valid and app is mounted
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/auth');
            }
            _isHandlingSignOut = false;
          });
        } else {
          // Skip redundant signout events
          debugPrint('Skipping redundant signout event processing');
        }
      }
    });
  }

  // Dispose method to clean up resources
  void dispose() {
    cancelAuthSubscription();
    _isListening = false;
  }
}

// Authentication Screen
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthenticationService _authService = AuthenticationService();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _showForgotPassword = false;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _authService.setupAuthStateChange(context);
  }

  @override
  void dispose() {
    _authService.cancelAuthSubscription();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _showForgotPassword = false;
      _clearErrors();
    });
  }

  void _toggleForgotPassword() {
    setState(() {
      _showForgotPassword = !_showForgotPassword;
      _clearErrors();
    });
  }

  void _clearErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

  bool _validateInputs() {
    bool isValid = true;

    // Validate email
    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      isValid = false;
    } else if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(_emailController.text)) {
      setState(() {
        _emailError = 'Please enter a valid email address';
      });
      isValid = false;
    } else {
      setState(() {
        _emailError = null;
      });
    }

    // Only validate password if not in forgot password mode
    if (!_showForgotPassword) {
      if (_passwordController.text.isEmpty) {
        setState(() {
          _passwordError = 'Password is required';
        });
        isValid = false;
      } else if (!_isLogin && _passwordController.text.length < 8) {
        // Only check password strength for signup
        setState(() {
          _passwordError = 'Password must be at least 8 characters';
        });
        isValid = false;
      } else {
        setState(() {
          _passwordError = null;
        });
      }
    }

    return isValid;
  }

  Future<void> _authenticate() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        // Sign in
        debugPrint('Attempting login with: ${_emailController.text}');
        final res = await _authService.login(
          _emailController.text,
          _passwordController.text,
        );

        if (res != null && res.user != null) {
          debugPrint('Login successful, user ID: ${res.user!.id}');

          // Successfully logged in, navigate directly to home
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed - invalid credentials')),
          );
        }
      } else {
        // Sign up
        final res = await _authService.signup(
          _emailController.text,
          _passwordController.text,
        );

        if (res != null && res.user != null) {
          // Navigate to registration
          Navigator.pushReplacementNamed(context, '/registration');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Signup failed')));
        }
      }
    } catch (e) {
      // Handle specific errors
      String errorMessage = 'Authentication failed';

      if (e is AuthException) {
        errorMessage = e.message;
      }

      debugPrint('Auth error during ${_isLogin ? "login" : "signup"}: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Logo placeholder
              Container(
                height: 120,
                alignment: Alignment.center,
                child: const FlutterLogo(size: 100),
              ),
              const SizedBox(height: 40),
              // Title
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email),
                  errorText: _emailError,
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => _clearErrors(),
              ),
              const SizedBox(height: 16),
              // Password field
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  errorText: _passwordError,
                ),
                obscureText: true,
                onChanged: (_) => _clearErrors(),
              ),
              const SizedBox(height: 24),
              // Main action button
              ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(_isLogin ? 'Login' : 'Sign Up'),
              ),
              const SizedBox(height: 16),
              // Toggle button
              TextButton(
                onPressed: _toggleAuthMode,
                child: Text(
                  _isLogin
                      ? 'Don\'t have an account? Sign Up'
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
