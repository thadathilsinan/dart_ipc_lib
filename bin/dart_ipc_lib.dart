import 'dart:async';
import 'dart:io';

import 'package:dart_ipc_lib/ipc_client.dart';
import 'package:dart_ipc_lib/ipc_server.dart';
import 'package:dart_ipc_lib/utils/logger.dart';

void main() async {
  final socketFilePath = '~/.dart_ipc.sock';

  print('Enter your program type [client/server]: ');
  final String choice = stdin.readLineSync()!;

  if (choice == 'client') {
    print('Running as client...');

    final client = IPCClient(
      serverSocketFilePath: socketFilePath,
      onBroadcastMessageRecievedCallback: (msg) {
        Logger.log('Broadcast message received: $msg');
      },
    );

    /// Send a message to the server
    while (true) {
      print('Enter your message: ');
      final message = stdin.readLineSync()!;

      if (message.isEmpty) {
        Logger.log('Empty message. Exiting client program...');
        break;
      }

      final response = await client.sendMessage(message);
      Logger.log('Response received: $response');
    }
  } else if (choice == 'server') {
    print('Running as server...');

    final server = IPCServer(
      socketFilePath: socketFilePath,
      onRequestCallback: (req) async {
        Logger.log('Request received: $req');

        return 'Response with time ${DateTime.now().millisecond}';
      },
    );

    /// Send a broadcast message to all connected clients every 5 seconds
    Timer.periodic(Duration(seconds: 5), (timer) async {
      await server.sendMessage('Hello broadcast from server');
    });
  } else {
    print('Invalid choice');
  }
}
