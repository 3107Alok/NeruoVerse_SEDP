import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/features/auth/auth_screen.dart';

void main() {
  testWidgets('Password visibility toggle on Login page works independently and defaults to hidden', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    // Find the password field on Login page
    final passwordFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Password',
    );
    expect(passwordFieldFinder, findsOneWidget);

    TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
    // Initially hidden
    expect(passwordField.obscureText, isTrue);

    // Initial icon is visibility_off
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsNothing);

    // Tap toggle icon
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    // Now password should be visible
    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsNothing);

    // Tap toggle icon again
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();

    // Now password should be obscured again
    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsNothing);
  });

  testWidgets('Password and Confirm Password toggles on Sign Up page operate independently', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    // Switch to Sign Up
    final switchButton = find.text("Don't have an account? Sign Up");
    expect(switchButton, findsOneWidget);
    await tester.tap(switchButton);
    await tester.pumpAndSettle();

    final passwordFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Password',
    );
    final confirmPasswordFieldFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Confirm Password',
    );

    expect(passwordFieldFinder, findsOneWidget);
    expect(confirmPasswordFieldFinder, findsOneWidget);

    TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
    TextField confirmPasswordField = tester.widget<TextField>(confirmPasswordFieldFinder);

    // Both hidden by default
    expect(passwordField.obscureText, isTrue);
    expect(confirmPasswordField.obscureText, isTrue);

    // Both have visibility_off icons
    expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility), findsNothing);

    // Tap the password visibility toggle (the first IconButton inside password field)
    final passwordToggle = find.descendant(
      of: passwordFieldFinder,
      matching: find.byType(IconButton),
    );
    await tester.tap(passwordToggle);
    await tester.pumpAndSettle();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    confirmPasswordField = tester.widget<TextField>(confirmPasswordFieldFinder);

    // Password is now visible, but Confirm Password is still obscured (independent state!)
    expect(passwordField.obscureText, isFalse);
    expect(confirmPasswordField.obscureText, isTrue);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    // Now tap the confirm password visibility toggle
    final confirmPasswordToggle = find.descendant(
      of: confirmPasswordFieldFinder,
      matching: find.byType(IconButton),
    );
    await tester.tap(confirmPasswordToggle);
    await tester.pumpAndSettle();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    confirmPasswordField = tester.widget<TextField>(confirmPasswordFieldFinder);

    // Both are now visible
    expect(passwordField.obscureText, isFalse);
    expect(confirmPasswordField.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_off), findsNothing);

    // Tap password toggle again to hide password
    await tester.tap(passwordToggle);
    await tester.pumpAndSettle();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    confirmPasswordField = tester.widget<TextField>(confirmPasswordFieldFinder);

    // Password is now hidden, Confirm Password remains visible
    expect(passwordField.obscureText, isTrue);
    expect(confirmPasswordField.obscureText, isFalse);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
  });
}
