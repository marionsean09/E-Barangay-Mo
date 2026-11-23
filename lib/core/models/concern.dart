class Concern {
  const Concern({required this.id, required this.createdAt, required this.data});

  final int id;
  final String? createdAt;

  /// Raw fields from the API: type, title, status, requestedDate,
  /// validIdFront (attachment id), evidence (attachment ids), requester, ...
  final Map<String, dynamic> data;

  factory Concern.fromJson(Map<String, dynamic> json) => Concern(
        id: json['id'] as int,
        createdAt: json['createdAt'] as String?,
        data: json,
      );
}
