import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/session.dart';
import 'screens/announcements_page.dart';
import 'screens/contact_head_volunteer_screen.dart';
import 'screens/head_dashboard.dart';
import 'screens/volunteer_requests_screen.dart';
import 'utils/formats.dart';
import 'theme/app_theme.dart';
import 'widgets/event_artwork.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      appBar: AppBar(title: const Text('Volunteer Connect'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Volunteer Connect',
                    style: AppTextStyles.pageHeading,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Know what to do, where to go and when to work.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'What is Volunteer Connect?',
              style: AppTextStyles.sectionHeading,
            ),

            const SizedBox(height: 10),

            const Text(
              'Volunteer Connect helps students participate in events '
              'without confusion or miscommunication. Head volunteers '
              'can provide clear information about what work needs to be '
              'done, where it needs to be done, when it needs to be done '
              'and how volunteers should complete it.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),

            const SizedBox(height: 25),

            const Text('Features', style: AppTextStyles.sectionHeading),

            const SizedBox(height: 15),

            const FeatureCard(
              icon: Icons.event,
              title: 'Discover Events',
              description:
                  'Find upcoming college events where volunteers are needed.',
            ),

            const FeatureCard(
              icon: Icons.task_alt,
              title: 'Choose Volunteer Work',
              description:
                  'Select specific tasks instead of attending unnecessary meetings.',
            ),

            const FeatureCard(
              icon: Icons.location_on,
              title: 'Know Where to Go',
              description:
                  'See the exact location where your task needs to be performed.',
            ),

            const FeatureCard(
              icon: Icons.access_time,
              title: 'Know When to Work',
              description: 'View your assigned date, start time and end time.',
            ),

            const FeatureCard(
              icon: Icons.menu_book,
              title: 'Clear Instructions',
              description:
                  'Get step-by-step instructions from the head volunteer.',
            ),

            const FeatureCard(
              icon: Icons.support_agent,
              title: 'Contact Head Volunteer',
              description:
                  'Ask questions or get help whenever you have doubts.',
            ),

            const FeatureCard(
              icon: Icons.notifications,
              title: 'Get Important Updates',
              description:
                  'Receive event announcements and changes in task details.',
            ),

            const FeatureCard(
              icon: Icons.check_circle,
              title: 'Track Your Tasks',
              description:
                  'Keep track of assigned and completed volunteer work.',
            ),

            const FeatureCard(
              icon: Icons.schedule,
              title: 'Part-Time Volunteering',
              description:
                  'Enroll only for the tasks and time slots that suit you.',
            ),

            const SizedBox(height: 25),

            const Text('How It Works', style: AppTextStyles.sectionHeading),

            const SizedBox(height: 15),

            const StepCard(
              number: '1',
              title: 'Find an Event',
              description: 'Browse available college events.',
            ),

            const StepCard(
              number: '2',
              title: 'Choose a Task',
              description: 'Select the work you want to volunteer for.',
            ),

            const StepCard(
              number: '3',
              title: 'Enroll',
              description: 'Register for your selected task.',
            ),

            const StepCard(
              number: '4',
              title: 'Get Instructions',
              description: 'See where, when and how you need to work.',
            ),

            const StepCard(
              number: '5',
              title: 'Volunteer',
              description:
                  'Complete your assigned work and update your status.',
            ),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Text(
                    'Ready to Volunteer?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create an account and start participating in events.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo,
                      ),
                      child: const Text('REGISTER NOW'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'I ALREADY HAVE AN ACCOUNT',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
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
// LOGIN SCREEN - CONNECTED TO SQLITE
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
// SIGNUP SCREEN - CONNECTED TO NODE.JS + MYSQL
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

  String selectedRole = 'Volunteer';

  bool showPassword = false;
  bool isLoading = false;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    // Check email
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    // Check password
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must contain at least 6 characters'),
        ),
      );
      return;
    }

    // ----------------------------------------------------------
    // START LOADING
    // ----------------------------------------------------------

    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // SEND DATA TO NODE.JS API
      // --------------------------------------------------------

      final result = await ApiService.registerUser(
        name: name,
        email: email,
        studentId: studentId,
        password: password,
        role: selectedRole,
      ).timeout(const Duration(seconds: 10));

      // Make sure screen still exists
      if (!mounted) return;

      // Stop the loading state BEFORE navigating.
      setState(() {
        isLoading = false;
      });

      // Show success message.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Account created successfully!'),
        ),
      );

      // Open Login screen after successful registration.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      // --------------------------------------------------------
      // ERROR
      // --------------------------------------------------------

      if (!mounted) return;

      String errorMessage = e.toString().replaceFirst('Exception: ', '');

      // If request takes longer than 10 seconds
      if (e is TimeoutException) {
        errorMessage =
            'Server is not responding. Please make sure Node.js server is running.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      // --------------------------------------------------------
      // ALWAYS ENABLE BUTTON AGAIN
      // --------------------------------------------------------

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
          children: [
            // --------------------------------------------------
            // TOP SPACE
            // --------------------------------------------------
            const SizedBox(height: 50),

            // --------------------------------------------------
            // ICON
            // --------------------------------------------------
            const Icon(Icons.person_add_alt_1, size: 70, color: Colors.indigo),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // TITLE
            // --------------------------------------------------
            const Text('Create Your Account', style: AppTextStyles.pageHeading),

            const SizedBox(height: 35),

            // --------------------------------------------------
            // FULL NAME
            // --------------------------------------------------
            TextField(
              controller: nameController,

              decoration: const InputDecoration(
                labelText: 'Full Name',

                prefixIcon: Icon(Icons.person_outline),

                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // EMAIL
            // --------------------------------------------------
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

            // --------------------------------------------------
            // STUDENT ID
            // --------------------------------------------------
            TextField(
              controller: studentIdController,

              decoration: const InputDecoration(
                labelText: 'Student ID',

                prefixIcon: Icon(Icons.badge_outlined),

                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // PASSWORD
            // --------------------------------------------------
            TextField(
              controller: passwordController,

              obscureText: !showPassword,

              decoration: InputDecoration(
                labelText: 'Password',

                prefixIcon: const Icon(Icons.lock_outline),

                border: const OutlineInputBorder(),

                // SHOW / HIDE PASSWORD
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

            const SizedBox(height: 16),

            // --------------------------------------------------
            // ROLE
            // --------------------------------------------------
            DropdownButtonFormField<String>(
              initialValue: selectedRole,

              decoration: const InputDecoration(
                labelText: 'Role',

                prefixIcon: Icon(Icons.groups_outlined),

                border: OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(value: 'Volunteer', child: Text('Volunteer')),

                DropdownMenuItem(
                  value: 'Head Volunteer',
                  child: Text('Head Volunteer'),
                ),
              ],

              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    selectedRole = value;
                  });
                }
              },
            ),

            const SizedBox(height: 30),

            // --------------------------------------------------
            // CREATE ACCOUNT BUTTON
            // --------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : signup,
                child: isLoading
                    ? const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'CREATE ACCOUNT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
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

  @override
  void initState() {
    super.initState();
    loadUpcomingEvents();
  }

  Future<void> loadUpcomingEvents() async {
    try {
      final data = await ApiService.getEvents();

      if (!mounted) return;

      setState(() {
        events = data.take(3).toList();
        isLoadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoadingEvents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['name'] ?? 'Volunteer';

    return SafeArea(
      child: SingleChildScrollView(
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

            const Text('Upcoming Events', style: AppTextStyles.sectionHeading),

            const SizedBox(height: 15),

            if (isLoadingEvents)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
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
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: Colors.indigo, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
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

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  // ============================================================
  // LOAD EVENTS FROM BACKEND
  // ============================================================

  Future<void> loadEvents() async {
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
      margin: const EdgeInsets.only(bottom: 15),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventArtwork(eventName: eventName, imageUrl: imageUrl),
            const SizedBox(height: 16),
            Text(eventName, style: AppTextStyles.itemHeading),
            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
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
                if (volunteersNeeded != null && volunteersNeeded! > 0)
                  _EventInfoChip(
                    icon: Icons.groups_2_outlined,
                    label: '$volunteersNeeded volunteers needed',
                  ),
              ],
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
                child: const Text('VIEW EVENT'),
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
              fontWeight: FontWeight.w600,
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
    setState(() => isLoading = true);

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
    } catch (_) {
      // Enrollment status is optional; ignore failures here.
    }
  }

  // ============================================================
  // LOAD ANNOUNCEMENTS FOR EVENT
  // ============================================================

  Future<void> loadAnnouncements() async {
    setState(() => loadingAnnouncements = true);

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

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getUserTasks(Session.userId);

      if (!mounted) return;

      setState(() {
        tasks = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

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
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

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

            const SizedBox(height: 5),

            Text(
              eventName,
              style: const TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.w600,
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

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

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
                child: const Text('VIEW TASK'),
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

// ============================================================
// PROFILE PAGE
// ============================================================

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? 'Volunteer';
    final email = user['email'] ?? '';
    final studentId = user['student_id'] ?? '';
    final role = user['role'] ?? 'Volunteer';

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
                  const ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Volunteer History'),
                    subtitle: Text('View completed volunteer work'),
                    trailing: Icon(Icons.arrow_forward_ios),
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
