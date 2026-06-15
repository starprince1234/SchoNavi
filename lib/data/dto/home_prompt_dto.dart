import '../../domain/entities/home_prompt.dart';

class HomePromptDto {
  const HomePromptDto({required this.text});

  final String text;

  factory HomePromptDto.fromJson(Map<String, dynamic> json) {
    return HomePromptDto(text: json['text'] as String);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'text': text};

  HomePrompt toEntity() => HomePrompt(text: text);
}

