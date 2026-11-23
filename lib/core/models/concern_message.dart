class ConcernMessage {
  const ConcernMessage({
    required this.id,
    required this.body,
    required this.senderName,
    required this.isMine,
    required this.createdAt,
  });

  final int id;
  final String body;
  final String senderName;
  final bool isMine;
  final String? createdAt;

  factory ConcernMessage.fromJson(Map<String, dynamic> json) => ConcernMessage(
        id: json['id'] as int,
        body: json['body'] as String,
        senderName: json['senderName'] as String,
        isMine: json['isMine'] as bool,
        createdAt: json['createdAt'] as String?,
      );
}
