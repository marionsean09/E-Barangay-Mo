class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? createdAt;

  // Only decides which screen to show. The server enforces the role on
  // every admin endpoint, so changing this on the client grants nothing.
  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'resident',
        createdAt: json['createdAt'] as String?,
      );
}
