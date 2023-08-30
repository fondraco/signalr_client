import 'dart:async';

import 'package:signalr_netcore/sse_channel/src/channel.dart';
import 'package:sse/client/sse_client.dart';
import 'package:stream_channel/stream_channel.dart';

class HtmlSseChannel extends StreamChannelMixin implements SseChannel {
  HtmlSseChannel(this.client);

  factory HtmlSseChannel.connect(Uri url) {
    return HtmlSseChannel(SseClient(url.toString()));
  }

  final SseClient client;

  @override
  StreamSink get sink => client.sink;

  @override
  Stream get stream => client.stream;
}
