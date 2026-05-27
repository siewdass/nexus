import 'package:grpc/grpc.dart';
import 'service.dart';

Future<void> main() async {
  print('Iniciando LLM engine...');
  final llm = LlmService();
  await llm.init();
  print('LLM listo.');

  final server = Server.create(
    services: [JarvisService(llm)],
  );
  await server.serve(port: 50051);
  print('Servidor gRPC en 0.0.0.0:50051');

  await Future.delayed(const Duration(days: 365));
}
