// This is a generated file - do not edit.
//
// Generated from jarvis.proto.

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

import 'jarvis.pb.dart' as $0;

export 'jarvis.pb.dart';

@$pb.GrpcServiceName('jarvis.JarvisService')
class JarvisServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  JarvisServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseStream<$0.ChatResponse> chat(
    $0.ChatRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$chat, $async.Stream.fromIterable([request]),
        options: options);
  }

  // method descriptors

  static final _$chat = $grpc.ClientMethod<$0.ChatRequest, $0.ChatResponse>(
      '/jarvis.JarvisService/Chat',
      ($0.ChatRequest value) => value.writeToBuffer(),
      $0.ChatResponse.fromBuffer);
}

@$pb.GrpcServiceName('jarvis.JarvisService')
abstract class JarvisServiceBase extends $grpc.Service {
  $core.String get $name => 'jarvis.JarvisService';

  JarvisServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ChatRequest, $0.ChatResponse>(
        'Chat',
        chat_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.ChatRequest.fromBuffer(value),
        ($0.ChatResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.ChatResponse> chat_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ChatRequest> $request) async* {
    yield* chat($call, await $request);
  }

  $async.Stream<$0.ChatResponse> chat(
      $grpc.ServiceCall call, $0.ChatRequest request);
}
