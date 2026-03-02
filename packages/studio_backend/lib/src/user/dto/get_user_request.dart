import 'package:json_annotation/json_annotation.dart';
part 'get_user_request.g.dart';

@JsonSerializable()
class GetUserRequest {
  GetUserRequest({required this.userId});
  factory GetUserRequest.fromJson(Map<String, dynamic> json) =>
      _$GetUserRequestFromJson(json);
  final String userId;

  Map<String, dynamic> toJson() => _$GetUserRequestToJson(this);
}
