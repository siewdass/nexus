// This is a generated file - do not edit.
//
// Generated from nexus.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class MessageRequest extends $pb.GeneratedMessage {
  factory MessageRequest({
    $core.String? sessionId,
    $core.String? message,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (message != null) result.message = message;
    return result;
  }

  MessageRequest._();

  factory MessageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nexus'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageRequest copyWith(void Function(MessageRequest) updates) =>
      super.copyWith((message) => updates(message as MessageRequest))
          as MessageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageRequest create() => MessageRequest._();
  @$core.override
  MessageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageRequest>(create);
  static MessageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

enum MessageResponse_Payload { think, reply, done, error, notSet }

class MessageResponse extends $pb.GeneratedMessage {
  factory MessageResponse({
    $core.String? sessionId,
    $core.String? think,
    $core.String? reply,
    $core.bool? done,
    $core.String? error,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (think != null) result.think = think;
    if (reply != null) result.reply = reply;
    if (done != null) result.done = done;
    if (error != null) result.error = error;
    return result;
  }

  MessageResponse._();

  factory MessageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, MessageResponse_Payload>
      _MessageResponse_PayloadByTag = {
    2: MessageResponse_Payload.think,
    3: MessageResponse_Payload.reply,
    4: MessageResponse_Payload.done,
    5: MessageResponse_Payload.error,
    0: MessageResponse_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nexus'),
      createEmptyInstance: create)
    ..oo(0, [2, 3, 4, 5])
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'think')
    ..aOS(3, _omitFieldNames ? '' : 'reply')
    ..aOB(4, _omitFieldNames ? '' : 'done')
    ..aOS(5, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageResponse copyWith(void Function(MessageResponse) updates) =>
      super.copyWith((message) => updates(message as MessageResponse))
          as MessageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageResponse create() => MessageResponse._();
  @$core.override
  MessageResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageResponse>(create);
  static MessageResponse? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  MessageResponse_Payload whichPayload() =>
      _MessageResponse_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get think => $_getSZ(1);
  @$pb.TagNumber(2)
  set think($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasThink() => $_has(1);
  @$pb.TagNumber(2)
  void clearThink() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reply => $_getSZ(2);
  @$pb.TagNumber(3)
  set reply($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReply() => $_has(2);
  @$pb.TagNumber(3)
  void clearReply() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get done => $_getBF(3);
  @$pb.TagNumber(4)
  set done($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDone() => $_has(3);
  @$pb.TagNumber(4)
  void clearDone() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get error => $_getSZ(4);
  @$pb.TagNumber(5)
  set error($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
}

class SettingsFetchRequest extends $pb.GeneratedMessage {
  factory SettingsFetchRequest() => create();

  SettingsFetchRequest._();

  factory SettingsFetchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettingsFetchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettingsFetchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nexus'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsFetchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsFetchRequest copyWith(void Function(SettingsFetchRequest) updates) =>
      super.copyWith((message) => updates(message as SettingsFetchRequest))
          as SettingsFetchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettingsFetchRequest create() => SettingsFetchRequest._();
  @$core.override
  SettingsFetchRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettingsFetchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettingsFetchRequest>(create);
  static SettingsFetchRequest? _defaultInstance;
}

class SettingsPayload extends $pb.GeneratedMessage {
  factory SettingsPayload({
    $core.bool? tunnel,
  }) {
    final result = create();
    if (tunnel != null) result.tunnel = tunnel;
    return result;
  }

  SettingsPayload._();

  factory SettingsPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettingsPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettingsPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nexus'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'tunnel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsPayload copyWith(void Function(SettingsPayload) updates) =>
      super.copyWith((message) => updates(message as SettingsPayload))
          as SettingsPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettingsPayload create() => SettingsPayload._();
  @$core.override
  SettingsPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettingsPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettingsPayload>(create);
  static SettingsPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get tunnel => $_getBF(0);
  @$pb.TagNumber(1)
  set tunnel($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTunnel() => $_has(0);
  @$pb.TagNumber(1)
  void clearTunnel() => $_clearField(1);
}

class SettingsPatchResponse extends $pb.GeneratedMessage {
  factory SettingsPatchResponse({
    $core.bool? success,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (error != null) result.error = error;
    return result;
  }

  SettingsPatchResponse._();

  factory SettingsPatchResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SettingsPatchResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SettingsPatchResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nexus'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsPatchResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SettingsPatchResponse copyWith(
          void Function(SettingsPatchResponse) updates) =>
      super.copyWith((message) => updates(message as SettingsPatchResponse))
          as SettingsPatchResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SettingsPatchResponse create() => SettingsPatchResponse._();
  @$core.override
  SettingsPatchResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SettingsPatchResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SettingsPatchResponse>(create);
  static SettingsPatchResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
