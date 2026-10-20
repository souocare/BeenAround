class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isAdmin,
  });

  final String id;
  final String username;
  final String displayName;
  final bool isAdmin;

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      isAdmin: json['is_admin'] as bool,
    );
  }
}
