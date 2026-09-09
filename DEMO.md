# Travel Super App demo

This Flutter prototype presents the first demo slice of the four-domain Travel Super App blueprint.

## What is ready

- **User application:** discovery, flight results, places, trip timeline, travel tools, and profile.
- **Partner portal:** bookings, revenue, payouts, inventory, promotions, and reviews.
- **Staff backoffice:** support queue, payment verification, partner approvals, and operational reports.
- **Administration:** executive KPIs, user operations, campaigns, partner controls, and service health.

Use the floating **Demo** button from any user-app screen to switch domains. Dashboard quick actions give visible feedback to make presentation flows clear.

## MVC demo structure

`lib/features/demo/models/portal_models.dart` contains immutable portal data.

`lib/features/demo/controllers/demo_controller.dart` owns demo actions and separates future API wiring from the view.

`lib/features/demo/views/portal_dashboard.dart` renders reusable portal dashboards.

The existing user-app pages remain in `lib/main.dart`; their SQLite bootstrap stays in `lib/database/local_database.dart` for the offline demo data.

## Run

```powershell
flutter pub get
flutter run -d chrome
```

For a mobile presentation, use a connected emulator or device in place of `chrome`.

## Next production increments

1. Move each user feature out of `main.dart` into model/controller/view folders.
2. Replace local fixtures with the Go REST API specified in the blueprint.
3. Add authentication, RBAC, booking, and payment flows before connecting external providers.
