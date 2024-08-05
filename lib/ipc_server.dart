import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ipc_lib/models/packet.dart';
import 'package:dart_ipc_lib/utils/logger.dart';

/// A socket server that listens to the client requests and sends response.
class IPCServer {
  /// port number doesn't matter (Because of UNIX IPC Socket)
  /// Here we are using 0 as port number
  static final _port = 0;

  /// All clients connected to this server are stored in this list
  final List<Socket> _clients = List.empty(growable: true);

  /// Address to create server Socket (UNIX IPC Socket)
  late final InternetAddress _internetAddress =
      InternetAddress(socketFilePath, type: InternetAddressType.unix);

  /// Unix domain socket server
  late final ServerSocket _server;

  /// A completer used to indicate that the server is initialized
  final Completer<bool> _serverInitializedCompleter = Completer<bool>();

  /// Socket file in the System files
  final String socketFilePath;

  /// A callback to execute when a request is received from a client
  final Future<String?> Function(String?) onRequestCallback;

  /// Create the server with the socket file path and the callback to execute on request from
  /// client is received.
  IPCServer({required this.socketFilePath, required this.onRequestCallback}) {
    /// Remove the Socket file, if already present
    File socketFile = File(socketFilePath);
    if (socketFile.existsSync()) {
      socketFile.deleteSync();
      Logger.info("Deleted existing socket file.");
    }

    _initialize();
  }

  /// Initialize the server and listen for the client connections
  Future<void> _initialize() async {
    Logger.info("Initializing server...");
    _server = await ServerSocket.bind(_internetAddress, _port);

    _server.listen(
      /// Handle incoming client connections
      _handelConnection,

      /// handle errors
      onError: (error) {
        Logger.error(error);
      },

      /// handle the client closing the connection
      onDone: () {
        Logger.info('Client left');
      },
    );

    Logger.info("Server initialized");

    /// Mark the server as initialized
    _serverInitializedCompleter.complete(true);
  }

  /// Handle the incoming connections from the client programs
  void _handelConnection(Socket client) {
    Logger.info('Connection activated from'
        ' ${client.remoteAddress.address}:${client.remotePort}');

    /// Add this new client to the list of all clients connected to this server
    _clients.add(client);

    /// Listen to the incoming requests from this client
    client.listen(
      /// Handle incoming requests of this particular client
      _handleEvents(client),

      /// handle connection errors
      onError: (error) {
        Logger.error(error);
      },

      /// handle the client closing the connection
      onDone: () async {
        Logger.info('Client left');
        _clients.remove(client);

        await client.flush();
        await client.close();
      },
    );
  }

  /// Handle the requests from a client.
  ///
  /// This is a higher order function that returns a function that handles
  /// the incoming requests from the client passed to this HOF.
  ///
  /// The returned function takes the binary data from the client and converts
  /// it into a string. Then it converts the string into a Packet object for processing
  /// the request.
  void Function(Uint8List)? _handleEvents(Socket client) =>
      (Uint8List data) async {
        try {
          /// Parse binary into String format.
          ///
          /// This String MUST be a JSON representation of the Packet object.
          final message = String.fromCharCodes(data);

          /// Convert string data into Packet object
          Packet request = Packet.fromJson(message);

          /// Execute onRequest method with the data from the request packet
          String? returnValue = await onRequestCallback(request.data);

          /// Send response to the request with same ID of the request.
          ///
          /// Same UUID is used for this response packet to identify the response is
          /// for the request with this UUID.
          Packet response = Packet.as(request.id, returnValue);
          client.write(response.toJson());
          await client.flush();
        } catch (e) {
          Logger.error('Error occured while handling client request: $e');
        }
      };

  /// send a packet to all clients connected.
  ///
  /// This is used to broadcast a message to all clients connected to this server.
  Future<void> _sendPacket(Packet packet) async {
    for (Socket client in _clients) {
      client.write(packet.toJson());
      await client.flush();
    }
  }

  /// Send a message to all clients
  ///
  /// This is used to broadcast a message to all clients connected to this server.
  Future<void> sendMessage(String message) async {
    /// Wait for the server to be initialized before sending the message
    await _serverInitializedCompleter.future;

    /// Generate packet of data with a new UUID
    Packet packetToSend = Packet(message);

    /// Send message packet
    _sendPacket(packetToSend);
  }

  /// Close the server and remove all the client connections
  Future<void> close() async {
    /// Flush all clients and close them
    for (Socket client in _clients) {
      await client.flush();
      client.close();
    }

    /// Remove all clients
    _clients.clear();

    /// Finally close the server
    if (!_serverInitializedCompleter.isCompleted ||
        !await _serverInitializedCompleter.future) {
      /// Server is not initialized yet
      return;
    }

    _server.close();
  }
}
