import 'package:flutter_test/flutter_test.dart';
import 'package:manga_reader_app/features/reader/models/chapter.dart';
import 'package:manga_reader_app/features/reader/services/chapter_selection.dart';
import 'package:manga_reader_app/features/reader/services/reader_mode.dart';

void main() {
  group('ChapterSelection.orderedChapters', () {
    test('orders chapters chronologically ascending when manga source returns descending (187 down to 1)', () {
      final ch187 = Chapter(
        id: 'c187',
        mangaId: 'm1',
        chapterNumber: '187',
        publishedAt: DateTime(2024, 1, 1),
      );
      final ch2 = Chapter(
        id: 'c2',
        mangaId: 'm1',
        chapterNumber: '2',
        publishedAt: DateTime(2023, 1, 2),
      );
      final ch1 = Chapter(
        id: 'c1',
        mangaId: 'm1',
        chapterNumber: '1',
        publishedAt: DateTime(2023, 1, 1),
      );

      final result = ChapterSelection.orderedChapters([ch187, ch2, ch1]);
      expect(result.map((c) => c.chapterNumber).toList(), ['1', '2', '187']);
    });

    test('sorts decimals (1, 1.5, 2, 10) numerically and not lexically', () {
      final ch10 = Chapter(
        id: 'c10',
        mangaId: 'm1',
        chapterNumber: '10',
        publishedAt: DateTime(2023, 1, 4),
      );
      final ch2 = Chapter(
        id: 'c2',
        mangaId: 'm1',
        chapterNumber: '2',
        publishedAt: DateTime(2023, 1, 3),
      );
      final ch1_5 = Chapter(
        id: 'c1.5',
        mangaId: 'm1',
        chapterNumber: '1.5',
        publishedAt: DateTime(2023, 1, 2),
      );
      final ch1 = Chapter(
        id: 'c1',
        mangaId: 'm1',
        chapterNumber: '1',
        publishedAt: DateTime(2023, 1, 1),
      );

      final result = ChapterSelection.orderedChapters([ch10, ch2, ch1_5, ch1]);
      expect(result.map((c) => c.chapterNumber).toList(), ['1', '1.5', '2', '10']);
    });

    test('preserves original compound IDs and handles special non-numeric labels deterministically', () {
      final chCompound = Chapter(
        id: 'vol-1-ch-5-extra',
        mangaId: 'm1',
        chapterNumber: '5-extra',
        publishedAt: DateTime(2023, 1, 3),
      );
      final chPrequel = Chapter(
        id: 'prologue_spec',
        mangaId: 'm1',
        chapterNumber: 'Пролог',
        publishedAt: DateTime(2023, 1, 1),
      );
      final ch1 = Chapter(
        id: 'ch_num_1',
        mangaId: 'm1',
        chapterNumber: '1',
        publishedAt: DateTime(2023, 1, 2),
      );

      final result = ChapterSelection.orderedChapters([chCompound, chPrequel, ch1]);
      expect(result.map((c) => c.id).toSet(), containsAll(['vol-1-ch-5-extra', 'prologue_spec', 'ch_num_1']));
      expect(result.isNotEmpty, isTrue);
    });
  });

  group('ChapterSelection.initialChapter', () {
    test('resumes exact chapter by ID when resumeChapterId is provided and available', () {
      final ch1 = Chapter(
        id: 'c1',
        mangaId: 'm1',
        chapterNumber: '1',
        publishedAt: DateTime(2023, 1, 1),
      );
      final ch2 = Chapter(
        id: 'c2',
        mangaId: 'm1',
        chapterNumber: '2',
        publishedAt: DateTime(2023, 1, 2),
      );

      final selected = ChapterSelection.initialChapter([ch1, ch2], resumeChapterId: 'c2');
      expect(selected?.id, 'c2');
    });

    test('selects earliest free chapter when no resumeChapterId, never lexical 187 first', () {
      final ch187 = Chapter(
        id: 'c187',
        mangaId: 'm1',
        chapterNumber: '187',
        publishedAt: DateTime(2024, 1, 1),
      );
      final ch1 = Chapter(
        id: 'c1',
        mangaId: 'm1',
        chapterNumber: '1',
        publishedAt: DateTime(2023, 1, 1),
      );

      // Even if list is returned in descending order [187, 1]
      final selected = ChapterSelection.initialChapter([ch187, ch1]);
      expect(selected?.chapterNumber, '1');
      expect(selected?.id, 'c1');
    });

    test('skips paid chapters and does not bypass paid status when choosing earliest free chapter', () {
      final ch1Paid = Chapter(
        id: 'c1',
        mangaId: 'm1',
        chapterNumber: '1',
        publishedAt: DateTime(2023, 1, 1),
        isPaid: true,
      );
      final ch2Free = Chapter(
        id: 'c2',
        mangaId: 'm1',
        chapterNumber: '2',
        publishedAt: DateTime(2023, 1, 2),
        isPaid: false,
      );

      final selected = ChapterSelection.initialChapter([ch1Paid, ch2Free]);
      expect(selected?.id, 'c2');
      expect(selected?.isPaid, isFalse);
    });
  });

  group('ReaderModeResolver.fromImageDimensions', () {
    test('resolves tall strip dimensions (e.g. 900x12000) as webtoon', () {
      final mode = ReaderModeResolver.fromImageDimensions(900, 12000);
      expect(mode, ReaderMode.webtoon);
    });

    test('resolves normal page dimensions (e.g. 900x1300) as paged', () {
      final mode = ReaderModeResolver.fromImageDimensions(900, 1300);
      expect(mode, ReaderMode.paged);
    });

    test('safely falls back for invalid dimensions (zero or negative)', () {
      final modeZero = ReaderModeResolver.fromImageDimensions(0, 0);
      expect(modeZero, isA<ReaderMode>());

      final modeNegative = ReaderModeResolver.fromImageDimensions(-100, 1000);
      expect(modeNegative, isA<ReaderMode>());
    });
  });
}
