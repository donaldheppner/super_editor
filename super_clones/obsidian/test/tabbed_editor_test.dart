import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor_obsidian/tabbed_editor.dart';
import 'package:tab_kit/tab_kit.dart';

/// Smoke test for the Obsidian clone's editor pane.
///
/// This file used to be the unedited `flutter create` counter test, which asserted on a
/// `find.text('0')` and an `Icons.add` that this app has never had (MemNote NOTE-165). It
/// pumps [TabbedEditor] rather than the app's `MyApp`, because `MyApp` mounts `Sidebar`,
/// whose `initState` lists a vault directory hard-coded to one developer's home directory
/// (`/Users/matt/Projects/...`) and throws in any other environment.
void main() {
  testWidgets('renders a tab per open document', (WidgetTester tester) async {
    final tabController = NotebookTabController()
      ..addTab(const TabDescriptor(id: "1", title: "This is a document"))
      ..addTab(const TabDescriptor(id: "2", title: "Another document"));
    addTearDown(tabController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabbedEditor(tabController: tabController),
        ),
      ),
    );

    expect(find.text("This is a document"), findsOneWidget);
    expect(find.text("Another document"), findsOneWidget);
  });
}
