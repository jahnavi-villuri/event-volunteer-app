import 'package:event_volunteer/services/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session & Role Authorization Tests', () {
    setUp(() {
      Session.clear();
    });

    tearDown(() {
      Session.clear();
    });

    test('standard volunteer session has expected permissions', () {
      Session.setUser({
        'id': 1,
        'name': 'Regular Volunteer',
        'email': 'vol@example.com',
        'role': 'Volunteer',
        'role_requested': 'Volunteer',
        'role_status': 'active',
        'access_token': 'dummy_jwt_123',
      });

      expect(Session.isLoggedIn, isTrue);
      expect(Session.userId, 1);
      expect(Session.name, 'Regular Volunteer');
      expect(Session.email, 'vol@example.com');
      expect(Session.role, 'Volunteer');
      expect(Session.roleRequested, 'Volunteer');
      expect(Session.roleStatus, 'active');
      expect(Session.isHeadVolunteer, isFalse);
      expect(Session.isHeadVolunteerPending, isFalse);
      expect(Session.canApproveRoleRequests, isFalse);
      expect(Session.canPostTasks, isFalse);
      expect(Session.canManageVolunteers, isFalse);
    });

    test('pending head role metadata grants no privileged actions', () {
      Session.setUser({
        'id': 2,
        'name': 'Applicant Head',
        'email': 'head.app@example.com',
        'role': 'Volunteer',
        'role_requested': 'Head Volunteer',
        'role_status': 'pending',
        'access_token': 'dummy_jwt_456',
      });

      // Crucial security invariant: client is NOT granted Head Volunteer permissions while pending
      expect(Session.isLoggedIn, isTrue);
      expect(Session.role, 'Volunteer');
      expect(Session.roleRequested, 'Head Volunteer');
      expect(Session.roleStatus, 'pending');
      expect(Session.isHeadVolunteer, isFalse);
      expect(Session.isHeadVolunteerPending, isTrue);
      expect(Session.canApproveRoleRequests, isFalse);
      expect(Session.canPostTasks, isFalse);
      expect(Session.canManageVolunteers, isFalse);
    });

    test('approved head volunteer has management permissions', () {
      Session.setUser({
        'id': 3,
        'name': 'Approved Head',
        'email': 'head.approved@example.com',
        'role': 'Head Volunteer',
        'role_requested': 'Head Volunteer',
        'role_status': 'approved',
        'access_token': 'dummy_jwt_789',
      });

      expect(Session.isLoggedIn, isTrue);
      expect(Session.role, 'Head Volunteer');
      expect(Session.isHeadVolunteer, isTrue);
      expect(Session.isHeadVolunteerPending, isFalse);
      expect(Session.canApproveRoleRequests, isFalse);
      expect(Session.canPostTasks, isTrue);
      expect(Session.canManageVolunteers, isTrue);
    });

    test('only administrators can approve head role requests', () {
      Session.setUser({
        'id': 4,
        'name': 'Administrator',
        'role': 'Administrator',
        'access_token': 'admin_token',
      });

      expect(Session.canApproveRoleRequests, isTrue);
    });

    test('updateUser and clear work as expected', () {
      Session.setUser({'id': 4, 'name': 'Updatable User', 'role': 'Volunteer'});

      expect(Session.role, 'Volunteer');

      Session.updateUser({'role': 'Head Volunteer', 'role_status': 'approved'});

      expect(Session.role, 'Head Volunteer');
      expect(Session.isHeadVolunteer, isTrue);

      Session.clear();
      expect(Session.currentUser, isNull);
      expect(Session.isLoggedIn, isFalse);
      expect(Session.userId, 0);
    });
  });
}
