import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:pool/pool.dart';
import 'package:signalr_netcore/sse_channel/src/channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:uuid/uuid.dart';

import 'src/event_source_transformer.dart';

final _requestPool = Pool(1000);

typedef OnConnected = void Function();

class IOSseChannel extends StreamChannelMixin implements SseChannel {
  int _lastMessageId = -1;
  final Uri _serverUrl;
  final String _clientId;
  late final StreamController<String?> _incomingController;
  late final StreamController<String?> _outgoingController;
  final _onConnected = Completer();

  StreamSubscription? _incomingSubscription;
  StreamSubscription? _outgoingSubscription;

  @override
  StreamSink get sink => _outgoingController.sink;

  @override
  Stream get stream => _incomingController.stream;

  factory IOSseChannel.connect(Uri url) {
    return IOSseChannel._(url);
  }

  IOSseChannel._(Uri serverUrl)
      : _serverUrl = serverUrl,
        _clientId = Uuid().v4(),
        _outgoingController = StreamController<String?>() {
    _incomingController = StreamController<String?>.broadcast(
      onListen: () => _initialize(),
      onCancel: () => _stop(),
    );

    _onConnected.future.whenComplete(() {
      return _outgoingSubscription =
          _outgoingController.stream.listen(_onOutgoingMessage);
    });
  }

  Future<void> _initialize() async {
    final queryParameters = Map<String, String>();
    queryParameters.addAll({'sseClientId': _clientId});
    queryParameters.addAll(_serverUrl.queryParameters);

    final request = Request(
      'GET',
      _serverUrl.replace(queryParameters: queryParameters),
    )..headers['Accept'] = 'text/event-stream';

    await Client().send(request).then((response) {
      if (response.statusCode == 200) {
        _incomingSubscription =
            response.stream.transform(EventSourceTransformer()).listen((event) {
          _incomingController.sink.add(event.data);
        });

        _onConnected.complete();
      } else {
        _incomingController.addError(
          SseClientException('Failed to connect to $_serverUrl'),
        );
      }
    });
  }

  void _stop() {
    _incomingSubscription?.cancel();
    _outgoingSubscription?.cancel();
    _incomingController.sink.close();
    _incomingController.close();
    _outgoingController.sink.close();
    _outgoingController.close();
  }

  Future<void> _onOutgoingMessage(String? message) {
    String? encodedMessage;

    return _requestPool.withResource(() async {
      try {
        encodedMessage = jsonEncode(message);
      } on JsonUnsupportedObjectError {
        //_logger.warning('[$_clientId] Unable to encode outgoing message: $e');
      } on ArgumentError {
        //_logger.warning('[$_clientId] Invalid argument: $e');
      }

      try {
        final url =
            '$_serverUrl?sseClientId=$_clientId&messageId=${_lastMessageId++}';
        await post(Uri.parse(url), body: encodedMessage);
      } catch (error) {
        //final augmentedError =
        //    '[$_clientId] SSE client failed to send $message:\n $error';
        //_logger.severe(augmentedError);
        //_closeWithError(augmentedError);
      }
    });
  }
}

class SseClientException implements Exception {
  final String message;

  const SseClientException(this.message);

  @override
  String toString() {
    return 'SseClientException: $message';
  }
}
