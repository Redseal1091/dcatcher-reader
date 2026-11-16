import 'package:flutter/material.dart';

class MangaGenre {
  final String id;
  final String nameRu;
  final String nameEn;
  final String category;
  final IconData icon;
  final List<String> aliases;

  const MangaGenre({
    required this.id,
    required this.nameRu,
    required this.nameEn,
    required this.category,
    required this.icon,
    this.aliases = const [],
  });

  /// Check whether a genre matches a search query or a raw tag from an extension
  bool matches(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return false;
    if (id.toLowerCase() == clean) return true;
    if (nameRu.toLowerCase() == clean || nameEn.toLowerCase() == clean) return true;
    if (nameRu.toLowerCase().contains(clean) || nameEn.toLowerCase().contains(clean)) return true;
    return aliases.any((a) {
      final al = a.toLowerCase();
      return al == clean || al.contains(clean) || clean.contains(al);
    });
  }

  /// All unique categories in logical presentation order
  static const List<String> categories = [
    'Все',
    '🔥 Вебтуны и темы',
    '⚔️ Экшен и бой',
    '🔮 Фэнтези и мистика',
    '🎭 Драма и эмоции',
    '❤️ Романтика и сёдзе',
    '🚀 Фантастика и сеттинг',
    '🎯 Форматы и увлечения',
  ];

  static MangaGenre? findById(String id) {
    for (final g in allGenres) {
      if (g.id == id) return g;
    }
    return null;
  }

  static MangaGenre? findByNameOrAlias(String name) {
    final clean = name.trim().toLowerCase();
    for (final g in allGenres) {
      if (g.matches(clean)) return g;
    }
    return null;
  }

  static List<MangaGenre> search(String query, {String? category}) {
    final clean = query.trim().toLowerCase();
    return allGenres.where((g) {
      if (category != null && category != 'Все' && g.category != category) {
        return false;
      }
      if (clean.isEmpty) return true;
      return g.matches(clean);
    }).toList();
  }

  static const List<MangaGenre> allGenres = [
    // ---------------------------------------------------------
    // 🔥 Вебтуны и популярные темы манхвы / маньхуа
    // ---------------------------------------------------------
    MangaGenre(
      id: 'system',
      nameRu: 'Система',
      nameEn: 'System',
      category: '🔥 Вебтуны и темы',
      icon: Icons.developer_board_rounded,
      aliases: ['система', 'system', 'статусы', 'окно статуса', 'игровые элементы', 'game system'],
    ),
    MangaGenre(
      id: 'regression',
      nameRu: 'Регрессия',
      nameEn: 'Regression',
      category: '🔥 Вебтуны и темы',
      icon: Icons.history_rounded,
      aliases: ['регрессия', 'regression', 'петля времени', 'возврат во времени', 'второй шанс', 'time loop', 'regressed'],
    ),
    MangaGenre(
      id: 'reincarnation',
      nameRu: 'Перерождение',
      nameEn: 'Reincarnation',
      category: '🔥 Вебтуны и темы',
      icon: Icons.autorenew_rounded,
      aliases: ['перерождение', 'реинкарнация', 'reincarnation', 'перерожденный'],
    ),
    MangaGenre(
      id: 'ace04297-3a1a-4624-8149-47079e8eacab', // MangaDex Isekai UUID
      nameRu: 'Исекай',
      nameEn: 'Isekai',
      category: '🔥 Вебтуны и темы',
      icon: Icons.flight_takeoff_rounded,
      aliases: ['исекай', 'исэкай', 'isekai', 'попаданец', 'попаданцы', 'другой мир', 'another world'],
    ),
    MangaGenre(
      id: 'cultivation',
      nameRu: 'Культивация / Сянься',
      nameEn: 'Cultivation / Xianxia',
      category: '🔥 Вебтуны и темы',
      icon: Icons.self_improvement_rounded,
      aliases: ['культивация', 'сянься', 'сяньхуа', 'бессмертные', 'дао', 'культиватор', 'cultivation', 'xianxia', 'immortals'],
    ),
    MangaGenre(
      id: 'wuxia',
      nameRu: 'Уся / Мурим',
      nameEn: 'Wuxia / Murim',
      category: '🔥 Вебтуны и темы',
      icon: Icons.sports_kabaddi_rounded,
      aliases: ['уся', 'мурим', 'wuxia', 'murim', 'секты', 'кланы боевых искусств'],
    ),
    MangaGenre(
      id: 'leveling',
      nameRu: 'Прокачка / Развитие',
      nameEn: 'Leveling',
      category: '🔥 Вебтуны и темы',
      icon: Icons.trending_up_rounded,
      aliases: ['прокачка', 'leveling', 'поднятие уровня', 'рост сил', 'solo leveling', 'progression'],
    ),
    MangaGenre(
      id: 'dungeon',
      nameRu: 'Подземелья / Врата',
      nameEn: 'Dungeon / Gates',
      category: '🔥 Вебтуны и темы',
      icon: Icons.door_sliding_rounded,
      aliases: ['подземелье', 'подземелья', 'dungeon', 'dungeons', 'врата', 'разломы', 'порталы', 'башня', 'tower'],
    ),
    MangaGenre(
      id: 'hunters',
      nameRu: 'Охотники',
      nameEn: 'Hunters',
      category: '🔥 Вебтуны и темы',
      icon: Icons.gps_fixed_rounded,
      aliases: ['охотник', 'охотники', 'hunter', 'hunters', 'ранги sss', 'гильдия охотников'],
    ),
    MangaGenre(
      id: 'villainess',
      nameRu: 'Злодейка / Аристократия',
      nameEn: 'Villainess / Royalty',
      category: '🔥 Вебтуны и темы',
      icon: Icons.diamond_outlined,
      aliases: ['злодейка', 'villainess', 'аристократия', 'герцогиня', 'принцесса', 'дворянство', 'роялти', 'royalty'],
    ),
    MangaGenre(
      id: 'games',
      nameRu: 'Игры / VR',
      nameEn: 'Video Games / VR',
      category: '🔥 Вебтуны и темы',
      icon: Icons.sports_esports_rounded,
      aliases: ['игры', 'виртуальная реальность', 'games', 'video games', 'vr', 'vrmmo', 'гача', 'mmo'],
    ),

    // ---------------------------------------------------------
    // ⚔️ Экшен и бой
    // ---------------------------------------------------------
    MangaGenre(
      id: '391b0423-d847-456f-aff0-8b0cfc03066b', // MangaDex Action UUID
      nameRu: 'Экшен / Боевик',
      nameEn: 'Action',
      category: '⚔️ Экшен и бой',
      icon: Icons.flash_on_rounded,
      aliases: ['экшен', 'action', 'боевик', 'битва', 'сражения'],
    ),
    MangaGenre(
      id: '87cc87cd-a395-47af-b27a-93258283bbc6', // MangaDex Adventure UUID
      nameRu: 'Приключения',
      nameEn: 'Adventure',
      category: '⚔️ Экшен и бой',
      icon: Icons.explore_rounded,
      aliases: ['приключения', 'adventure', 'путешествия'],
    ),
    MangaGenre(
      id: '070645bf-e12a-4d39-a15d-5b140645672d', // MangaDex Martial Arts UUID
      nameRu: 'Боевые искусства',
      nameEn: 'Martial Arts',
      category: '⚔️ Экшен и бой',
      icon: Icons.sports_mma_rounded,
      aliases: ['боевые искусства', 'martial arts', 'единоборства', 'кунг-фу', 'карате'],
    ),
    MangaGenre(
      id: 'magic',
      nameRu: 'Магия / Волшебство',
      nameEn: 'Magic',
      category: '⚔️ Экшен и бой',
      icon: Icons.auto_awesome_rounded,
      aliases: ['магия', 'magic', 'волшебство', 'заклинания', 'маги'],
    ),
    MangaGenre(
      id: 'superpowers',
      nameRu: 'Сверхспособности',
      nameEn: 'Superpowers',
      category: '⚔️ Экшен и бой',
      icon: Icons.bolt_rounded,
      aliases: ['сверхспособности', 'суперсилы', 'superpowers', 'супергерои', 'superhero'],
    ),
    MangaGenre(
      id: 'survival',
      nameRu: 'Выживание',
      nameEn: 'Survival',
      category: '⚔️ Экшен и бой',
      icon: Icons.healing_rounded,
      aliases: ['выживание', 'survival', 'борьба за жизнь'],
    ),
    MangaGenre(
      id: 'military',
      nameRu: 'Военное / Армия',
      nameEn: 'Military',
      category: '⚔️ Экшен и бой',
      icon: Icons.shield_rounded,
      aliases: ['военное', 'military', 'война', 'армия', 'солдаты', 'битвы армий'],
    ),
    MangaGenre(
      id: 'samurai',
      nameRu: 'Самураи / Мечи',
      nameEn: 'Samurai',
      category: '⚔️ Экшен и бой',
      icon: Icons.colorize_rounded,
      aliases: ['самураи', 'самурай', 'samurai', 'меч', 'фехтование', 'катана', 'рыцари'],
    ),

    // ---------------------------------------------------------
    // 🔮 Фэнтези и мистика
    // ---------------------------------------------------------
    MangaGenre(
      id: 'cdc58593-ada3-4f5c-8429-b24baece269c', // MangaDex Fantasy UUID
      nameRu: 'Фэнтези',
      nameEn: 'Fantasy',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.castle_rounded,
      aliases: ['фэнтези', 'fantasy', 'средневековье'],
    ),
    MangaGenre(
      id: 'dark-fantasy',
      nameRu: 'Тёмное фэнтези',
      nameEn: 'Dark Fantasy',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.nightlight_round,
      aliases: ['темное фэнтези', 'тёмное фэнтези', 'dark fantasy', 'мрачное фэнтези'],
    ),
    MangaGenre(
      id: 'eabc5b4c-6aff-42f3-b657-3e190adc48b6', // MangaDex Supernatural UUID
      nameRu: 'Сверхъестественное',
      nameEn: 'Supernatural',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.blur_on_rounded,
      aliases: ['сверхъестественное', 'supernatural', 'паранормальное'],
    ),
    MangaGenre(
      id: 'ee968100-4191-4968-93d3-f82d72be7e46', // MangaDex Mystery UUID
      nameRu: 'Мистика / Тайна',
      nameEn: 'Mystery',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.visibility_rounded,
      aliases: ['мистика', 'mystery', 'тайна', 'загадка'],
    ),
    MangaGenre(
      id: 'detective',
      nameRu: 'Детектив',
      nameEn: 'Detective',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.search_rounded,
      aliases: ['детектив', 'detective', 'расследование', 'следствие'],
    ),
    MangaGenre(
      id: 'demons',
      nameRu: 'Демоны / Монстры',
      nameEn: 'Demons & Monsters',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.pest_control_rodent_rounded,
      aliases: ['демоны', 'демон', 'demons', 'монстры', 'monsters', 'чудовища', 'духи', 'нечисть'],
    ),
    MangaGenre(
      id: 'vampires',
      nameRu: 'Вампиры',
      nameEn: 'Vampires',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.bloodtype_rounded,
      aliases: ['вампиры', 'вампир', 'vampires', 'кровопийцы'],
    ),
    MangaGenre(
      id: 'gods',
      nameRu: 'Боги / Мифология',
      nameEn: 'Mythology & Gods',
      category: '🔮 Фэнтези и мистика',
      icon: Icons.wb_sunny_rounded,
      aliases: ['боги', 'божества', 'мифология', 'mythology', 'gods', 'небожители'],
    ),

    // ---------------------------------------------------------
    // 🎭 Драма, эмоции и юмор
    // ---------------------------------------------------------
    MangaGenre(
      id: '4d32cc48-9f00-4cca-9b5a-a839f0764984', // MangaDex Comedy UUID
      nameRu: 'Комедия',
      nameEn: 'Comedy',
      category: '🎭 Драма и эмоции',
      icon: Icons.sentiment_very_satisfied_rounded,
      aliases: ['комедия', 'comedy', 'юмор', 'смешно', 'пародия', 'parody'],
    ),
    MangaGenre(
      id: 'b9af3a63-f058-46de-a9a0-e0c13906197a', // MangaDex Drama UUID
      nameRu: 'Драма',
      nameEn: 'Drama',
      category: '🎭 Драма и эмоции',
      icon: Icons.theater_comedy_rounded,
      aliases: ['драма', 'drama', 'переживания'],
    ),
    MangaGenre(
      id: 'tragedy',
      nameRu: 'Трагедия',
      nameEn: 'Tragedy',
      category: '🎭 Драма и эмоции',
      icon: Icons.sentiment_very_dissatisfied_rounded,
      aliases: ['трагедия', 'tragedy', 'стекло', 'боль'],
    ),
    MangaGenre(
      id: 'e5301a23-ebd9-49dd-a0cb-2add944c7fe9', // MangaDex Slice of Life UUID
      nameRu: 'Повседневность',
      nameEn: 'Slice of Life',
      category: '🎭 Драма и эмоции',
      icon: Icons.coffee_rounded,
      aliases: ['повседневность', 'slice of life', 'быт', 'жизнь'],
    ),
    MangaGenre(
      id: '3b60b75c-a2d7-4860-ab56-05f391bb889c', // MangaDex Psychological UUID
      nameRu: 'Психология',
      nameEn: 'Psychological',
      category: '🎭 Драма и эмоции',
      icon: Icons.psychology_rounded,
      aliases: ['психология', 'psychological', 'игры разума', 'психологическое'],
    ),
    MangaGenre(
      id: '070645bf-e12a-4d39-a15d-5b140645673e', // MangaDex Thriller UUID
      nameRu: 'Триллер',
      nameEn: 'Thriller',
      category: '🎭 Драма и эмоции',
      icon: Icons.speed_rounded,
      aliases: ['триллер', 'thriller', 'напряжение', 'саспенс'],
    ),
    MangaGenre(
      id: 'cdad7e68-07dd-491d-b02f-b467ecb5710f', // MangaDex Horror UUID
      nameRu: 'Ужасы / Хоррор',
      nameEn: 'Horror',
      category: '🎭 Драма и эмоции',
      icon: Icons.warning_amber_rounded,
      aliases: ['ужасы', 'horror', 'хоррор', 'страх', 'кошмар'],
    ),
    MangaGenre(
      id: 'school',
      nameRu: 'Школа',
      nameEn: 'School',
      category: '🎭 Драма и эмоции',
      icon: Icons.school_rounded,
      aliases: ['школа', 'school', 'школьная жизнь', 'студенты', 'академия', 'academy'],
    ),

    // ---------------------------------------------------------
    // ❤️ Романтика и сёдзе
    // ---------------------------------------------------------
    MangaGenre(
      id: '423e2eae-a7a2-4a8b-ac03-a8351462d71d', // MangaDex Romance UUID
      nameRu: 'Романтика',
      nameEn: 'Romance',
      category: '❤️ Романтика и сёдзе',
      icon: Icons.favorite_rounded,
      aliases: ['романтика', 'romance', 'любовь', 'отношения'],
    ),
    MangaGenre(
      id: 'harem',
      nameRu: 'Гарем',
      nameEn: 'Harem',
      category: '❤️ Романтика и сёдзе',
      icon: Icons.group_add_rounded,
      aliases: ['гарем', 'harem', 'много девушек', 'много парней'],
    ),
    MangaGenre(
      id: 'shojo',
      nameRu: 'Сёдзё',
      nameEn: 'Shojo',
      category: '❤️ Романтика и сёдзе',
      icon: Icons.spa_rounded,
      aliases: ['сёдзё', 'седзе', 'shoujo', 'shojo', 'для девушек'],
    ),
    MangaGenre(
      id: 'josei',
      nameRu: 'Дзёсэй',
      nameEn: 'Josei',
      category: '❤️ Романтика и сёдзе',
      icon: Icons.woman_rounded,
      aliases: ['дзёсэй', 'джосей', 'josei', 'взрослая романтика'],
    ),
    MangaGenre(
      id: 'office',
      nameRu: 'Офис / Бизнес',
      nameEn: 'Office / Business',
      category: '❤️ Романтика и сёдзе',
      icon: Icons.business_center_rounded,
      aliases: ['офис', 'бизнес', 'business', 'служебный роман', 'корпорация'],
    ),

    // ---------------------------------------------------------
    // 🚀 Фантастика и сеттинг
    // ---------------------------------------------------------
    MangaGenre(
      id: '256c8bd9-4904-432d-8b4f-182188d169b1', // MangaDex Sci-Fi UUID
      nameRu: 'Научная фантастика',
      nameEn: 'Sci-Fi',
      category: '🚀 Фантастика и сеттинг',
      icon: Icons.rocket_launch_rounded,
      aliases: ['научная фантастика', 'sci-fi', 'scifi', 'фантастика', 'технологии будущего'],
    ),
    MangaGenre(
      id: 'cyberpunk',
      nameRu: 'Киберпанк',
      nameEn: 'Cyberpunk',
      category: '🚀 Фантастика и сеттинг',
      icon: Icons.memory_rounded,
      aliases: ['киберпанк', 'cyberpunk', 'высокие технологии', 'импланты'],
    ),
    MangaGenre(
      id: 'post-apocalypse',
      nameRu: 'Постапокалипсис',
      nameEn: 'Post-Apocalypse',
      category: '🚀 Фантастика и сеттинг',
      icon: Icons.terrain_rounded,
      aliases: ['постапокалипсис', 'post-apocalyptic', 'апокалипсис', 'пустоши', 'конец света'],
    ),
    MangaGenre(
      id: 'mecha',
      nameRu: 'Меха / Роботы',
      nameEn: 'Mecha',
      category: '🚀 Фантастика и сеттинг',
      icon: Icons.smart_toy_rounded,
      aliases: ['меха', 'mecha', 'роботы', 'пилотируемые роботы'],
    ),
    MangaGenre(
      id: 'space',
      nameRu: 'Космос',
      nameEn: 'Space',
      category: '🚀 Фантастика и сеттинг',
      icon: Icons.public_rounded,
      aliases: ['космос', 'space', 'космическая опера', 'галактика'],
    ),
    MangaGenre(
      id: 'historical',
      nameRu: 'Исторический',
      nameEn: 'Historical',
      category: '🚀 Фантастика и сеттинг',
      icon: Icons.account_balance_rounded,
      aliases: ['исторический', 'история', 'historical', 'древний мир', 'эпоха'],
    ),

    // ---------------------------------------------------------
    // 🎯 Форматы и увлечения
    // ---------------------------------------------------------
    MangaGenre(
      id: 'shonen',
      nameRu: 'Сёнэн',
      nameEn: 'Shounen',
      category: '🎯 Форматы и увлечения',
      icon: Icons.whatshot_rounded,
      aliases: ['сёнэн', 'сенен', 'shounen', 'shonen', 'для парней'],
    ),
    MangaGenre(
      id: 'seinen',
      nameRu: 'Сэйнэн',
      nameEn: 'Seinen',
      category: '🎯 Форматы и увлечения',
      icon: Icons.person_rounded,
      aliases: ['сэйнэн', 'сейнен', 'seinen', 'для взрослых мужчин'],
    ),
    MangaGenre(
      id: 'sports',
      nameRu: 'Спорт',
      nameEn: 'Sports',
      category: '🎯 Форматы и увлечения',
      icon: Icons.sports_soccer_rounded,
      aliases: ['спорт', 'sports', 'футбол', 'баскетбол', 'волейбол', 'соревнования'],
    ),
    MangaGenre(
      id: 'cooking',
      nameRu: 'Кулинария',
      nameEn: 'Cooking',
      category: '🎯 Форматы и увлечения',
      icon: Icons.restaurant_rounded,
      aliases: ['кулинария', 'cooking', 'еда', 'готовка', 'гурман'],
    ),
    MangaGenre(
      id: 'medical',
      nameRu: 'Медицина',
      nameEn: 'Medical',
      category: '🎯 Форматы и увлечения',
      icon: Icons.medical_services_rounded,
      aliases: ['медицина', 'medical', 'врачи', 'доктор', 'хирургия'],
    ),
    MangaGenre(
      id: 'ecchi',
      nameRu: 'Этти',
      nameEn: 'Ecchi',
      category: '🎯 Форматы и увлечения',
      icon: Icons.visibility_off_rounded,
      aliases: ['этти', 'ecchi', 'фансервис'],
    ),
  ];
}
