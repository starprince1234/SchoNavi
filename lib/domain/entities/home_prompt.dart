/// A suggested prompt shown on the home screen bento grid.
class HomePrompt {
  const HomePrompt({required this.text});

  final String text;

  factory HomePrompt.fromJson(Map<String, dynamic> json) {
    return HomePrompt(text: json['text'] as String);
  }

  Map<String, dynamic> toJson() => {'text': text};
}
