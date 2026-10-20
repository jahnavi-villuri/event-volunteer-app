import 'dart:async';
import 'package:flutter/material.dart';
import 'services/app_preferences.dart';
import 'services/api_service.dart';
import 'services/local_database_service.dart';
import 'services/session.dart';
import 'screens/announcements_page.dart';
import 'screens/contact_head_volunteer_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/head_dashboard.dart';
import 'screens/volunteer_requests_screen.dart';
import 'utils/formats.dart';
import 'theme/app_theme.dart';
import 'widgets/event_artwork.dart';
import 'widgets/load_error_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.load();
  await LocalDatabaseService.instance.initialize();

  runApp(const VolunteerApp());
}

class VolunteerApp extends StatelessWidget {
  const VolunteerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Volunteer Connect',
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// SPLASH SCREEN
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.volunteer_activism,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Volunteer Connect', style: AppTextStyles.pageHeading),
            const SizedBox(height: 8),
            const Text(
              'Volunteer smarter. Work together.',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WELCOME / FEATURES
// ============================================================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              Color(0xFFEEF5FF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.volunteer_activism,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Volunteer Connect',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Event operations platform',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Volunteer smarter.',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Coordinate events, manage volunteers, and deliver a polished attendee experience from one platform.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _StatPill(label: 'Browse', value: 'events'),
                          const SizedBox(width: 10),
                          _StatPill(label: 'Join', value: 'tasks'),
                        ],
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text('I already have an account'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'What you can do',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const FeatureCard(
                  icon: Icons.event_available_rounded,
                  title: 'Discover events',
                  description:
                      'Browse upcoming opportunities with clear dates and volunteer roles.',
                ),
                const FeatureCard(
                  icon: Icons.groups_2_outlined,
                  title: 'Review applications',
                  description:
                      'Approve or decline volunteer requests with a structured workflow.',
                ),
                const FeatureCard(
                  icon: Icons.campaign_rounded,
                  title: 'Send updates',
                  description:
                      'Keep everyone informed with announcements and event reminders.',
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FEATURE CARD
// ============================================================

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.indigo.shade50,
              child: Icon(icon, color: Colors.indigo),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STEP CARD
// ============================================================

class StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const StepCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }
}

// ============================================================
// LOGIN SCREEN - CONNECTED TO THE BACKEND
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool showPassword = false;
  bool isLoading = false;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = await ApiService.loginUser(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      Session.setUser(user);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VolunteerHomeScreen(user: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      String errorMessage = e.toString().replaceFirst('Exception: ', '');

      if (e is TimeoutException) {
        errorMessage =
            'Server is not responding. Please make sure Node.js server is running.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(Icons.lock_outline, size: 70, color: Colors.indigo),

            const SizedBox(height: 20),

            const Text('Welcome Back', style: AppTextStyles.pageHeading),

            const SizedBox(height: 30),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  icon: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : login,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('LOGIN'),
              ),
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignupScreen()),
                );
              },
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SIGNUP SCREEN - CONNECTED TO THE BACKEND
// ============================================================

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ------------------------------------------------------------
  // TEXT CONTROLLERS
  // ------------------------------------------------------------

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ------------------------------------------------------------
  // VARIABLES
  // ------------------------------------------------------------

  bool showPassword = false;
  bool isLoading = false;
  String? selectedRole;

  // ------------------------------------------------------------
  // SIGNUP FUNCTION
  // ------------------------------------------------------------

  Future<void> signup() async {
    // Get values from text fields
    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String studentId = studentIdController.text.trim();
    final String password = passwordController.text;

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (name.isEmpty ||
        email.isEmpty ||
        studentId.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least 6 characters'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (selectedRole == null || selectedRole!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role (Volunteer or Head Volunteer) before registering.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiService.registerUser(
        name: name,
        email: email,
        studentId: studentId,
        password: password,
        role: selectedRole!,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      final message = result['message'] ?? 'Account created successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // DISPOSE CONTROLLERS
  // ------------------------------------------------------------

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    studentIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required List<String> bulletPoints,
    required IconData icon,
    String? badgeText,
  }) {
    final isSelected = selectedRole == role;

    return Semantics(
      selected: isSelected,
      label: '$title account role. ${isSelected ? "Currently selected" : "Not selected"}',
      button: true,
      child: InkWell(
        onTap: () {
          setState(() {
            selectedRole = role;
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.lavender,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (badgeText != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              ...bulletPoints.map(
                (point) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Create Your Account', style: AppTextStyles.pageHeading),
                  const SizedBox(height: 6),
                  const Text(
                    'Join the community and start making an impact.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // FULL NAME
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 16),

            // EMAIL
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 16),

            // STUDENT ID
            TextField(
              controller: studentIdController,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),

            const SizedBox(height: 16),

            // PASSWORD
            TextField(
              controller: passwordController,
              obscureText: !showPassword,
              decoration: InputDecoration(
                labelText: 'Password (min. 6 characters)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                  icon: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SELECT ROLE SECTION
            Row(
              children: [
                const Text(
                  'Select Account Role',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose your role carefully. Neither role is selected by default.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            // VOLUNTEER CARD
            _buildRoleCard(
              role: 'Volunteer',
              title: 'Volunteer',
              subtitle: 'Join and participate in events',
              icon: Icons.volunteer_activism_outlined,
              bulletPoints: const [
                'Join events and register for volunteer opportunities.',
                'Track participation and volunteer hours.',
                'View personal activities and event announcements.',
              ],
            ),

            const SizedBox(height: 12),

            // HEAD VOLUNTEER CARD
            _buildRoleCard(
              role: 'Head Volunteer',
              title: 'Head Volunteer',
              subtitle: 'Coordinate volunteers & events',
              icon: Icons.supervisor_account_outlined,
              badgeText: 'Approval Required',
              bulletPoints: const [
                'Coordinate volunteer activities and view volunteer lists.',
                'Create and manage events, tasks, and announcements.',
                'Assist with attendance and respond to student help requests.',
                'Requires organizer/administrator approval before activation.',
              ],
            ),

            const SizedBox(height: 28),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : signup,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class VolunteerHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const VolunteerHomeScreen({super.key, required this.user});

  @override
  State<VolunteerHomeScreen> createState() => _VolunteerHomeScreenState();
}

class _VolunteerHomeScreenState extends State<VolunteerHomeScreen> {
  int selectedIndex = 0;

  bool get isHeadVolunteer => Session.isHeadVolunteer;

  @override
  Widget build(BuildContext context) {
    final pages = isHeadVolunteer
        ? <Widget>[
            HeadDashboardPage(user: widget.user),
            const EventsPage(),
            const VolunteerRequestsPage(),
            const AnnouncementsPage(),
            ProfilePage(user: widget.user),
          ]
        : <Widget>[
            HomePage(user: widget.user),
            const EventsPage(),
            const MyTasksPage(),
            const AnnouncementsPage(),
            ProfilePage(user: widget.user),
          ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.025),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(selectedIndex),
          child: pages[selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: isHeadVolunteer
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Events',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Recruiter',
                ),
                NavigationDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(Icons.campaign),
                  label: 'Announce',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Events',
                ),
                NavigationDestination(
                  icon: Icon(Icons.task_outlined),
                  selectedIcon: Icon(Icons.task),
                  label: 'My Tasks',
                ),
                NavigationDestination(
                  icon: Icon(Icons.campaign_outlined),
                  selectedIcon: Icon(Icons.campaign),
                  label: 'Announce',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }
}

// ============================================================
// VOLUNTEER REQUESTS PAGE (HEAD VOLUNTEER TAB)
// ============================================================

class VolunteerRequestsPage extends StatelessWidget {
  const VolunteerRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const VolunteerRequestsScreen();
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> events = [];
  bool isLoadingEvents = true;
  String? eventsError;

  @override
  void initState() {
    super.initState();
    loadUpcomingEvents();
  }

  Future<void> loadUpcomingEvents() async {
    setState(() {
      isLoadingEvents = true;
      eventsError = null;
    });
    try {
      final data = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        events = data.take(3).toList();
        isLoadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingEvents = false;
        eventsError = 'Could not load upcoming events. $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? 'Volunteer';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadUpcomingEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $name 👋', style: AppTextStyles.pageHeading),

              const SizedBox(height: 6),

              const Text(
                'Ready to make a difference?',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),

              if (Session.isHeadVolunteerPending) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Head Volunteer Request Pending',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Your request for Head Volunteer access is waiting for administrator approval. You can currently participate as a Volunteer.',
                              style: TextStyle(
                                color: Color(0xFF78350F),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 25),

              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.event,
                      title: 'View Events',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EventsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.task_alt,
                      title: 'My Tasks',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyTasksPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.campaign,
                      title: 'Announcements',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnnouncementsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.support_agent,
                      title: 'Contact Head Volunteer',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ContactHeadVolunteerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                'Upcoming Events',
                style: AppTextStyles.sectionHeading,
              ),

              const SizedBox(height: 15),

              if (isLoadingEvents)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (eventsError != null)
                LoadErrorState(
                  message: eventsError!,
                  onRetry: loadUpcomingEvents,
                )
              else if (events.isEmpty)
                const Text(
                  'No upcoming events.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...events.map((event) {
                  return EventCard(
                    eventId: (event['id'] as num).toInt(),
                    eventName: event['name'] ?? 'Unnamed Event',
                    date: _formatDate(event['date']),
                    location: event['location'] ?? '',
                    description: event['description'] ?? '',
                    imageUrl: event['image_url']?.toString(),
                    volunteersNeeded: (event['volunteers_needed'] as num?)
                        ?.toInt(),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString().split(' ').first;
    final parts = text.split('-');
    if (parts.length != 3) return raw.toString();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null ||
        month == null ||
        day == null ||
        month < 1 ||
        month > 12) {
      return raw.toString();
    }
    return '${months[month - 1]} $day, $year';
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EVENTS PAGE
// ============================================================

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  // ============================================================
  // LOAD EVENTS FROM BACKEND
  // ============================================================

  Future<void> loadEvents() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    try {
      final data = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        events = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Could not load events. $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
    }
  }

  // ============================================================
  // BUILD PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Events', style: AppTextStyles.pageHeading),

              const SizedBox(height: 8),

              const Text(
                'Find events and choose volunteer work.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // LOADING
              // ==================================================
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              // ==================================================
              // NO EVENTS
              // ==================================================
              else if (loadError != null)
                LoadErrorState(message: loadError!, onRetry: loadEvents)
              else if (events.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No events available.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              // ==================================================
              // DISPLAY EVENTS
              // ==================================================
              else
                ...events.map((event) {
                  return EventCard(
                    eventId: (event['id'] as num).toInt(),
                    eventName: event['name'] ?? 'Unnamed Event',
                    date: formatDate(event['date']),
                    location: event['location'] ?? '',
                    description: event['description'] ?? '',
                    imageUrl: event['image_url']?.toString(),
                    volunteersNeeded: (event['volunteers_needed'] as num?)
                        ?.toInt(),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EVENT CARD
// ============================================================

class EventCard extends StatelessWidget {
  final int eventId;
  final String eventName;
  final String date;
  final String location;
  final String description;
  final String? imageUrl;
  final int? volunteersNeeded;

  const EventCard({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.date,
    required this.location,
    this.description = '',
    this.imageUrl,
    this.volunteersNeeded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventArtwork(eventName: eventName, imageUrl: imageUrl),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(eventName, style: AppTextStyles.itemHeading),
                ),
                if (volunteersNeeded != null && volunteersNeeded! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$volunteersNeeded spots',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EventInfoChip(icon: Icons.calendar_today, label: date),
                _EventInfoChip(icon: Icons.location_on, label: location),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(
                        eventId: eventId,
                        eventName: eventName,
                        date: date,
                        location: location,
                        description: description,
                        imageUrl: imageUrl,
                        volunteersNeeded: volunteersNeeded,
                      ),
                    ),
                  );
                },
                child: const Text('View event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EVENT DETAILS
// ============================================================

class EventDetailsScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  final String date;
  final String location;
  final String description;
  final String? imageUrl;
  final int? volunteersNeeded;

  const EventDetailsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.date,
    required this.location,
    this.description = '',
    this.imageUrl,
    this.volunteersNeeded,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  List<dynamic> tasks = [];
  List<dynamic> announcements = [];
  Map<int, String> enrolledStatuses = {};
  String? tasksError;
  String? announcementsError;
  bool isLoading = true;
  bool loadingAnnouncements = true;
  int enrollingTaskId = 0;

  @override
  void initState() {
    super.initState();
    loadTasks();
    loadAnnouncements();
  }

  // ============================================================
  // LOAD TASKS FROM BACKEND
  // ============================================================

  Future<void> loadTasks() async {
    setState(() {
      isLoading = true;
      tasksError = null;
    });

    try {
      final data = await ApiService.getTasks(widget.eventId);

      if (!mounted) return;

      setState(() {
        tasks = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        tasksError = 'Could not load event tasks. $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    }

    if (!Session.isLoggedIn || Session.isHeadVolunteer) return;

    try {
      final myTasks = await ApiService.getUserTasks(Session.userId);

      if (!mounted) return;

      final map = <int, String>{};
      for (final task in myTasks) {
        final taskId = (task['task_id'] as num).toInt();
        map[taskId] = (task['status'] ?? 'pending').toString();
      }

      setState(() => enrolledStatuses = map);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not check your enrollment status: $error'),
        ),
      );
    }
  }

  // ============================================================
  // LOAD ANNOUNCEMENTS FOR EVENT
  // ============================================================

  Future<void> loadAnnouncements() async {
    setState(() {
      loadingAnnouncements = true;
      announcementsError = null;
    });

    try {
      final data = await ApiService.getEventAnnouncements(widget.eventId);

      if (!mounted) return;

      setState(() {
        announcements = data;
        loadingAnnouncements = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingAnnouncements = false;
        announcementsError = 'Could not load event announcements. $e';
      });
    }
  }

  // ============================================================
  // ENROLL IN TASK
  // ============================================================

  Future<void> enroll(int taskId) async {
    setState(() => enrollingTaskId = taskId);

    try {
      final result = await ApiService.enroll(
        Session.userId,
        taskId,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        enrolledStatuses[taskId] = result['status'] ?? 'pending';
        enrollingTaskId = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enrollment submitted successfully. Waiting for approval.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => enrollingTaskId = 0);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final showEnroll = Session.isLoggedIn && !Session.isHeadVolunteer;

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),

      body: RefreshIndicator(
        onRefresh: () async {
          await loadTasks();
          await loadAnnouncements();
        },

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              EventArtwork(
                eventName: widget.eventName,
                imageUrl: widget.imageUrl,
                height: 210,
              ),
              const SizedBox(height: 18),
              // ==================================================
              // EVENT NAME
              // ==================================================
              Text(widget.eventName, style: AppTextStyles.pageHeading),

              const SizedBox(height: 20),

              // ==================================================
              // DATE
              // ==================================================
              InfoRow(
                icon: Icons.calendar_today,
                title: 'Date',
                value: widget.date,
              ),

              // ==================================================
              // LOCATION
              // ==================================================
              InfoRow(
                icon: Icons.location_on,
                title: 'Location',
                value: widget.location,
              ),
              if (widget.volunteersNeeded != null &&
                  widget.volunteersNeeded! > 0)
                InfoRow(
                  icon: Icons.groups_2_outlined,
                  title: 'Volunteers needed',
                  value: '${widget.volunteersNeeded}',
                ),
              if (widget.description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  widget.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ==================================================
              // AVAILABLE TASKS
              // ==================================================
              const Text(
                'Available Tasks',
                style: AppTextStyles.sectionHeading,
              ),

              const SizedBox(height: 15),

              // ==================================================
              // LOADING
              // ==================================================
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              // ==================================================
              // NO TASKS
              // ==================================================
              else if (tasksError != null)
                LoadErrorState(message: tasksError!, onRetry: loadTasks)
              else if (tasks.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'No tasks available for this event.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              // ==================================================
              // DISPLAY TASKS
              // ==================================================
              else
                ...tasks.asMap().entries.map((entry) {
                  final task = entry.value;
                  final taskId = (task['id'] as num).toInt();
                  final enrollmentStatus = enrolledStatuses[taskId];

                  return TweenAnimationBuilder<double>(
                    key: ValueKey(taskId),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 350 + entry.key * 70),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: VolunteerTaskCard(
                      taskId: taskId,
                      taskName: task['task_name'] ?? 'Unnamed Task',
                      time:
                          '${formatTime(task['start_time'])} - '
                          '${formatTime(task['end_time'])}',
                      date: formatDate(task['date']),
                      location: task['location'] ?? '',
                      instructions: task['instructions'] ?? '',
                      showEnrollButton: showEnroll,
                      isEnrolling: enrollingTaskId == taskId,
                      enrollmentStatus: enrollmentStatus,
                      onEnroll: () => enroll(taskId),
                    ),
                  );
                }),

              const SizedBox(height: 10),

              // ==================================================
              // ANNOUNCEMENTS
              // ==================================================
              const Text('Announcements', style: AppTextStyles.sectionHeading),

              const SizedBox(height: 15),

              if (loadingAnnouncements)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (announcementsError != null)
                LoadErrorState(
                  message: announcementsError!,
                  onRetry: loadAnnouncements,
                )
              else if (announcements.isEmpty)
                const Text(
                  'No announcements for this event yet.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...announcements.asMap().entries.map((entry) {
                  final a = entry.value;
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(a['id'] ?? entry.key),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 350 + entry.key * 70),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - value)),
                        child: child,
                      ),
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['title'] ?? 'Announcement',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              a['message'] ?? '',
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatDateTime(a['created_at']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================================================
// VOLUNTEER TASK CARD
// ============================================================

class VolunteerTaskCard extends StatelessWidget {
  final int taskId;
  final String taskName;
  final String time;
  final String date;
  final String location;
  final String instructions;
  final bool showEnrollButton;
  final bool isEnrolling;
  final String? enrollmentStatus;
  final VoidCallback? onEnroll;

  const VolunteerTaskCard({
    super.key,
    required this.taskId,
    required this.taskName,
    required this.time,
    required this.date,
    required this.location,
    required this.instructions,
    this.showEnrollButton = true,
    this.isEnrolling = false,
    this.enrollmentStatus,
    this.onEnroll,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel => enrollmentStatus?.toUpperCase() ?? 'PENDING';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              taskName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            InfoRow(icon: Icons.calendar_today, title: 'Date', value: date),

            InfoRow(icon: Icons.access_time, title: 'Time', value: time),

            InfoRow(icon: Icons.location_on, title: 'Where', value: location),

            InfoRow(icon: Icons.menu_book, title: 'How', value: instructions),

            const SizedBox(height: 12),

            if (enrollmentStatus != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(
                    enrollmentStatus!,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor(enrollmentStatus!),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ] else if (showEnrollButton) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isEnrolling ? null : onEnroll,
                  child: isEnrolling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ENROLL'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MY TASKS
// ============================================================

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  List<dynamic> tasks = [];
  bool isLoading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final data = await ApiService.getUserTasks(Session.userId);

      if (!mounted) return;

      setState(() {
        tasks = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'Could not load your tasks. $e';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadTasks,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Tasks',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 36,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your shifts, status and event details in one place.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              if (!isLoading) ...[
                _TaskSummary(tasks: tasks),
                const SizedBox(height: 20),
              ],

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (loadError != null)
                LoadErrorState(message: loadError!, onRetry: loadTasks)
              else if (tasks.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'You have not enrolled in any tasks yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
              else
                ...tasks.map((task) {
                  return TaskCard(
                    taskName: task['task_name'] ?? 'Task',
                    eventName: task['event_name'] ?? 'Event',
                    date: formatDate(task['date']),
                    time:
                        '${formatTime(task['start_time'])} - '
                        '${formatTime(task['end_time'])}',
                    location: task['location'] ?? '',
                    instructions: task['instructions'] ?? '',
                    status: task['status'] ?? 'pending',
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskSummary extends StatelessWidget {
  final List<dynamic> tasks;

  const _TaskSummary({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final approved = tasks
        .where((task) => task['status']?.toString() == 'approved')
        .length;
    final pending = tasks
        .where(
          (task) =>
              task['status']?.toString() != 'approved' &&
              task['status']?.toString() != 'rejected',
        )
        .length;
    final rejected = tasks
        .where((task) => task['status']?.toString() == 'rejected')
        .length;
    final total = tasks.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9D9D4), Color(0xFFF5EAE3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Volunteer activity',
            style: TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TaskCount(
                label: 'Total',
                count: total,
                color: AppColors.primary,
              ),
              _TaskCount(
                label: 'Accepted',
                count: approved,
                color: AppColors.success,
              ),
              _TaskCount(
                label: 'Pending',
                count: pending,
                color: AppColors.accent,
              ),
              _TaskCount(
                label: 'Declined',
                count: rejected,
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 9,
              child: total == 0
                  ? const ColoredBox(color: Color(0xFFE4E6EF))
                  : Row(
                      children: [
                        if (approved > 0)
                          Expanded(
                            flex: approved,
                            child: const ColoredBox(color: AppColors.success),
                          ),
                        if (pending > 0)
                          Expanded(
                            flex: pending,
                            child: const ColoredBox(color: AppColors.accent),
                          ),
                        if (rejected > 0)
                          Expanded(
                            flex: rejected,
                            child: const ColoredBox(color: AppColors.danger),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enrollment status',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCount extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TaskCount({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TASK CARD
// ============================================================

class TaskCard extends StatelessWidget {
  final String taskName;
  final String eventName;
  final String date;
  final String time;
  final String location;
  final String instructions;
  final String status;

  const TaskCard({
    super.key,
    required this.taskName,
    required this.eventName,
    required this.date,
    required this.time,
    required this.location,
    this.instructions = '',
    required this.status,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    taskName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              eventName,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 15),
            InfoRow(icon: Icons.calendar_today, title: 'Date', value: date),
            InfoRow(icon: Icons.access_time, title: 'Time', value: time),
            InfoRow(icon: Icons.location_on, title: 'Where', value: location),
            if (instructions.isNotEmpty) ...[
              InfoRow(
                icon: Icons.menu_book,
                title: 'Instructions',
                value: instructions,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsScreen(
                        taskName: taskName,
                        eventName: eventName,
                        date: date,
                        time: time,
                        location: location,
                        instructions: instructions,
                        status: status,
                      ),
                    ),
                  );
                },
                child: const Text('View task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TASK DETAILS
// ============================================================

class TaskDetailsScreen extends StatelessWidget {
  final String taskName;
  final String eventName;
  final String date;
  final String time;
  final String location;
  final String instructions;
  final String status;

  const TaskDetailsScreen({
    super.key,
    required this.taskName,
    required this.eventName,
    required this.date,
    required this.time,
    required this.location,
    this.instructions = '',
    this.status = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(taskName, style: AppTextStyles.pageHeading),

            const SizedBox(height: 8),

            Text(
              eventName,
              style: const TextStyle(
                color: Colors.indigo,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 25),

            InfoRow(icon: Icons.calendar_today, title: 'WHEN', value: date),

            InfoRow(icon: Icons.access_time, title: 'TIME', value: time),

            InfoRow(icon: Icons.location_on, title: 'WHERE', value: location),

            if (status.isNotEmpty) ...[
              InfoRow(
                icon: Icons.verified,
                title: 'STATUS',
                value: status.toUpperCase(),
              ),
            ],

            InfoRow(
              icon: Icons.menu_book,
              title: 'HOW',
              value: instructions.isEmpty
                  ? 'Follow the instructions given by the head volunteer. '
                        'If you have any questions, contact your head volunteer.'
                  : instructions,
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContactHeadVolunteerScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.support_agent),
                label: const Text('CONTACT HEAD VOLUNTEER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// INFO ROW
// ============================================================

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigo, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '$title\n',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  TextSpan(text: value, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isCheckingHealth = false;
  String? healthStatus;

  Future<void> _checkServerHealth() async {
    setState(() {
      isCheckingHealth = true;
      healthStatus = null;
    });

    try {
      final res = await ApiService.checkHealth();
      if (!mounted) return;
      setState(() {
        healthStatus =
            'Connected: Server OK (Database: ${res['database'] ?? 'sqlite'})';
        isCheckingHealth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        healthStatus =
            'Connection failed: ${e.toString().replaceFirst('Exception: ', '')}';
        isCheckingHealth = false;
      });
    }
  }

  void _logout() {
    Session.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Info')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Account Details', style: AppTextStyles.sectionHeading),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.person),
                      ),
                      title: Text(
                        Session.name.isNotEmpty ? Session.name : 'Active User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(Session.email),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Session.isHeadVolunteer
                              ? const Color(0xFFFEF3C7)
                              : AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Session.isHeadVolunteer
                                ? const Color(0xFFF59E0B)
                                : AppColors.accent,
                          ),
                        ),
                        child: Text(
                          Session.role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Session.isHeadVolunteer
                                ? const Color(0xFF92400E)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    if (Session.isHeadVolunteerPending) ...[
                      const Divider(),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(
                            Icons.hourglass_top,
                            color: Color(0xFFD97706),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Head Volunteer status is pending approval',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Database & Server', style: AppTextStyles.sectionHeading),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.dns_outlined, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'Backend API Base URL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ApiService.baseUrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.storage_outlined, color: AppColors.success),
                        SizedBox(width: 10),
                        Text(
                          'Local Persistent SQLite',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'volunteer_app_local.db • Active for offline caching and storage',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isCheckingHealth ? null : _checkServerHealth,
                        icon: isCheckingHealth
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: Text(
                          isCheckingHealth
                              ? 'Checking...'
                              : 'Test Server Connection',
                        ),
                      ),
                    ),
                    if (healthStatus != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: healthStatus!.contains('Connected')
                              ? AppColors.accentSoft
                              : const Color(0xFFFFECEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          healthStatus!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: healthStatus!.contains('Connected')
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('App Information', style: AppTextStyles.sectionHeading),
            const SizedBox(height: 12),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.palette_outlined),
                    title: Text('Appearance'),
                    subtitle: Text('Light Theme Only (Curated Design)'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text('Build Status'),
                    subtitle: Text('Version 1.0.0+1 (GitHub Ready)'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('SIGN OUT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE PAGE
// ============================================================

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Map<String, dynamic> profile;

  @override
  void initState() {
    super.initState();
    profile = Map<String, dynamic>.from(widget.user);
  }

  Future<void> editProfile() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userId: Session.userId,
          name: profile['name']?.toString() ?? '',
          studentId: profile['student_id']?.toString() ?? '',
        ),
      ),
    );
    if (!mounted || updated == null) return;
    profile = {...profile, ...updated};
    Session.updateUser(updated);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] ?? 'Volunteer';
    final email = profile['email'] ?? '';
    final studentId = profile['student_id'] ?? '';
    final role = profile['role'] ?? 'Volunteer';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 55)),

            const SizedBox(height: 15),

            Text(name, style: AppTextStyles.pageHeading),

            const SizedBox(height: 5),

            Text(role, style: const TextStyle(color: Colors.grey)),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: editProfile,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('EDIT PROFILE'),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(email),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Student ID'),
                    subtitle: Text(studentId),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    subtitle: const Text('Theme, display, and preferences'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('My Tasks'),
                    subtitle: const Text('View your volunteer sign-ups'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyTasksPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Session.clear();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('LOGOUT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
