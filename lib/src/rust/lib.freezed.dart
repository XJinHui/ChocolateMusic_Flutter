// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lib.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Error {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Error()';
}


}

/// @nodoc
class $ErrorCopyWith<$Res>  {
$ErrorCopyWith(Error _, $Res Function(Error) __);
}


/// Adds pattern-matching-related methods to [Error].
extension ErrorPatterns on Error {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( Error_Api value)?  api,TResult Function( Error_Http value)?  http,TResult Function( Error_Json value)?  json,TResult Function( Error_Crypto value)?  crypto,TResult Function( Error_Io value)?  io,TResult Function( Error_Invalid value)?  invalid,TResult Function( Error_NotLoggedIn value)?  notLoggedIn,required TResult orElse(),}){
final _that = this;
switch (_that) {
case Error_Api() when api != null:
return api(_that);case Error_Http() when http != null:
return http(_that);case Error_Json() when json != null:
return json(_that);case Error_Crypto() when crypto != null:
return crypto(_that);case Error_Io() when io != null:
return io(_that);case Error_Invalid() when invalid != null:
return invalid(_that);case Error_NotLoggedIn() when notLoggedIn != null:
return notLoggedIn(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( Error_Api value)  api,required TResult Function( Error_Http value)  http,required TResult Function( Error_Json value)  json,required TResult Function( Error_Crypto value)  crypto,required TResult Function( Error_Io value)  io,required TResult Function( Error_Invalid value)  invalid,required TResult Function( Error_NotLoggedIn value)  notLoggedIn,}){
final _that = this;
switch (_that) {
case Error_Api():
return api(_that);case Error_Http():
return http(_that);case Error_Json():
return json(_that);case Error_Crypto():
return crypto(_that);case Error_Io():
return io(_that);case Error_Invalid():
return invalid(_that);case Error_NotLoggedIn():
return notLoggedIn(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( Error_Api value)?  api,TResult? Function( Error_Http value)?  http,TResult? Function( Error_Json value)?  json,TResult? Function( Error_Crypto value)?  crypto,TResult? Function( Error_Io value)?  io,TResult? Function( Error_Invalid value)?  invalid,TResult? Function( Error_NotLoggedIn value)?  notLoggedIn,}){
final _that = this;
switch (_that) {
case Error_Api() when api != null:
return api(_that);case Error_Http() when http != null:
return http(_that);case Error_Json() when json != null:
return json(_that);case Error_Crypto() when crypto != null:
return crypto(_that);case Error_Io() when io != null:
return io(_that);case Error_Invalid() when invalid != null:
return invalid(_that);case Error_NotLoggedIn() when notLoggedIn != null:
return notLoggedIn(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String message,  PlatformInt64? code,  int status,  String body)?  api,TResult Function( String field0)?  http,TResult Function( String field0)?  json,TResult Function( String field0)?  crypto,TResult Function( String field0)?  io,TResult Function( String field0)?  invalid,TResult Function()?  notLoggedIn,required TResult orElse(),}) {final _that = this;
switch (_that) {
case Error_Api() when api != null:
return api(_that.message,_that.code,_that.status,_that.body);case Error_Http() when http != null:
return http(_that.field0);case Error_Json() when json != null:
return json(_that.field0);case Error_Crypto() when crypto != null:
return crypto(_that.field0);case Error_Io() when io != null:
return io(_that.field0);case Error_Invalid() when invalid != null:
return invalid(_that.field0);case Error_NotLoggedIn() when notLoggedIn != null:
return notLoggedIn();case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String message,  PlatformInt64? code,  int status,  String body)  api,required TResult Function( String field0)  http,required TResult Function( String field0)  json,required TResult Function( String field0)  crypto,required TResult Function( String field0)  io,required TResult Function( String field0)  invalid,required TResult Function()  notLoggedIn,}) {final _that = this;
switch (_that) {
case Error_Api():
return api(_that.message,_that.code,_that.status,_that.body);case Error_Http():
return http(_that.field0);case Error_Json():
return json(_that.field0);case Error_Crypto():
return crypto(_that.field0);case Error_Io():
return io(_that.field0);case Error_Invalid():
return invalid(_that.field0);case Error_NotLoggedIn():
return notLoggedIn();}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String message,  PlatformInt64? code,  int status,  String body)?  api,TResult? Function( String field0)?  http,TResult? Function( String field0)?  json,TResult? Function( String field0)?  crypto,TResult? Function( String field0)?  io,TResult? Function( String field0)?  invalid,TResult? Function()?  notLoggedIn,}) {final _that = this;
switch (_that) {
case Error_Api() when api != null:
return api(_that.message,_that.code,_that.status,_that.body);case Error_Http() when http != null:
return http(_that.field0);case Error_Json() when json != null:
return json(_that.field0);case Error_Crypto() when crypto != null:
return crypto(_that.field0);case Error_Io() when io != null:
return io(_that.field0);case Error_Invalid() when invalid != null:
return invalid(_that.field0);case Error_NotLoggedIn() when notLoggedIn != null:
return notLoggedIn();case _:
  return null;

}
}

}

/// @nodoc


class Error_Api extends Error {
  const Error_Api({required this.message, this.code, required this.status, required this.body}): super._();
  

/// 错误描述（`error_msg` / `msg` / `error`）
 final  String message;
/// `error_code`
 final  PlatformInt64? code;
/// 归一化后的状态码（`502` 表示上游业务失败）
 final  int status;
/// 完整响应体（JSON 文本，便于排查）
 final  String body;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Error_ApiCopyWith<Error_Api> get copyWith => _$Error_ApiCopyWithImpl<Error_Api>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error_Api&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&(identical(other.status, status) || other.status == status)&&(identical(other.body, body) || other.body == body));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,status,body);

@override
String toString() {
  return 'Error.api(message: $message, code: $code, status: $status, body: $body)';
}


}

/// @nodoc
abstract mixin class $Error_ApiCopyWith<$Res> implements $ErrorCopyWith<$Res> {
  factory $Error_ApiCopyWith(Error_Api value, $Res Function(Error_Api) _then) = _$Error_ApiCopyWithImpl;
@useResult
$Res call({
 String message, PlatformInt64? code, int status, String body
});




}
/// @nodoc
class _$Error_ApiCopyWithImpl<$Res>
    implements $Error_ApiCopyWith<$Res> {
  _$Error_ApiCopyWithImpl(this._self, this._then);

  final Error_Api _self;
  final $Res Function(Error_Api) _then;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = freezed,Object? status = null,Object? body = null,}) {
  return _then(Error_Api(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as PlatformInt64?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Error_Http extends Error {
  const Error_Http(this.field0): super._();
  

 final  String field0;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Error_HttpCopyWith<Error_Http> get copyWith => _$Error_HttpCopyWithImpl<Error_Http>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error_Http&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Error.http(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Error_HttpCopyWith<$Res> implements $ErrorCopyWith<$Res> {
  factory $Error_HttpCopyWith(Error_Http value, $Res Function(Error_Http) _then) = _$Error_HttpCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$Error_HttpCopyWithImpl<$Res>
    implements $Error_HttpCopyWith<$Res> {
  _$Error_HttpCopyWithImpl(this._self, this._then);

  final Error_Http _self;
  final $Res Function(Error_Http) _then;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Error_Http(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Error_Json extends Error {
  const Error_Json(this.field0): super._();
  

 final  String field0;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Error_JsonCopyWith<Error_Json> get copyWith => _$Error_JsonCopyWithImpl<Error_Json>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error_Json&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Error.json(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Error_JsonCopyWith<$Res> implements $ErrorCopyWith<$Res> {
  factory $Error_JsonCopyWith(Error_Json value, $Res Function(Error_Json) _then) = _$Error_JsonCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$Error_JsonCopyWithImpl<$Res>
    implements $Error_JsonCopyWith<$Res> {
  _$Error_JsonCopyWithImpl(this._self, this._then);

  final Error_Json _self;
  final $Res Function(Error_Json) _then;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Error_Json(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Error_Crypto extends Error {
  const Error_Crypto(this.field0): super._();
  

 final  String field0;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Error_CryptoCopyWith<Error_Crypto> get copyWith => _$Error_CryptoCopyWithImpl<Error_Crypto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error_Crypto&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Error.crypto(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Error_CryptoCopyWith<$Res> implements $ErrorCopyWith<$Res> {
  factory $Error_CryptoCopyWith(Error_Crypto value, $Res Function(Error_Crypto) _then) = _$Error_CryptoCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$Error_CryptoCopyWithImpl<$Res>
    implements $Error_CryptoCopyWith<$Res> {
  _$Error_CryptoCopyWithImpl(this._self, this._then);

  final Error_Crypto _self;
  final $Res Function(Error_Crypto) _then;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Error_Crypto(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Error_Io extends Error {
  const Error_Io(this.field0): super._();
  

 final  String field0;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Error_IoCopyWith<Error_Io> get copyWith => _$Error_IoCopyWithImpl<Error_Io>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error_Io&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Error.io(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Error_IoCopyWith<$Res> implements $ErrorCopyWith<$Res> {
  factory $Error_IoCopyWith(Error_Io value, $Res Function(Error_Io) _then) = _$Error_IoCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$Error_IoCopyWithImpl<$Res>
    implements $Error_IoCopyWith<$Res> {
  _$Error_IoCopyWithImpl(this._self, this._then);

  final Error_Io _self;
  final $Res Function(Error_Io) _then;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Error_Io(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Error_Invalid extends Error {
  const Error_Invalid(this.field0): super._();
  

 final  String field0;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$Error_InvalidCopyWith<Error_Invalid> get copyWith => _$Error_InvalidCopyWithImpl<Error_Invalid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error_Invalid&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'Error.invalid(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $Error_InvalidCopyWith<$Res> implements $ErrorCopyWith<$Res> {
  factory $Error_InvalidCopyWith(Error_Invalid value, $Res Function(Error_Invalid) _then) = _$Error_InvalidCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$Error_InvalidCopyWithImpl<$Res>
    implements $Error_InvalidCopyWith<$Res> {
  _$Error_InvalidCopyWithImpl(this._self, this._then);

  final Error_Invalid _self;
  final $Res Function(Error_Invalid) _then;

/// Create a copy of Error
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(Error_Invalid(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class Error_NotLoggedIn extends Error {
  const Error_NotLoggedIn(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Error_NotLoggedIn);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'Error.notLoggedIn()';
}


}




// dart format on
