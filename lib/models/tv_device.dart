class TVDevice {
  final String name;
  final String ipAddress;
  final int port;
  final String? model;
  final String? manufacturer;
  final bool isConnected;
  final DateTime? lastConnected;

  const TVDevice({
    required this.name,
    required this.ipAddress,
    this.port = 8080,
    this.model,
    this.manufacturer,
    this.isConnected = false,
    this.lastConnected,
  });

  TVDevice copyWith({
    String? name,
    String? ipAddress,
    int? port,
    String? model,
    String? manufacturer,
    bool? isConnected,
    DateTime? lastConnected,
  }) {
    return TVDevice(
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      model: model ?? this.model,
      manufacturer: manufacturer ?? this.manufacturer,
      isConnected: isConnected ?? this.isConnected,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'model': model,
      'manufacturer': manufacturer,
      'isConnected': isConnected,
      'lastConnected': lastConnected?.toIso8601String(),
    };
  }

  factory TVDevice.fromJson(Map<String, dynamic> json) {
    return TVDevice(
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int? ?? 8080,
      model: json['model'] as String?,
      manufacturer: json['manufacturer'] as String?,
      isConnected: json['isConnected'] as bool? ?? false,
      lastConnected:
          json['lastConnected'] != null
              ? DateTime.parse(json['lastConnected'] as String)
              : null,
    );
  }

  @override
  String toString() {
    return 'TVDevice(name: $name, ip: $ipAddress:$port, connected: $isConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TVDevice &&
        other.ipAddress == ipAddress &&
        other.port == port;
  }

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;
}
