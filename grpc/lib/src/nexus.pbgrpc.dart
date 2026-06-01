// This is a generated file - do not edit.
//
// Generated from nexus.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'nexus.pb.dart' as $0;

export 'nexus.pb.dart';

@$pb.GrpcServiceName('nexus.NexusService')
class NexusServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  NexusServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.MessageResponse> message(
    $0.MessageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(
        _$message, $async.Stream.fromIterable([request]),
        options: options);
  }

  $grpc.ResponseFuture<$0.SettingsPayload> settingsFetch(
    $0.SettingsFetchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$settingsFetch, request, options: options);
  }

  $grpc.ResponseFuture<$0.SettingsPatchResponse> settingsPatch(
    $0.SettingsPayload request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$settingsPatch, request, options: options);
  }

  // method descriptors

  static final _$message =
      $grpc.ClientMethod<$0.MessageRequest, $0.MessageResponse>(
          '/nexus.NexusService/Message',
          ($0.MessageRequest value) => value.writeToBuffer(),
          $0.MessageResponse.fromBuffer);
  static final _$settingsFetch =
      $grpc.ClientMethod<$0.SettingsFetchRequest, $0.SettingsPayload>(
          '/nexus.NexusService/SettingsFetch',
          ($0.SettingsFetchRequest value) => value.writeToBuffer(),
          $0.SettingsPayload.fromBuffer);
  static final _$settingsPatch =
      $grpc.ClientMethod<$0.SettingsPayload, $0.SettingsPatchResponse>(
          '/nexus.NexusService/SettingsPatch',
          ($0.SettingsPayload value) => value.writeToBuffer(),
          $0.SettingsPatchResponse.fromBuffer);
}

@$pb.GrpcServiceName('nexus.NexusService')
abstract class NexusServiceBase extends $grpc.Service {
  $core.String get $name => 'nexus.NexusService';

  NexusServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.MessageRequest, $0.MessageResponse>(
        'Message',
        message_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.MessageRequest.fromBuffer(value),
        ($0.MessageResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SettingsFetchRequest, $0.SettingsPayload>(
        'SettingsFetch',
        settingsFetch_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SettingsFetchRequest.fromBuffer(value),
        ($0.SettingsPayload value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SettingsPayload, $0.SettingsPatchResponse>(
            'SettingsPatch',
            settingsPatch_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SettingsPayload.fromBuffer(value),
            ($0.SettingsPatchResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.MessageResponse> message_Pre($grpc.ServiceCall $call,
      $async.Future<$0.MessageRequest> $request) async* {
    yield* message($call, await $request);
  }

  $async.Stream<$0.MessageResponse> message(
      $grpc.ServiceCall call, $0.MessageRequest request);

  $async.Future<$0.SettingsPayload> settingsFetch_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SettingsFetchRequest> $request) async {
    return settingsFetch($call, await $request);
  }

  $async.Future<$0.SettingsPayload> settingsFetch(
      $grpc.ServiceCall call, $0.SettingsFetchRequest request);

  $async.Future<$0.SettingsPatchResponse> settingsPatch_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SettingsPayload> $request) async {
    return settingsPatch($call, await $request);
  }

  $async.Future<$0.SettingsPatchResponse> settingsPatch(
      $grpc.ServiceCall call, $0.SettingsPayload request);
}
