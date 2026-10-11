// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$QrStatus {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QrStatus);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QrStatus()';
}


}

/// @nodoc
class $QrStatusCopyWith<$Res>  {
$QrStatusCopyWith(QrStatus _, $Res Function(QrStatus) __);
}


/// Adds pattern-matching-related methods to [QrStatus].
extension QrStatusPatterns on QrStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( QrStatus_Expired value)?  expired,TResult Function( QrStatus_Waiting value)?  waiting,TResult Function( QrStatus_Scanned value)?  scanned,TResult Function( QrStatus_Success value)?  success,TResult Function( QrStatus_Unknown value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case QrStatus_Expired() when expired != null:
return expired(_that);case QrStatus_Waiting() when waiting != null:
return waiting(_that);case QrStatus_Scanned() when scanned != null:
return scanned(_that);case QrStatus_Success() when success != null:
return success(_that);case QrStatus_Unknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( QrStatus_Expired value)  expired,required TResult Function( QrStatus_Waiting value)  waiting,required TResult Function( QrStatus_Scanned value)  scanned,required TResult Function( QrStatus_Success value)  success,required TResult Function( QrStatus_Unknown value)  unknown,}){
final _that = this;
switch (_that) {
case QrStatus_Expired():
return expired(_that);case QrStatus_Waiting():
return waiting(_that);case QrStatus_Scanned():
return scanned(_that);case QrStatus_Success():
return success(_that);case QrStatus_Unknown():
return unknown(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( QrStatus_Expired value)?  expired,TResult? Function( QrStatus_Waiting value)?  waiting,TResult? Function( QrStatus_Scanned value)?  scanned,TResult? Function( QrStatus_Success value)?  success,TResult? Function( QrStatus_Unknown value)?  unknown,}){
final _that = this;
switch (_that) {
case QrStatus_Expired() when expired != null:
return expired(_that);case QrStatus_Waiting() when waiting != null:
return waiting(_that);case QrStatus_Scanned() when scanned != null:
return scanned(_that);case QrStatus_Success() when success != null:
return success(_that);case QrStatus_Unknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  expired,TResult Function()?  waiting,TResult Function()?  scanned,TResult Function( String token,  String userid,  String nickname,  String pic)?  success,TResult Function( PlatformInt64 field0)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case QrStatus_Expired() when expired != null:
return expired();case QrStatus_Waiting() when waiting != null:
return waiting();case QrStatus_Scanned() when scanned != null:
return scanned();case QrStatus_Success() when success != null:
return success(_that.token,_that.userid,_that.nickname,_that.pic);case QrStatus_Unknown() when unknown != null:
return unknown(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  expired,required TResult Function()  waiting,required TResult Function()  scanned,required TResult Function( String token,  String userid,  String nickname,  String pic)  success,required TResult Function( PlatformInt64 field0)  unknown,}) {final _that = this;
switch (_that) {
case QrStatus_Expired():
return expired();case QrStatus_Waiting():
return waiting();case QrStatus_Scanned():
return scanned();case QrStatus_Success():
return success(_that.token,_that.userid,_that.nickname,_that.pic);case QrStatus_Unknown():
return unknown(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  expired,TResult? Function()?  waiting,TResult? Function()?  scanned,TResult? Function( String token,  String userid,  String nickname,  String pic)?  success,TResult? Function( PlatformInt64 field0)?  unknown,}) {final _that = this;
switch (_that) {
case QrStatus_Expired() when expired != null:
return expired();case QrStatus_Waiting() when waiting != null:
return waiting();case QrStatus_Scanned() when scanned != null:
return scanned();case QrStatus_Success() when success != null:
return success(_that.token,_that.userid,_that.nickname,_that.pic);case QrStatus_Unknown() when unknown != null:
return unknown(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class QrStatus_Expired extends QrStatus {
  const QrStatus_Expired(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QrStatus_Expired);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QrStatus.expired()';
}


}




/// @nodoc


class QrStatus_Waiting extends QrStatus {
  const QrStatus_Waiting(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QrStatus_Waiting);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QrStatus.waiting()';
}


}




/// @nodoc


class QrStatus_Scanned extends QrStatus {
  const QrStatus_Scanned(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QrStatus_Scanned);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'QrStatus.scanned()';
}


}




/// @nodoc


class QrStatus_Success extends QrStatus {
  const QrStatus_Success({required this.token, required this.userid, required this.nickname, required this.pic}): super._();
  

 final  String token;
 final  String userid;
 final  String nickname;
 final  String pic;

/// Create a copy of QrStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QrStatus_SuccessCopyWith<QrStatus_Success> get copyWith => _$QrStatus_SuccessCopyWithImpl<QrStatus_Success>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QrStatus_Success&&(identical(other.token, token) || other.token == token)&&(identical(other.userid, userid) || other.userid == userid)&&(identical(other.nickname, nickname) || other.nickname == nickname)&&(identical(other.pic, pic) || other.pic == pic));
}


@override
int get hashCode => Object.hash(runtimeType,token,userid,nickname,pic);

@override
String toString() {
  return 'QrStatus.success(token: $token, userid: $userid, nickname: $nickname, pic: $pic)';
}


}

/// @nodoc
abstract mixin class $QrStatus_SuccessCopyWith<$Res> implements $QrStatusCopyWith<$Res> {
  factory $QrStatus_SuccessCopyWith(QrStatus_Success value, $Res Function(QrStatus_Success) _then) = _$QrStatus_SuccessCopyWithImpl;
@useResult
$Res call({
 String token, String userid, String nickname, String pic
});




}
/// @nodoc
class _$QrStatus_SuccessCopyWithImpl<$Res>
    implements $QrStatus_SuccessCopyWith<$Res> {
  _$QrStatus_SuccessCopyWithImpl(this._self, this._then);

  final QrStatus_Success _self;
  final $Res Function(QrStatus_Success) _then;

/// Create a copy of QrStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? token = null,Object? userid = null,Object? nickname = null,Object? pic = null,}) {
  return _then(QrStatus_Success(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,userid: null == userid ? _self.userid : userid // ignore: cast_nullable_to_non_nullable
as String,nickname: null == nickname ? _self.nickname : nickname // ignore: cast_nullable_to_non_nullable
as String,pic: null == pic ? _self.pic : pic // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class QrStatus_Unknown extends QrStatus {
  const QrStatus_Unknown(this.field0): super._();
  

 final  PlatformInt64 field0;

/// Create a copy of QrStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$QrStatus_UnknownCopyWith<QrStatus_Unknown> get copyWith => _$QrStatus_UnknownCopyWithImpl<QrStatus_Unknown>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is QrStatus_Unknown&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'QrStatus.unknown(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $QrStatus_UnknownCopyWith<$Res> implements $QrStatusCopyWith<$Res> {
  factory $QrStatus_UnknownCopyWith(QrStatus_Unknown value, $Res Function(QrStatus_Unknown) _then) = _$QrStatus_UnknownCopyWithImpl;
@useResult
$Res call({
 PlatformInt64 field0
});




}
/// @nodoc
class _$QrStatus_UnknownCopyWithImpl<$Res>
    implements $QrStatus_UnknownCopyWith<$Res> {
  _$QrStatus_UnknownCopyWithImpl(this._self, this._then);

  final QrStatus_Unknown _self;
  final $Res Function(QrStatus_Unknown) _then;

/// Create a copy of QrStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(QrStatus_Unknown(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as PlatformInt64,
  ));
}


}

// dart format on
