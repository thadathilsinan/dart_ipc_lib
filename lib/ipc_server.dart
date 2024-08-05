import 'dart:io';
import 'dart:typed_data';
import 'package:dart_ipc_lib/models/packet.dart';
import 'package:dart_ipc_lib/utils/logger.dart';

/// Socket Server: Listen to requests of the clients (Unix IPC socket) and give required resposes

class IPCServer {
  // Socket Manager instance
  static final _instance = IPCServer._init();
  // Socket file in the System files
  static final _socketPath = '/tmp/elegant_shell.socket';
  // port number doesn't matter (Because of UNIX IPC Socket)
  static final port = 0;
  // Execute when a request comes from client
  late final String? Function(String?) onRequest;
  // All clients connected to the server
  final List<Socket> _clients = List.empty(growable: true);

  // Address to create server Socket (UNIX IPC Socket)
  static final address =
      InternetAddress(_socketPath, type: InternetAddressType.unix);

  // Socket Server
  late final ServerSocket _server;

  //Constructor
  factory IPCServer(String? Function(String?) onRequest) {
    _instance.onRequest = onRequest;
    return _instance;
  }

  // Constructor for singleton
  IPCServer._init() {
    // Remove the Socket file, if already present
    File socketFile = File(_socketPath);
    if (socketFile.existsSync()) {
      socketFile.deleteSync();
      Logger.info("Deleted existing socket.");
    }
  }

  // Initialize the server
  initialize() async {
    Logger.info("Initializing server...");
    _server = await ServerSocket.bind(address, port);

    _server.listen(
      // Handle incoming client connections
      _handelConnection,

      // handle errors
      onError: (error) {
        Logger.error(error);
      },

      // handle the client closing the connection
      onDone: () {
        Logger.info('Client left');
      },
    );
    Logger.info("Server initialized");
  }

  // Handle the incoming connections
  _handelConnection(Socket client) {
    Logger.info('Connection activated from'
        ' ${client.remoteAddress.address}:${client.remotePort}');
    //Add to the clients list
    _clients.add(client);

    client.listen(
      // Handle incoming requests of this particular client
      _handleEvents(client),

      // handle connection errors
      onError: (error) {
        Logger.error(error);
      },

      // handle the client closing the connection
      onDone: () {
        Logger.info('Client left');
        _clients.remove(client);
        client.close();
      },
    );
  }

  // Handle the requests from the client
  _handleEvents(Socket client) => (Uint8List data) {
        // Parse binary into String format
        final message = String.fromCharCodes(data);
        // Convert string data into Packet object
        Packet request = Packet.fromJson(message);

        //Execute onRequest method
        String? returnValue = onRequest(request.data);

        // Send response to the request with same ID of the request
        Packet response = Packet.as(request.id, returnValue);
        client.write(response.toJson());
      };

  // send a packet to all clients connected
  _sendPacket(Packet packet) async {
    for (Socket client in _clients) {
      client.write(packet.toJson());
    }
  }

  // Send a message to all clients
  sendMessage(String message) async {
    // Generate packet of data
    Packet packetToSend = Packet(message);

    // Send message packet
    await _sendPacket(packetToSend);
  }

  //Close the server
  close() {
    // Remove all clients
    _clients.removeWhere((client) {
      client.close();
      return true;
    });
    _server.close();
  }
}
