import 'package:event_volunteer/services/api_service.dart';
import 'package:event_volunteer/services/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('on-device backend serves the full volunteer workflow', () async {
    expect(ApiService.useLocalBackend, isTrue);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final headEmail = 'head$stamp@test.edu';
    final volEmail = 'vol$stamp@test.edu';

    expect((await ApiService.checkHealth())['database'], 'on-device');

    await ApiService.registerUser(
      name: 'Head One',
      email: headEmail,
      studentId: 'H1',
      password: 'secret1',
      role: 'Head Volunteer',
    );
    await ApiService.registerUser(
      name: 'Vol One',
      email: volEmail,
      studentId: 'V1',
      password: 'secret2',
      role: 'Volunteer',
    );
    await expectLater(
      ApiService.registerUser(
        name: 'Dup',
        email: headEmail,
        studentId: 'x',
        password: 'secret1',
        role: 'Volunteer',
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
    await expectLater(
      ApiService.loginUser(email: volEmail, password: 'wrong'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );

    // Head Volunteer creates a published event with a task.
    final head = await ApiService.loginUser(
      email: headEmail,
      password: 'secret1',
    );
    Session.setUser(head);
    expect(Session.isHeadVolunteer, isTrue);
    final event = await ApiService.createEvent(
      name: 'Test Fest',
      date: '2030-03-01',
      location: 'Main Hall',
      volunteersNeeded: 5,
      status: 'published',
      startTime: '09:00',
      endTime: '17:00',
    );
    final eventId = event['eventId'] as int;
    final task = await ApiService.createTask(
      eventId: eventId,
      taskName: 'Desk',
      description: 'Check-in desk',
      date: '2030-03-01',
      startTime: '09:00:00',
      endTime: '12:00:00',
      location: 'Gate',
      volunteersRequired: 1,
    );
    final taskId = task['taskId'] as int;

    // Volunteer registers, enrolls (capacity 1), second enroll is refused.
    final vol = await ApiService.loginUser(email: volEmail, password: 'secret2');
    Session.setUser(vol);
    final events = await ApiService.getEvents();
    expect(events.any((e) => e['id'] == eventId), isTrue);
    await ApiService.registerForEvent(
      eventId: eventId,
      selectedLocation: 'Main Hall',
    );
    final enrollment = await ApiService.enroll(taskId);
    expect(enrollment['status'], 'pending');
    await expectLater(
      ApiService.enroll(taskId),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
    final mine = await ApiService.getUserTasks(Session.userId);
    expect(mine.single['status'], 'pending');
    await expectLater(
      ApiService.createEvent(name: 'x', date: '2030-03-01', location: 'y'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );

    // Head approves, volunteer is notified, announcement + help request flow.
    Session.setUser(head);
    final requests = await ApiService.getEnrollments(status: 'pending');
    final id = requests.firstWhere((r) => r['task_id'] == taskId)['enrollment_id'];
    await ApiService.updateEnrollmentStatus(id as int, 'approved');
    await ApiService.createAnnouncement(
      eventId: eventId,
      title: 'Hello',
      message: 'Briefing at 8',
    );

    Session.setUser(vol);
    expect((await ApiService.getUserTasks(Session.userId)).single['status'], 'approved');
    expect((await ApiService.getNotifications()).length, greaterThanOrEqualTo(2));
    expect(
      (await ApiService.getEventAnnouncements(eventId)).single['title'],
      'Hello',
    );
    await ApiService.submitHelpRequest(
      userId: Session.userId,
      eventId: eventId,
      message: 'Where is the gate?',
    );

    Session.setUser(head);
    final help = await ApiService.getHelpRequests(status: 'open');
    expect(help.any((h) => h['message'] == 'Where is the gate?'), isTrue);
    Session.clear();
  });
}
