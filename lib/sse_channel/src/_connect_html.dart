import 'package:signalr_netcore/sse_channel/html.dart';

import 'channel.dart';

SseChannel connect(Uri url) => HtmlSseChannel.connect(url);
