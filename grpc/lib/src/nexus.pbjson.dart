// This is a generated file - do not edit.
//
// Generated from nexus.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use messageRequestDescriptor instead')
const MessageRequest$json = {
  '1': 'MessageRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `MessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageRequestDescriptor = $convert.base64Decode(
    'Cg5NZXNzYWdlUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSGAoHbWVzc2'
    'FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use messageResponseDescriptor instead')
const MessageResponse$json = {
  '1': 'MessageResponse',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'think', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'think'},
    {'1': 'reply', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'reply'},
    {'1': 'done', '3': 4, '4': 1, '5': 8, '9': 0, '10': 'done'},
    {'1': 'error', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'error'},
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `MessageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageResponseDescriptor = $convert.base64Decode(
    'Cg9NZXNzYWdlUmVzcG9uc2USHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhYKBXRoaW'
    '5rGAIgASgJSABSBXRoaW5rEhYKBXJlcGx5GAMgASgJSABSBXJlcGx5EhQKBGRvbmUYBCABKAhI'
    'AFIEZG9uZRIWCgVlcnJvchgFIAEoCUgAUgVlcnJvckIJCgdwYXlsb2Fk');

@$core.Deprecated('Use settingsFetchRequestDescriptor instead')
const SettingsFetchRequest$json = {
  '1': 'SettingsFetchRequest',
};

/// Descriptor for `SettingsFetchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsFetchRequestDescriptor =
    $convert.base64Decode('ChRTZXR0aW5nc0ZldGNoUmVxdWVzdA==');

@$core.Deprecated('Use settingsPayloadDescriptor instead')
const SettingsPayload$json = {
  '1': 'SettingsPayload',
  '2': [
    {'1': 'tunnel', '3': 1, '4': 1, '5': 8, '10': 'tunnel'},
  ],
};

/// Descriptor for `SettingsPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsPayloadDescriptor = $convert
    .base64Decode('Cg9TZXR0aW5nc1BheWxvYWQSFgoGdHVubmVsGAEgASgIUgZ0dW5uZWw=');

@$core.Deprecated('Use settingsPatchResponseDescriptor instead')
const SettingsPatchResponse$json = {
  '1': 'SettingsPatchResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `SettingsPatchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsPatchResponseDescriptor = $convert.base64Decode(
    'ChVTZXR0aW5nc1BhdGNoUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIUCgVlcn'
    'JvchgCIAEoCVIFZXJyb3I=');
