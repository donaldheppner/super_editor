import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  group('SuperEditor > plugins > lifecycle', () {
    testWidgetsOnAllPlatforms('are detached when the editor is disposed', (tester) async {
      final plugin = _FakePlugin();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withPlugin(plugin)
          .pump();

      // Ensure the plugin was not attached initially.
      expect(plugin.detachCallCount, 0);

      // Pump another widget tree to dispose SuperEditor.
      await tester.pumpWidget(Container());

      // Ensure the plugin was detached.
      expect(plugin.detachCallCount, 1);
    });

    group('appended style phases >', () {
      testWidgetsOnAllPlatforms('are re-read when the plugin set changes but the stylesheet does not', (tester) async {
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [
              ParagraphNode(id: "1", text: AttributedText()),
            ],
          ),
          composer: MutableDocumentComposer(),
        );

        final plugin1 = _StylePhasePlugin();
        final plugin2 = _StylePhasePlugin();

        // Both pumps hand `SuperEditor` the SAME `Stylesheet` instance, so the stylesheet
        // identity check in `didUpdateWidget` can't be what rebuilds the layout presenter.
        // A plugin's `appendedStylePhases` are baked into the presenter's pipeline when the
        // presenter is created, so swapping the plugin has to rebuild the presenter on its
        // own account (MemNote NOTE-162).
        Widget buildEditorWith(SuperEditorPlugin plugin) => MaterialApp(
              home: Scaffold(
                body: SuperEditor(
                  editor: editor,
                  stylesheet: defaultStylesheet,
                  plugins: {plugin},
                ),
              ),
            );

        await tester.pumpWidget(buildEditorWith(plugin1));

        // The first plugin's phase is in the pipeline, so it ran.
        expect(plugin1.phase.styleCallCount, greaterThan(0));
        expect(plugin2.phase.styleCallCount, 0);
        final plugin1CallCountBeforeSwap = plugin1.phase.styleCallCount;

        // Replace the plugin instance without touching anything else. This is the same
        // `SuperEditor` element, so it takes the `didUpdateWidget` path.
        await tester.pumpWidget(buildEditorWith(plugin2));
        await tester.pump();

        // The replacement plugin's phase reached the pipeline...
        expect(plugin2.phase.styleCallCount, greaterThan(0));
        // ...and the removed plugin's phase is no longer in it.
        expect(plugin1.phase.styleCallCount, plugin1CallCountBeforeSwap);
      });
    });

    group('rebuild >', () {
      testWidgetsOnAllPlatforms('different SuperEditor, same Editor, same plugin instance', (tester) async {
        final pump1Key = GlobalKey(debugLabel: 'pump-1');
        final pump2Key = GlobalKey(debugLabel: 'pump-2');
        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [
              ParagraphNode(id: "1", text: AttributedText()),
            ],
          ),
          composer: MutableDocumentComposer(),
        );
        final plugin = _FakePlugin();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: pump1Key,
              body: SuperEditor(
                editor: editor,
                plugins: {plugin},
              ),
            ),
          ),
        );

        // Grab the instance of the context resource that was added by
        // the plugin. We want to make sure the instance doesn't disappear
        // or get replaced.
        expect(plugin.attachCallCount, 1);
        expect(plugin.detachCallCount, 0);
        final resource1 = editor.context.findMaybe(_FakePluginResource.key);
        expect(resource1, isNotNull);

        // Pump another widget tree to replace the existing Super Editor tree
        // with another Super Editor tree (simulating something like a navigator
        // replacing an entire subtree, including SuperEditor, but wanting to
        // continue using the same backing editor and document).
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: pump2Key,
              body: SuperEditor(
                editor: editor,
                plugins: {plugin},
              ),
            ),
          ),
        );

        // Since we retained the same `Editor` and the same plugin instance, across two
        // different `SuperEditor` widgets, we expect that the plugin remained attached
        // to the `Editor` the whole time, and the resource instance remained the same, too.
        expect(plugin.attachCallCount, 1);
        expect(plugin.detachCallCount, 0);
        final resource2 = editor.context.findMaybe(_FakePluginResource.key);
        expect(resource2, isNotNull);
        expect(resource1, resource2);
      });

      testWidgetsOnAllPlatforms('different SuperEditor, same Editor, different plugin instance', (tester) async {
        final pump1Key = GlobalKey(debugLabel: 'pump-1');
        final plugin1 = _FakePlugin();

        final pump2Key = GlobalKey(debugLabel: 'pump-2');
        final plugin2 = _FakePlugin();

        final editor = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [
              ParagraphNode(id: "1", text: AttributedText()),
            ],
          ),
          composer: MutableDocumentComposer(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: pump1Key,
              body: SuperEditor(
                editor: editor,
                plugins: {plugin1},
              ),
            ),
          ),
        );

        // Grab the instance of the context resource that was added by
        // the plugin. We expect that this resource instance will change
        // because the plugin will be replaced with a second plugin.
        expect(plugin1.attachCallCount, 1);
        expect(plugin1.detachCallCount, 0);
        final resource1 = editor.context.findMaybe(_FakePluginResource.key);
        expect(resource1, isNotNull);

        // Pump another widget tree to replace the existing Super Editor tree
        // with another Super Editor tree (simulating something like a navigator
        // replacing an entire subtree, including SuperEditor, but wanting to
        // continue using the same backing editor and document).
        //
        // Also replace one plugin with another instance of that plugin.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: pump2Key,
              body: SuperEditor(
                editor: editor,
                plugins: {plugin2},
              ),
            ),
          ),
        );

        // Grab the context resource again and ensure the first plugin's resource
        // was replaced by the second plugin's resource.
        expect(plugin1.attachCallCount, 1);
        expect(plugin1.detachCallCount, 1);

        expect(plugin2.attachCallCount, 1);
        expect(plugin2.detachCallCount, 0);

        final resource2 = editor.context.findMaybe(_FakePluginResource.key);
        expect(resource2, isNotNull);
        expect(resource1, isNot(resource2));
      });

      testWidgetsOnAllPlatforms('same SuperEditor, different Editor, same plugin instance', (tester) async {
        final superEditorKey = GlobalKey(debugLabel: 'SuperEditor');
        final plugin = _FakePlugin();

        final editor1 = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [
              ParagraphNode(id: "1", text: AttributedText()),
            ],
          ),
          composer: MutableDocumentComposer(),
        );

        final editor2 = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [
              ParagraphNode(id: "1", text: AttributedText()),
            ],
          ),
          composer: MutableDocumentComposer(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: superEditorKey,
              body: SuperEditor(
                editor: editor1,
                plugins: {plugin},
              ),
            ),
          ),
        );

        // Ensure the plugin attached itself. Grab the resource because we expect
        // it to the stay the same.
        expect(plugin.attachCallCount, 1);
        expect(plugin.detachCallCount, 0);

        final resource1 = editor1.context.findMaybe(_FakePluginResource.key);
        expect(resource1, plugin.fakeResource);

        // Re-pump with a different Editor, but the same SuperEditor and plugin.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: superEditorKey,
              body: SuperEditor(
                editor: editor2,
                plugins: {plugin},
              ),
            ),
          ),
        );

        // Ensure the plugin detached and re-attached when the `SuperEditor` rebuilt
        // with a new `Editor`. Ensure the same plugin resource is in the context.
        expect(plugin.attachCallCount, 2);
        expect(plugin.detachCallCount, 1);

        final resource2 = editor2.context.findMaybe(_FakePluginResource.key);
        expect(resource2, plugin.fakeResource);
      });

      testWidgetsOnAllPlatforms('different SuperEditor, different Editor, same plugin instance', (tester) async {
        final plugin = _FakePlugin();

        final pump1Key = GlobalKey(debugLabel: 'pump-1');
        final editor1 = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [
              ParagraphNode(id: "1", text: AttributedText()),
            ],
          ),
          composer: MutableDocumentComposer(),
        );

        final pump2Key = GlobalKey(debugLabel: 'pump-2');
        final editor2 = createDefaultDocumentEditor(
          document: MutableDocument(
            nodes: [
              ParagraphNode(id: "1", text: AttributedText()),
            ],
          ),
          composer: MutableDocumentComposer(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: pump1Key,
              body: SuperEditor(
                editor: editor1,
                plugins: {plugin},
              ),
            ),
          ),
        );

        // Ensure the plugin attached itself. We expect the plugin resource to remain the same.
        expect(plugin.attachCallCount, 1);
        expect(plugin.detachCallCount, 0);
        final resource1 = editor1.context.findMaybe(_FakePluginResource.key);
        expect(resource1, plugin.fakeResource);

        // Re-pump with a different Editor, but the same plugin.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              key: pump2Key,
              body: SuperEditor(
                editor: editor2,
                plugins: {plugin},
              ),
            ),
          ),
        );

        // Ensure the plugin detached and re-attached, and the same resource is registered
        // with the new editor context.
        expect(plugin.attachCallCount, 2);
        expect(plugin.detachCallCount, 1);

        final resource2 = editor2.context.findMaybe(_FakePluginResource.key);
        expect(resource2, plugin.fakeResource);
      });
    });
  });
}

/// A plugin that tracks whether it was detached.
class _FakePlugin extends SuperEditorPlugin {
  int get attachCallCount => _attachCallCount;
  int _attachCallCount = 0;

  int get detachCallCount => _detachCallCount;
  int _detachCallCount = 0;

  final fakeResource = _FakePluginResource();

  @override
  void attach(Editor editor) {
    editor.context.put(_FakePluginResource.key, fakeResource);

    _attachCallCount += 1;
  }

  @override
  void detach(Editor editor) {
    editor.context.remove(_FakePluginResource.key, fakeResource);

    _detachCallCount += 1;
  }
}

class _FakePluginResource extends Editable {
  static const key = "fake-resource";
}

/// A plugin that contributes a style phase to `SuperEditor`'s layout presenter pipeline,
/// and counts how many times that phase actually runs.
class _StylePhasePlugin extends SuperEditorPlugin {
  final phase = _CountingStylePhase();

  @override
  List<SingleColumnLayoutStylePhase> get appendedStylePhases => [phase];
}

class _CountingStylePhase extends SingleColumnLayoutStylePhase {
  int styleCallCount = 0;

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    styleCallCount += 1;
    return viewModel;
  }
}
