import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_ipc_lib/models/packet.dart';
import 'package:dart_ipc_lib/utils/logger.dart';

/// A client used to connect to the given unix domain socket file and interact with the server
class IPCClient {
  /// The internally used unix doamin socket
  late final Socket _client;

  /// A list of packets that are sent by this client which does not have a response yet.
  ///
  /// Each element in this list contains a packet and a completer. The completer is used to
  /// complete the future when the response is received from the server.
  ///
  /// The elements from this list are removed when the response is received from the server
  /// for that packet.
  final List<({Packet packet, Completer<String?> completer})> _sentPackets = [];

  /// Internet address to connect to the server socket
  late final _internetAddress =
      InternetAddress(serverSocketFilePath, type: InternetAddressType.unix);

  /// The port number of the server
  static final _port = 0;

  /// A completer used to indicate that the connection is established
  final Completer<bool> _connectionCompleter = Completer<bool>();

  /// Server socket file path
  final String serverSocketFilePath;

  /// A callback to execute when a braodcast message is received from the server
  final void Function(String?)? onBroadcastMessageRecievedCallback;

  /// Create the client with the callback to execute on broadcast message from server and the
  /// server socket file path
  IPCClient(
      {required this.serverSocketFilePath,
      this.onBroadcastMessageRecievedCallback}) {
    connect();
  }

  /// Connect to the server socket and start listening for the broadcast messages
  Future<void> connect() async {
    Logger.info("Connecting...");

    do {
      try {
        /// Try to connect to the server socket.
        ///
        /// If the server is available to connect then this will be successful.
        /// Otherwise, it will retry after 500 milliseconds.
        _client = await Socket.connect(_internetAddress, _port);

        /// This will break the loop if the connection is successful
        break;
      } catch (e) {
        /// Connection failed, retry after 500 milliseconds
        Logger.warn('Connection to server socket failed. retying...');
        sleep(Duration(milliseconds: 500));
      }
    } while (true);

    Logger.info("Connceted to server.");

    /// Mark the connection as established
    _connectionCompleter.complete(true);

    /// Listen for the responses from the server
    _client.listen(_serverResponseHandler);
  }

  /// Handle a response recieved from the server.
  ///
  /// This will be called when a response is received from the server.
  /// It can be either a response to a message sent by this client or a broadcast message.
  void _serverResponseHandler(Uint8List data) async {
    try {
      /// Converts the received binary data into a string.
      ///
      /// This string must be in the JSON format of a Packet object.
      String dataString = String.fromCharCodes(data);

      /// In some cases there are chances of getting multiple JSON objects in the
      /// same data. So, split the data into individual JSON objects and convert
      /// them to Packet objects.
      final dataJsons = dataString.split('}');

      for (var dataJson in dataJsons) {
        /// If the JSON object is empty, then skip it.
        if (dataJson.trim().isEmpty) {
          continue;
        }

        /// When splitting the data, the closing bracket of the JSON object is removed.
        /// So, add the closing bracket back to the JSON string.
        dataJson = '$dataJson}';

        /// Create the Packet object from the JSON string
        Packet recievedPacket = Packet.fromJson(dataJson);

        /// If there is a packet sent by this client with the same ID as the received packet,
        /// then this will be the response to that packet.
        ///
        /// Otherwise, this will be a broadcast message from the server.
        if (_sentPackets
            .any((sentPacket) => sentPacket.packet.id == recievedPacket.id)) {
          /// Find the packet sent by this client with the same ID as the received packet
          final sentPacket = _sentPackets.firstWhere(
              (sentPacket) => sentPacket.packet.id == recievedPacket.id);

          /// Remove the sent packet from the list of sent packets
          _sentPackets.removeWhere(
              (sentPacket) => sentPacket.packet.id == recievedPacket.id);

          /// Complete the completer of the sent packet with the response data
          sentPacket.completer.complete(recievedPacket.data);
        } else {
          /// Call the broadcast message received callback if the user has provided it
          onBroadcastMessageRecievedCallback?.call(recievedPacket.data);
        }
      }
    } catch (e) {
      Logger.error("Error in handling server response: $e");
    }
  }

  /// Send a given packet to the server
  Future<void> _sendPacket(Packet packet) async {
    _client.write(packet.toJson());
    await _client.flush();
  }

  /// Send a message to the server
  ///
  /// [noResponse] is used to send a message without waiting for a response.
  ///
  /// Then return the response from the server if the [noResponse] is false.
  /// If the [noResponse] is true, then return null immediately.
  Future<String?> sendMessage(String message, {bool noResponse = false}) async {
    /// Wait for the connection to be established before sending the message
    await _connectionCompleter.future;

    /// Generate packet of data with a new UUID
    Packet packetToSend = Packet(message);

    /// Send message packet
    await _sendPacket(packetToSend);

    if (noResponse) {
      return null;
    } else {
      /// Add the packet to the list of sent packets and wait for the response
      Completer<String?> responseCompleter = Completer();
      _sentPackets.add((packet: packetToSend, completer: responseCompleter));

      final responseData = await responseCompleter.future;
      return responseData;
    }
  }

  /// Close the connection to the server
  Future<void> close() async {
    if (!_connectionCompleter.isCompleted ||
        !await _connectionCompleter.future) {
      /// No connection established
      return;
    }

    _client.flush();
    _client.close();
  }
}
