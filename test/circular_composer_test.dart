import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asb_house_hub/models/school_notice.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/widgets/school_circular_composer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    AuthService.isFirebaseLiveOverride = false;
    AuthService.firestoreFailureSimulated = null;
    auth = AuthService();
  });

  tearDown(() {
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
  });

  Uint8List pdfBytes([String body = '%PDF-1.4 test circular']) =>
      Uint8List.fromList(utf8.encode(body));

  group('School circular publishing semantics', () {
    test('local mode publishes with a PDF but reports localOnly, not broadcast',
        () async {
      final bytes = pdfBytes();

      final result = await auth.publishSchoolNotice(
        title: 'Mid-Term Examination Guidelines',
        content: 'Examinations begin on Sunday. Bring your hall ticket.',
        category: 'Examination',
        targetAudience: 'Senior Secondary (11-12)',
        attachmentBytes: bytes,
        attachmentName: 'mid-term.pdf',
      );

      expect(result.success, isTrue);
      expect(result.localOnly, isTrue);
      expect(result.noticeId, startsWith('notice_'));
      expect(result.attachmentUrl, startsWith('data:application/pdf;base64,'));

      final cached = AuthService.getCachedNotices();
      expect(cached, hasLength(1));
      expect(cached.single.title, 'Mid-Term Examination Guidelines');
      expect(cached.single.category, 'Examination');
      expect(cached.single.targetAudience, 'Senior Secondary (11-12)');
      expect(cached.single.attachmentName, 'mid-term.pdf');
      expect(cached.single.attachmentSize, bytes.length);
      expect(cached.single.hasAttachment, isTrue);
      expect(cached.single.isPdfAttachment, isTrue);
    });

    test('a failed live Firestore write returns failure and caches nothing',
        () async {
      AuthService.isFirebaseLiveOverride = true;

      final result = await auth.publishSchoolNotice(
        title: 'Sports Day Circular',
        content: 'Sports Day is postponed to Thursday.',
        category: 'Sports',
        targetAudience: 'All Students',
        attachmentBytes: pdfBytes(),
        attachmentName: 'sports-day.pdf',
      );

      expect(result.success, isFalse);
      expect(result.localOnly, isFalse);
      expect(result.error, contains('Could not broadcast'));
      // The attachment may have been prepared or uploaded, but a denied
      // broadcast must not leave a cached notice that looks delivered.
      expect(AuthService.getCachedNotices(), isEmpty);
    });

    test('SchoolNotice parses category, audience, and PDF metadata', () {
      final notice = SchoolNotice.fromMap('notice_1', {
        'title': 'Term 2 Circular',
        'content': 'Read the attached circular.',
        'category': 'Academic',
        'target_audience': 'Senior Secondary (11-12)',
        'date': '10/11/2026',
        'attachment_url': 'https://example.test/circulars/notice_1/term2.pdf',
        'attachment_name': 'term2.pdf',
        'attachment_size': 2048,
      });

      expect(notice.categoryLabel, 'Academic');
      expect(notice.targetAudience, 'Senior Secondary (11-12)');
      expect(notice.hasAttachment, isTrue);
      expect(notice.isPdfAttachment, isTrue);
      expect(notice.attachmentLabel, 'term2.pdf');
      expect(notice.attachmentSize, 2048);
    });

    test('a PDF larger than the inline Firestore fallback is refused', () async {
      final oversized = Uint8List(kMaxInlineCircularPdfBytes + 1);

      final url = await auth.uploadCircularPdf(
        bytes: oversized,
        noticeId: 'notice_oversized',
        fileName: 'oversized.pdf',
      );

      expect(url, isNull);
    });

    test('storage path is scoped under circulars/{noticeId}', () {
      expect(
        AuthService.formatCircularStoragePath(
          noticeId: ' notice_123 ',
          fileName: '..\\Term 2 // circular.pdf',
        ),
        'circulars/notice_123/circular.pdf',
      );
    });
  });

  group('SchoolCircularComposer widget flow', () {
    Future<List<SchoolNoticePublishResult?>> openComposer(
      WidgetTester tester, {
      required CircularPublishCallback onPublish,
      CircularPdfPicker? pickPdf,
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final popped = <SchoolNoticePublishResult?>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const Key('open_circular_composer'),
                  onPressed: () async {
                    final result =
                        await showModalBottomSheet<SchoolNoticePublishResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SchoolCircularComposer(
                        isDark: false,
                        onPublish: onPublish,
                        pickPdf: pickPdf,
                      ),
                    );
                    popped.add(result);
                  },
                  child: const Text('Open composer'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_circular_composer')));
      await tester.pumpAndSettle();
      return popped;
    }

    testWidgets('admin attaches a PDF, picks details, and publishes',
        (tester) async {
      final bytes = pdfBytes();
      String? seenTitle;
      String? seenContent;
      String? seenCategory;
      String? seenAudience;
      PickedCircularPdf? seenPdf;

      final popped = await openComposer(
        tester,
        pickPdf: () async => PickedCircularPdf(
          bytes: bytes,
          fileName: 'annual-day.pdf',
        ),
        onPublish: ({
          required String title,
          required String content,
          required String category,
          required String targetAudience,
          PickedCircularPdf? pdf,
        }) async {
          seenTitle = title;
          seenContent = content;
          seenCategory = category;
          seenAudience = targetAudience;
          seenPdf = pdf;
          return SchoolNoticePublishResult.success(
            noticeId: 'notice_widget_1',
            attachmentUrl: 'data:application/pdf;base64,AA==',
          );
        },
      );

      await tester.tap(find.byKey(const Key('circular_pdf_picker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('circular_pdf_preview')), findsOneWidget);
      expect(find.text('annual-day.pdf'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('circular_title_field')),
        'Annual Day Circular',
      );
      await tester.enterText(
        find.byKey(const Key('circular_content_field')),
        'Annual Day will be held on Saturday. Parents are invited.',
      );

      await tester.tap(find.byKey(const Key('circular_category_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sports').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('circular_audience_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Senior Secondary (11-12)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('publish_circular_button')));
      await tester.pumpAndSettle();

      expect(seenTitle, 'Annual Day Circular');
      expect(seenContent, 'Annual Day will be held on Saturday. Parents are invited.');
      expect(seenCategory, 'Sports');
      expect(seenAudience, 'Senior Secondary (11-12)');
      expect(seenPdf, isNotNull);
      expect(seenPdf!.fileName, 'annual-day.pdf');
      expect(seenPdf!.bytes, bytes);

      // Success closes the sheet and returns the publish result.
      expect(find.byKey(const Key('publish_circular_button')), findsNothing);
      expect(popped, hasLength(1));
      expect(popped.single!.success, isTrue);
      expect(popped.single!.noticeId, 'notice_widget_1');
    });

    testWidgets('failed publish keeps the sheet open and shows the real error',
        (tester) async {
      final popped = await openComposer(
        tester,
        onPublish: ({
          required String title,
          required String content,
          required String category,
          required String targetAudience,
          PickedCircularPdf? pdf,
        }) async {
          return SchoolNoticePublishResult.failure(
            'Could not broadcast the circular. Check your admin access and try again.',
          );
        },
      );

      await tester.enterText(
        find.byKey(const Key('circular_title_field')),
        'Holiday Notice',
      );
      await tester.enterText(
        find.byKey(const Key('circular_content_field')),
        'School will remain closed on Sunday.',
      );

      await tester.tap(find.byKey(const Key('publish_circular_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('circular_error_banner')), findsOneWidget);
      expect(find.textContaining('Could not broadcast'), findsOneWidget);
      expect(find.byKey(const Key('publish_circular_button')), findsOneWidget);
      expect(popped, isEmpty);
    });

    testWidgets('an oversized PDF is rejected before publish', (tester) async {
      var publishCalled = false;

      await openComposer(
        tester,
        pickPdf: () async => PickedCircularPdf(
          bytes: Uint8List(kMaxSchoolCircularPdfBytes + 1),
          fileName: 'huge.pdf',
        ),
        onPublish: ({
          required String title,
          required String content,
          required String category,
          required String targetAudience,
          PickedCircularPdf? pdf,
        }) async {
          publishCalled = true;
          return SchoolNoticePublishResult.success(noticeId: 'nope');
        },
      );

      await tester.tap(find.byKey(const Key('circular_pdf_picker')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('circular_error_banner')), findsOneWidget);
      expect(find.textContaining('larger than 15 MB'), findsOneWidget);
      expect(find.byKey(const Key('circular_pdf_preview')), findsNothing);
      expect(publishCalled, isFalse);
    });
  });

  group('Circular rules contracts', () {
    test('notices validation and Storage PDF path are present in the rules',
        () {
      final firestore = File('firestore.rules').readAsStringSync();
      final storage = File('storage.rules').readAsStringSync();

      expect(firestore, contains('function isValidSchoolNotice(data)'));
      expect(
        firestore,
        contains('data.attachment_url is string && data.attachment_url.size() <= 1000000'),
      );
      expect(
        firestore,
        contains("allow write: if isAdmin() && isValidSchoolNotice(request.resource.data);"),
      );

      expect(storage, contains('match /circulars/{noticeId}/{fileName=**}'));
      final circularBlock = storage.substring(
        storage.indexOf('match /circulars/{noticeId}/{fileName=**}'),
      );
      expect(circularBlock, contains('allow read: if isSignedIn();'));
      expect(circularBlock, contains('isPdf() && isUnderMaxSize(15)'));
    });
  });
}
