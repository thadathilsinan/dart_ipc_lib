import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipc_lib/ipc_server.dart';
import 'package:dart_ipc_lib/models/packet.dart';
import 'package:dart_ipc_lib/utils/logger.dart';

/// Connect to the server socket and sent request to it.

class IPCClient {
  // Socket client
  late final Socket _client;
  // Broadcast Stream to get data
  late final Stream<Uint8List> _stream;
  // On request callback (Called when a broadcast message arrived from server)
  final void Function(String?) onResponse;

  //Constructor
  IPCClient(this.onResponse);

  // IConnect to the server socket
  Future<void> connect() async {
    Logger.info("Connecting...");
    do {
      try {
        _client = await Socket.connect(IPCServer.address, IPCServer.port);
        break;
      } catch (e) {
        // Connection failed, retry after 500 milliseconds
        Logger.warn('Connection to server socket failed. retying...');
        sleep(Duration(milliseconds: 500));
      }
    } while (true);

    Logger.info("Connceted to server.");
    _stream = _client.asBroadcastStream();

    // Call onRequest when getting a message
    _stream.listen((data) {
      String dataString = String.fromCharCodes(data);
      Packet packet = Packet.fromJson(dataString);
      onResponse(packet.data);
    });
  }

  // send a packet to server
  Future<void> _sendPacket(Packet packet) async {
    _client.write(packet.toJson());
  }

  // Send a message to the server
  Future<String?> sendMessage(String message) async {
    // Generate packet of data
    Packet packetToSend = Packet(message);

    // Send message packet
    await _sendPacket(packetToSend);

    // Wait for response with Packet of same ID as request packet
    await for (Uint8List data in _stream) {
      // Parse data into Packet object
      String dataString = String.fromCharCodes(data);
      Packet packetRecieved = Packet.fromJson(dataString);

      // Checking recieved packet ID
      if (packetRecieved.id == packetToSend.id) {
        return packetRecieved.data;
      }
    }

    // Stream end reached, not able to find the response from server.
    return null;
  }

  // Close the connection to the client
  void close() {
    _client.close();
  }
}
