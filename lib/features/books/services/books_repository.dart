import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book_item.dart';
import 'flibusta_service.dart';

class BooksRepository {
  static final BooksRepository _instance = BooksRepository._internal();
  factory BooksRepository() => _instance;
  BooksRepository._internal();

  final FlibustaService _flibusta = FlibustaService();

  static const List<String> genres = [
    'Все',
    'Фантастика',
    'Мистика и Ужасы',
    'Детектив',
    'Приключения',
    'Классика',
  ];

  static const List<String> availableSources = [
    'Флибуста (Flibusta)',
    'Открытая библиотека классики',
    'Все источники',
    'Мои книги (.txt/.fb2)',
  ];

  static const List<BookItem> _curatedClassics = [
    BookItem(
      id: 'master_and_margarita',
      title: 'Мастер и Маргарита',
      author: 'Михаил Булгаков',
      genre: 'Мистика и Ужасы',
      year: 1940,
      rating: 9.9,
      coverUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400&q=80',
      description: 'Однажды весною, в час небывало жаркого заката, в Москве, на Патриарших прудах, появились два гражданина... Великий роман о дьяволе в советской Москве, любви Мастера и Маргариты и вечном суде Понтия Пилата.',
      chapters: [
        BookChapter(
          id: 'mm_1',
          number: '1',
          title: 'Глава 1: Никогда не разговаривайте с неизвестными',
          content: '''
Глава 1: Никогда не разговаривайте с неизвестными

Однажды весною, в час небывало жаркого заката, в Москве, на Патриарших прудах, появились два гражданина. Первый был не кто иной, как Михаил Александрович Берлиоз, председатель правления одной из крупнейших московских литературных ассоциаций, а молодой спутник его — поэт Иван Николаевич Понырев, пишущий под псевдонимом Бездомный.

Попав в тень чуть зеленеющих лип, писатели первым долгом бросились к пестро раскрашенной будочке с надписью «Пиво и воды».

— Дайте нарзану, — попросил Берлиоз.
— Нарзану нету, — ответила женщина в будочке и почему-то обиделась.
— А пиво есть? — сиплым голосом осведомился Бездомный.
— Пиво привезут к вечеру, — ответила женщина.
— А что есть? — спросил Берлиоз.
— Абрикосовая, только теплая, — сказала женщина.
— Ну, давайте, давайте, давайте!..

Абрикосовая дала обильную желтую пену, и в воздухе запахло парикмахерской. Напившись, литераторы немедленно начали икать, расплатились и уселись на скамейке лицом к пруду и спиной к Бронной.

И тут знойный воздух сгустился перед ними, и соткался из этого воздуха сквозящий гражданин престранного вида. На маленькой головке жокейский картузик, клетчатый куцый воздушный же пиджачок... Гражданин ростом в сажень, но в плечах узок, худ неимоверно, и физиономия, прошу заметить, глумливая.
''',
        ),
        BookChapter(
          id: 'mm_2',
          number: '2',
          title: 'Глава 2: Понтий Пилат',
          content: '''
Глава 2: Понтий Пилат

В белом плаще с кровавым подбоем, шаркающей кавалерийской походкой, ранним утром четырнадцатого числа весеннего месяца нисана в крытую колоннаду между двумя крыльями дворца Ирода Великого вышел прокуратор Иудеи Понтий Пилат.

Более всего на свете прокуратор ненавидел запах розового масла, и все теперь предвещало нехороший день, так как запах этот начал преследовать прокуратора с рассвета.

— Привели арестованного? — спросил Пилат.
— Привели, — ответил легионер.

Из флигеля на площадку сада вывели человека лет двадцати семи. Этот человек был одет в старенький и разорванный голубой хитон. Под левым глазом у человека был большой синяк, в углу рта — ссадина с запекшейся кровью.

— Имя? — спросил прокуратор.
— Мое? — торопливо отозвался арестованный. — Иешуа.
— Прозвище есть?
— Га-Ноцри.
''',
        ),
      ],
    ),
    BookItem(
      id: 'sherlock_holmes_study',
      title: 'Этюд в багровых тонах',
      author: 'Артур Конан Дойл',
      genre: 'Детектив',
      year: 1887,
      rating: 9.7,
      coverUrl: 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400&q=80',
      description: 'Первое легендарное дело Шерлока Холмса и доктора Джона Ватсона. Загадочное убийство в заброшенном лондонском доме, надпись кровью на стене «RACHE» и запутанная месть, тянущаяся через океан.',
      chapters: [
        BookChapter(
          id: 'sh_1',
          number: '1',
          title: 'Глава 1: Мистер Шерлок Холмс',
          content: '''
Глава 1: Мистер Шерлок Холмс

В 1878 году я окончил Лондонский университет, получив диплом военного врача. Меня прикомандировали к Пятому Нортумберлендскому стрелковому полку. В сражении при Майванде я был ранен в плечо пулей.

Изнуренный и обессиленный, я был отправлен военным транспортом обратно в Англию. У меня не было в Лондоне ни родных, ни друзей.

Именно в этот день в баре «Критерион» я столкнулся с молодым Стэмфордом:
— Ищу квартиру, — признался я. — Пытаюсь найти человека, который согласился бы поделить со мной расходы пополам.
Стэмфорд странно посмотрел на меня:
— Знаете, вы сегодня уже второй, кто говорит мне это. Утром один парень жаловался, что нашел отличные комнаты на Бейкер-стрит, 221-Б, но они слишком дороги для одного... Его зовут Шерлок Холмс.
''',
        ),
      ],
    ),
    BookItem(
      id: 'call_of_cthulhu',
      title: 'Зов Ктулху',
      author: 'Говард Филлипс Лавкрафт',
      genre: 'Мистика и Ужасы',
      year: 1928,
      rating: 9.6,
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=400&q=80',
      description: '«Самое милосердное в этом мире, как мне кажется, — это неспособность человеческого разума связать воедино всё, что в нём содержится». Расследование культа древнего спящего божества со дна Тихого океана.',
      chapters: [
        BookChapter(
          id: 'cc_1',
          number: '1',
          title: 'Часть 1: Ужас в глине',
          content: '''
Часть 1: Ужас в глине

Самое милосердное в этом мире, как мне кажется, — это неспособность человеческого разума связать воедино всё, что в нём содержится. Мы живём на спокойном островке неведения посреди чёрных морей бесконечности.

Среди бумаг моего покойного двоюродного деда профессора Энджелла я нашел странный глиняный барельеф. На нем было вылеплено существо, в котором смутно угадывались черты осьминога, дракона и чудовищной карикатуры на человека. Внизу неровными угловатыми рунами было высечено жуткое воззвание:
«Пх’нглуи мглв’нафх Ктулху Р’льех вгах’нагл фхтагн».
''',
        ),
      ],
    ),
    BookItem(
      id: 'we_zamyatin',
      title: 'Мы',
      author: 'Евгений Замятин',
      genre: 'Фантастика',
      year: 1920,
      rating: 9.5,
      coverUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=400&q=80',
      description: 'Великая антиутопия XX века, предвосхитившая романы Оруэлла и Хаксли. Стеклянный город Единого Государства, люди с номерами вместо имен, математическая гармония и зарождение бунта.',
      chapters: [
        BookChapter(
          id: 'we_1',
          number: '1',
          title: 'Запись 1: Стеклянный Интеграл',
          content: '''
Запись 1: Стеклянный Интеграл

Я просто списываю — слово в слово — то, что сегодня напечатано в Государственной Газете:
«Через 120 дней заканчивается постройка ИНТЕГРАЛА. Близится великий час, когда первый ИНТЕГРАЛ взовьется в мировое пространство. Вам предстоит подчинить благодетельному игу разума неведомые существа на иных планетах. Наш долг заставить их быть счастливыми!»
Я — Д-503, строитель Интеграла.
''',
        ),
      ],
    ),
    BookItem(
      id: 'mysterious_island',
      title: 'Таинственный остров',
      author: 'Жюль Верн',
      genre: 'Приключения',
      year: 1874,
      rating: 9.8,
      coverUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400&q=80',
      description: 'Во время Гражданской войны в США пятеро смельчаков бегут из осажденного Ричмонда на воздушном шаре и терпят крушение на необитаемом острове южной части Тихого океана.',
      chapters: [
        BookChapter(
          id: 'mi_1',
          number: '1',
          title: 'Глава 1: Буря 1865 года',
          content: '''
Глава 1: Буря 1865 года

— Мы поднимаемся?
— Нет! Напротив! Мы падаем!
— Выбросьте за борт всё лишнее!
— Всё уже выброшено!
Такие возгласы раздавались над пустынными просторами Тихого океана 23 марта 1865 года.
''',
        ),
      ],
    ),
    BookItem(
      id: 'crime_and_punishment',
      title: 'Преступление и наказание',
      author: 'Федор Достоевский',
      genre: 'Классика',
      year: 1866,
      rating: 9.8,
      coverUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=400&q=80',
      description: '«Тварь ли я дрожащая или право имею?» Психологическая драма Родиона Раскольникова в душных переулках Петербурга, его теория об исключительных личностях и путь к искуплению.',
      chapters: [
        BookChapter(
          id: 'cp_1',
          number: '1',
          title: 'Часть 1: Каморка Раскольникова',
          content: '''
Часть 1: Каморка Раскольникова

В начале июля, в чрезвычайно жаркое время, под вечер, один молодой человек вышел из своей каморки, которую нанимал от жильцов в С — м переулке, на улицу и медленно, как бы в нерешимости, отправился к К — ну мосту.
«На какое дело хочу покуситься и в то же время каких пустяков боюсь!» — подумал он со странной улыбкой.
''',
        ),
      ],
    ),
  ];

  Future<List<BookItem>> getBooks({
    String source = 'Флибуста (Flibusta)',
    String genre = 'Все',
    String search = '',
  }) async {
    List<BookItem> baseList = [];

    if (source.contains('Флибуста') || source.contains('Flibusta')) {
      final flibustaBooks = await _flibusta.searchFlibusta(search);
      baseList = flibustaBooks;
    } else if (source.contains('Классика') || source.contains('классики')) {
      baseList = _curatedClassics;
    } else if (source.contains('Мои книги') || source.contains('файлы')) {
      baseList = await _loadCustomBooks();
    } else {
      // Все источники
      final flibustaBooks = await _flibusta.searchFlibusta(search);
      final custom = await _loadCustomBooks();
      baseList = [...flibustaBooks, ..._curatedClassics, ...custom];
    }

    // Если был выбран источник "Классика" или "Все", применяем фильтр жанров и поиска
    return baseList.where((book) {
      if (genre != 'Все' && book.genre != genre) {
        return false;
      }
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        final matchTitle = book.title.toLowerCase().contains(q);
        final matchAuthor = book.author.toLowerCase().contains(q);
        return matchTitle || matchAuthor;
      }
      return true;
    }).toList();
  }

  Future<BookItem?> getBookById(String id) async {
    final all = await getBooks(source: 'Все источники');
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addCustomBook({
    required String title,
    required String author,
    required String genre,
    required String chapterTitle,
    required String content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('custom_library_books') ?? [];

    final newBook = {
      'id': 'book_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'author': author.isNotEmpty ? author : 'Пользовательская книга',
      'genre': genre,
      'year': DateTime.now().year,
      'coverUrl': 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400&q=80',
      'description': 'Книга добавлена пользователем',
      'chapters': [
        {
          'id': 'ch_${DateTime.now().millisecondsSinceEpoch}',
          'number': '1',
          'title': chapterTitle.isNotEmpty ? chapterTitle : 'Глава 1',
          'content': content,
        }
      ],
    };

    list.add(jsonEncode(newBook));
    await prefs.setStringList('custom_library_books', list);
  }

  Future<List<BookItem>> _loadCustomBooks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('custom_library_books') ?? [];
      final List<BookItem> result = [];

      for (final raw in list) {
        final data = jsonDecode(raw);
        final chaps = (data['chapters'] as List).map((c) => BookChapter(
          id: c['id'],
          number: c['number'] ?? '1',
          title: c['title'],
          content: c['content'],
        )).toList();

        result.add(BookItem(
          id: data['id'],
          title: data['title'],
          author: data['author'],
          genre: data['genre'] ?? 'Классика',
          year: data['year'] ?? 2025,
          coverUrl: data['coverUrl'] ?? '',
          description: data['description'] ?? '',
          chapters: chaps,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('Error loading custom books: $e');
      return [];
    }
  }
}
