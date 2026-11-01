class MangaGenre {
  final String id;
  final String nameRu;
  final String nameEn;

  const MangaGenre({
    required this.id,
    required this.nameRu,
    required this.nameEn,
  });

  static const List<MangaGenre> allGenres = [
    MangaGenre(id: '391b0423-d847-456f-aff0-8b0cfc03066b', nameRu: 'Экшен', nameEn: 'Action'),
    MangaGenre(id: '87cc87cd-a395-47af-b27a-93258283bbc6', nameRu: 'Приключения', nameEn: 'Adventure'),
    MangaGenre(id: '4d32cc48-9f00-4cca-9b5a-a839f0764984', nameRu: 'Комедия', nameEn: 'Comedy'),
    MangaGenre(id: 'b9af3a63-f058-46de-a9a0-e0c13906197a', nameRu: 'Драма', nameEn: 'Drama'),
    MangaGenre(id: 'cdc58593-ada3-4f5c-8429-b24baece269c', nameRu: 'Фэнтези', nameEn: 'Fantasy'),
    MangaGenre(id: 'ace04297-3a1a-4624-8149-47079e8eacab', nameRu: 'Исекай', nameEn: 'Isekai'),
    MangaGenre(id: '423e2eae-a7a2-4a8b-ac03-a8351462d71d', nameRu: 'Романтика', nameEn: 'Romance'),
    MangaGenre(id: 'e5301a23-ebd9-49dd-a0cb-2add944c7fe9', nameRu: 'Повседневность', nameEn: 'Slice of Life'),
    MangaGenre(id: 'cdad7e68-07dd-491d-b02f-b467ecb5710f', nameRu: 'Ужасы', nameEn: 'Horror'),
    MangaGenre(id: '070645bf-e12a-4d39-a15d-5b140645672d', nameRu: 'Боевые искусства', nameEn: 'Martial Arts'),
    MangaGenre(id: 'ee968100-4191-4968-93d3-f82d72be7e46', nameRu: 'Тайна / Детектив', nameEn: 'Mystery'),
    MangaGenre(id: '3b60b75c-a2d7-4860-ab56-05f391bb889c', nameRu: 'Психология', nameEn: 'Psychological'),
    MangaGenre(id: '256c8bd9-4904-432d-8b4f-182188d169b1', nameRu: 'Фантастика', nameEn: 'Sci-Fi'),
    MangaGenre(id: 'eabc5b4c-6aff-42f3-b657-3e190adc48b6', nameRu: 'Сверхъестественное', nameEn: 'Supernatural'),
    MangaGenre(id: '070645bf-e12a-4d39-a15d-5b140645673e', nameRu: 'Триллер', nameEn: 'Thriller'),
  ];
}
