import 'package:googleapis/identitytoolkit/v1.dart';

class User {
  User({required this.uid, required this.displayName, required this.createdAt});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String uid;
  final String? displayName;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,

      'createdAt': createdAt.toIso8601String(),
    };
  }
}

User userMapper(GoogleCloudIdentitytoolkitV1UserInfo user) {
  return User(
    uid: user.localId!,
    displayName: user.displayName,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      int.parse(user.createdAt ?? '0'),
    ),
  );
}
