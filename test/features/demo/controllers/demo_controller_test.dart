import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_flutter_app/features/demo/controllers/demo_controller.dart';

void main() {
  group('DemoController role-scoped work items', () {
    late DemoController controller;

    setUp(() {
      controller = DemoController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('each portal receives only its own workflow queue', () {
      final List<PortalWorkItem> partnerItems = controller.workItems(DemoPortal.partner);
      final List<PortalWorkItem> staffItems = controller.workItems(DemoPortal.staff);
      final List<PortalWorkItem> adminItems = controller.workItems(DemoPortal.admin);

      expect(partnerItems.map((item) => item.id), contains('booking-29401'));
      expect(staffItems.map((item) => item.id), contains('payment-29401'));
      expect(adminItems.map((item) => item.id), contains('dispute-29401'));
      expect(partnerItems.map((item) => item.id), isNot(contains('payment-29401')));
      expect(staffItems.map((item) => item.id), isNot(contains('dispute-29401')));
      expect(adminItems.map((item) => item.id), isNot(contains('booking-29401')));
    });

    test('work item transitions once and notifies listeners', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.advanceWorkItem(DemoPortal.partner, 'booking-29401'), isTrue);
      final PortalWorkItem item = controller
          .workItems(DemoPortal.partner)
          .singleWhere((workItem) => workItem.id == 'booking-29401');
      expect(item.status, 'ยืนยันแล้ว');
      expect(item.isCompleted, isTrue);
      expect(notifications, 1);

      expect(controller.advanceWorkItem(DemoPortal.partner, 'booking-29401'), isFalse);
      expect(notifications, 1);
    });

    test('a role cannot mutate an item from another role', () {
      expect(controller.advanceWorkItem(DemoPortal.partner, 'payment-29401'), isFalse);
      expect(
        controller
            .workItems(DemoPortal.staff)
            .singleWhere((item) => item.id == 'payment-29401')
            .isCompleted,
        isFalse,
      );
    });
  });
}
