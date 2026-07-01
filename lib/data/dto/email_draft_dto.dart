import '../../domain/entities/email_draft.dart';

class EmailDraftDto {
  const EmailDraftDto({required this.subject, required this.body});

  final String subject;
  final String body;

  factory EmailDraftDto.fromJson(Map<String, dynamic> json) {
    return EmailDraftDto(
      subject: json['subject'] as String,
      body: json['body'] as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'subject': subject,
    'body': body,
  };

  EmailDraft toEntity() => EmailDraft(subject: subject, body: body);
}
