import 'package:dart_ipc_lib/ipc_client.dart';
import 'package:dart_ipc_lib/ipc_server.dart';
import 'package:dart_ipc_lib/utils/logger.dart';

/// Manage the server/client for IPC

class IPCManager {
  late final IPCClient? _client;
  late final IPCServer? _server;

  // Initialize for server
  IPCManager.forServer(String? Function(String?) onRequest)
      : _server = IPCServer(onRequest),
        _client = null;

  // Initialize for client
  IPCManager.forClient(void Function(String?) onResponse)
      : _server = null,
        _client = IPCClient(onResponse);

  // Initialize server/client
  initialize() async {
    await _server?.initialize();
    await _client?.connect();

    Logger.info('IPC Manager initialization completed.');
  }

  // Send request
  Future<String?> sendReq(String reqData) async {
    if (_client != null) {
      return _client.sendMessage(reqData);
    } else if (_server != null) {
      _server.sendMessage(reqData);
      return Future.value(null);
    } else {
      Logger.error('IPC Manager is not initialized, cannot send request.');
      return Future.value(null);
    }
  }

  // Close the connection
  close() {
    _client?.close();
    _server?.close();
  }
}
