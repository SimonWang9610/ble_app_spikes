sealed class ConnectionStatus {
  const ConnectionStatus(this.text);

  final String text;
}

class Connecting extends ConnectionStatus {
  const Connecting() : super('Connecting…');
}

class Connected extends ConnectionStatus {
  const Connected() : super('Connected');
}

class Reconnecting extends ConnectionStatus {
  const Reconnecting(this.attempt) : super('Link lost, reconnecting (attempt $attempt)…');

  final int attempt;
}

class Disconnecting extends ConnectionStatus {
  const Disconnecting() : super('Disconnecting…');
}

class Disconnected extends ConnectionStatus {
  const Disconnected([this.reason]) : super(reason == null ? 'Disconnected' : 'Disconnected: $reason');

  final String? reason;
}
