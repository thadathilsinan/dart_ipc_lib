import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Data are transferred between client and server in the form of packets.
/// Each packet has a unique identifier and data. Here data will be always in
/// the form of string.
///
/// This is the model class for the packet.
class Packet {
  /// Unique identifier for request/response packet
  final String id;

  /// Actual data sent/recieved
  final String? data;

  /// Create a packet with ID and data
  Packet.as(
    this.id,
    this.data,
  );

  /// Create a packet with data and generate a new unique ID
  Packet(
    this.data,
  ) : id = Uuid().v4();

  /// Create a copy of the Packet object
  Packet copyWith({
    String? id,
    String? data,
  }) {
    return Packet.as(
      id ?? this.id,
      data ?? this.data,
    );
  }

  /// Convert into a Map (Used for JSON conversion)
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'data': data,
    };
  }

  /// Create packet from Map
  factory Packet.fromMap(Map<String, dynamic> map) {
    return Packet.as(
      map['id'] as String,
      map['data'] as String,
    );
  }

  /// Convert into JSON string
  String toJson() => json.encode(toMap());

  /// Create packet from JSON string
  factory Packet.fromJson(String source) =>
      Packet.fromMap(json.decode(source) as Map<String, dynamic>);

  /// String representation of a packet
  @override
  String toString() => 'Packet(id: $id, data: $data)';

  /// Compare two packets have same ID and data
  @override
  bool operator ==(covariant Packet other) {
    if (identical(this, other)) return true;

    return other.id == id && other.data == data;
  }

  /// Hash code of the packet
  @override
  int get hashCode => id.hashCode ^ data.hashCode;
}
