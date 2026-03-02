import 'package:json_annotation/json_annotation.dart';
part 'get_user_response.g.dart';

@JsonSerializable()
class GetUserResponse {
  GetUserResponse({
    required this.userId,
    required this.displayName,
    required this.isVerified,
  });
  factory GetUserResponse.fromJson(Map<String, dynamic> json) =>
      _$GetUserResponseFromJson(json);
  final String userId;
  final String displayName;
  final bool isVerified;

  Map<String, dynamic> toJson() => _$GetUserResponseToJson(this);
}
