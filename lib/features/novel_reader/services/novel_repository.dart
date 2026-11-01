import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/novel_chapter.dart';

class NovelBook {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String description;
  final List<NovelChapter> chapters;
  final bool isCustom;

  const NovelBook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    required this.chapters,
    this.isCustom = false,
  });
}

class NovelRepository {
  static final NovelRepository _instance = NovelRepository._internal();
  factory NovelRepository() => _instance;
  NovelRepository._internal();

  static final List<NovelBook> _curatedNovels = [
    NovelBook(
      id: 'solo_leveling',
      title: 'Поднятие уровня в одиночку',
      author: 'Чхугон (Chugong)',
      coverUrl: 'https://remanga.org/media/titles/solo-leveling/cover_high.webp',
      description: 'Десять лет назад открылись Врата, соединившие наш мир с миром монстров. Сон Джин-у — охотник E-ранга, которого все называют «самым слабым оружием человечества». Но всё изменилось в двойном подземелье...',
      chapters: [
        NovelChapter(
          id: 'sl_1',
          title: 'Глава 1: Самый слабый охотник E-ранга',
          chapterNumber: '1',
          publishedAt: DateTime(2025, 1, 1),
          content: '''
Глава 1: Самый слабый охотник E-ранга

Десять лет назад, после того как таинственные Врата связали наш мир с миром чудовищ, среди обычных людей стали пробуждаться те, кто получил сверхъестественные способности. Их стали называть Охотниками.

Сон Джин-у был одним из них. Вот только его ранг был самым низким — E-ранг. 

В мире, где даже охотники D-ранга легко расправлялись с низшими монстрами, Джин-у с трудом выживал в самых легких подземельях. Каждая вылазка оборачивалась для него тяжелыми травмами, а заработанных денег едва хватало на оплату счетов в больнице матери.

— Джин-у, ты снова здесь? — окликнул его мистер Сон, один из ветеранов рейда.
— Да, мистер Сон. Мне нужны деньги на лекарства, — с вежливой улыбкой ответил парень, поправляя дешевый нож на поясе.

Собравшаяся группа из шестнадцати человек двинулась внутрь темного туннеля подземелья D-ранга. Поначалу всё шло как обычно: слабые гоблины легко погибали под ударами магов и танков. Но в глубине пещеры отряд наткнулся на нечто невиданное — еще одни массивные каменные врата, ведущие в тайное святилище.

— Двойное подземелье? — прошептал лидер рейда, сглотнув ком в горле. — В уставе ассоциации сказано: если большинство за, мы имеем право войти...
''',
        ),
        NovelChapter(
          id: 'sl_2',
          title: 'Глава 2: Храм Картеннона и колоссы',
          chapterNumber: '2',
          publishedAt: DateTime(2025, 1, 2),
          content: '''
Глава 2: Храм Картеннона и колоссы

Тяжелые каменные двери с глухим рокотом захлопнулись за спинами охотников, отрезая путь к отступлению.

В центре исполинского зала возвышалась колоссальная каменная статуя, восседающая на троне. Вокруг нее стояли десятки других исполинов, сжимающих в руках гигантские музыкальные инструменты и оружие.

— Что это за место?.. — испуганно пробормотала юная целительница Чжу-хи, судорожно вцепившись в рукав Джин-у.

На каменной плите у подножия трона виднелись древние письмена:
«Заповеди Храма Картеннона:
Первое — почитай Бога.
Второе — восхваляй Бога.
Третье — докажи свою веру.
Тот, кто нарушит заповеди, никогда не вернется живым».

Внезапно один из охотников потерял самообладание:
— Да к черту это! Я ухожу! — закричал он и бросился к выходу.

Но стоило ему сделать шаг к дверям, как каменная статуя рыцаря у входа взмахнула исполинским топором. Раздался глухой удар — и от беглеца осталась лишь багровая пыль.

В зале повисла мертвая тишина. Медленно, со скрежетом многотонного камня, голова гигантской статуи на троне повернулась. Её глаза вспыхнули багровым адским пламенем.
''',
        ),
        NovelChapter(
          id: 'sl_3',
          title: 'Глава 3: Пробуждение Системы Игрока',
          chapterNumber: '3',
          publishedAt: DateTime(2025, 1, 3),
          content: '''
Глава 3: Пробуждение Системы Игрока

Смертельный лазерный взор исполина испепелял всё на своем пути. За считанные минуты половина отряда была уничтожена. 

Только благодаря феноменальной наблюдательности Джин-у удалось разгадать первую заповедь:
— Всем на колени! Поклонитесь ему!

Оставшиеся в живых пали ниц. Огненный взор угас, а на каменных губах гиганта застыла зловещая, жуткая улыбка.

Однако испытание алтаря требовало последней жертвы. Когда круг огней начал замыкаться, Джин-у остался на алтаре один, прикрывая отход раненой Чжу-хи и лидера отряда.

Каменные мечи колоссов обрушились на него. Боль пронзила всё тело, мир перед глазами начал угасать в кровавой пелене.

«Я не хочу умирать... Если бы мне дали еще один шанс...» — пронеслась последняя мысль.

В этот миг время замерло. Перед меркнущим взором Джин-у материализовалось полупрозрачное неоновое окно:

[Поздравляем! Вы выполнили скрытые условия секретного квеста «Мужество слабейшего»].
[Вы получили квалификацию стать «Игроком»].
[Принять предложение? Сердце остановится через 3... 2... 1...].

— Принять... — прошептали пересохшие губы.

[Добро пожаловать в Систему].
''',
        ),
      ],
    ),
    NovelBook(
      id: 'omniscient_reader',
      title: 'Точка зрения всеведущего читателя',
      author: 'Sing Shong',
      coverUrl: 'https://remanga.org/media/titles/omniscient-readers-viewpoint/cover_high.webp',
      description: 'Ким Докча — единственный читатель, дочитавший до конца веб-новеллу «Три способа выжить в разрушенном мире». И когда реальность внезапно превратилась в эту самую новеллу, только он знал, чем всё закончится.',
      chapters: [
        NovelChapter(
          id: 'orv_1',
          title: 'Глава 1: Бесплатная услуга завершена',
          chapterNumber: '1',
          publishedAt: DateTime(2025, 1, 1),
          content: '''
Глава 1: Бесплатная услуга завершена

«Три способа выжить в разрушенном мире».
Новелла из 3149 глав. Десять лет публикаций. Единственный постоянный читатель — я, Ким Докча.

В метро по пути с работы я дочитал последний эпилог и отправил автору благодарственное письмо. Ответ пришел почти мгновенно:
«Спасибо вам за всё. Моя история станет платной сегодня в 19:00. Надеюсь, она поможет вам выжить».

Ровно в семь вечера поезд метро дернулся и замер посреди темного туннеля. Погас свет.

В воздухе раздался сухой треск, и посреди вагона возникло странное парящее существо с рожками и меховым тельцем — токкэби Бихён.

— [А-а-а, проверка связи! Наконец-то подключился канал планеты 8612. Людишки, бесплатное демо вашей жизни подошло к концу].

Перед каждым пассажиром в воздухе вспыхнули синие буквы:

[Основной сценарий #1 — Доказать ценность]
Категория: Основной
Сложность: F
Условие: Убейте одно или более живых существ за 30 минут.
Награда: 300 монет
Штраф за провал: Смерть.

Паника охватила вагон. Но я не паниковал. Я читал эту главу сотни раз.
''',
        ),
      ],
    ),
    NovelBook(
      id: 'iron_blood_hound',
      title: 'Мастер меча из клана Гончих',
      author: 'Sword Hound',
      coverUrl: 'https://remanga.org/media/titles/revenge-of-the-iron-blooded-sword-hound/cover_high.webp',
      description: 'Викир был верным охотничьим псом семьи Баскервилль, выполнявшим самую грязную работу. Но в награду получил лишь гильотину. Переродившись в теле младенца, он решает отомстить своему палачу.',
      chapters: [
        NovelChapter(
          id: 'hound_1',
          title: 'Глава 1: Верный пёс на эшафоте',
          chapterNumber: '1',
          publishedAt: DateTime(2025, 1, 1),
          content: '''
Глава 1: Верный пёс на эшафоте

Холодное лезвие гильотины блеснуло в серых лучах рассвета.

— Викир Ван Баскервилль. Ты признан виновным в государственной измене, — ледяным тоном объявил патриарх клана Хьюго Баскервилль, человек, ради которого Викир пролил океаны крови.

Викир не оправдывался. Он сорок лет был тайным клинком клана, устранял врагов и выполнял грязные приказы. И теперь, когда в нем отпала надобность, его просто выбросили, как сломанный инструмент.

— Если охота окончена — гончих псов варят в котле, — криво усмехнулся Викир сквозь окровавленные губы.

Тяжелый нож сорвался вниз. Тьма.

...А в следующее мгновение он почувствовал, как чьи-то нежные руки бережно баюкают его, а над головой сияют роскошные своды детской спальни великого замка.

«Я... жив? И это руки кормилицы?»
Викир взглянул на свои крошечные пухлые ручки. Он вернулся назад на сорок лет. И на этот раз он больше никогда не станет чужой цепной собакой.
''',
        ),
      ],
    ),
  ];

  /// Список всех доступных ранобэ и книг
  Future<List<NovelBook>> getAllNovels() async {
    final customBooks = await _loadCustomNovels();
    return [..._curatedNovels, ...customBooks];
  }

  /// Поиск ранобэ для конкретной манги
  Future<NovelBook?> findNovelForManga(String mangaId, String mangaTitle) async {
    final titleLower = mangaTitle.toLowerCase();
    final all = await getAllNovels();

    for (final book in all) {
      final bTitle = book.title.toLowerCase();
      if (titleLower.contains(bTitle) || bTitle.contains(titleLower)) {
        return book;
      }
      if (titleLower.contains('одиночк') && bTitle.contains('одиночк')) return book;
      if (titleLower.contains('читател') && bTitle.contains('читател')) return book;
      if (titleLower.contains('гонч') && bTitle.contains('гонч')) return book;
    }

    return null;
  }

  /// Сохранение пользовательской книги/ранобэ
  Future<void> addCustomNovel({
    required String title,
    required String author,
    required String chapterTitle,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_novels') ?? [];

    final newBook = {
      'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'author': author.isNotEmpty ? author : 'Пользовательский файл',
      'coverUrl': 'https://placehold.co/256x360/18181b/fafafa?text=Book',
      'description': 'Книга добавлена из памяти устройства',
      'chapters': [
        {
          'id': 'c_${DateTime.now().millisecondsSinceEpoch}',
          'title': chapterTitle.isNotEmpty ? chapterTitle : 'Глава 1',
          'chapterNumber': '1',
          'publishedAt': DateTime.now().toIso8601String(),
          'content': content,
        }
      ],
    };

    list.add(jsonEncode(newBook));
    await prefs.setStringList('custom_novels', list);
  }

  Future<List<NovelBook>> _loadCustomNovels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('custom_novels') ?? [];
      final List<NovelBook> result = [];

      for (final raw in list) {
        final data = jsonDecode(raw);
        final chaps = (data['chapters'] as List).map((c) => NovelChapter(
          id: c['id'],
          title: c['title'],
          chapterNumber: c['chapterNumber'] ?? '1',
          content: c['content'],
          publishedAt: DateTime.tryParse(c['publishedAt'] ?? '') ?? DateTime.now(),
        )).toList();

        result.add(NovelBook(
          id: data['id'],
          title: data['title'],
          author: data['author'],
          coverUrl: data['coverUrl'] ?? '',
          description: data['description'] ?? '',
          chapters: chaps,
          isCustom: true,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('Error loading custom novels: $e');
      return [];
    }
  }
}
