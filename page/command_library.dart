class CommandLibrary {
  final int id;
  final String title;
  final String author;
  final String urlImage;

  const CommandLibrary({
    required this.id,
    required this.author,
    required this.title,
    required this.urlImage,
  });

  factory CommandLibrary.fromJson(Map<String, dynamic> json) => CommandLibrary(
    id: json['id'],
    author: json['author'],
    title: json['title'],
    urlImage: json['urlImage'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'urlImage': urlImage,
  };
}