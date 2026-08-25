/// Wire types shared by the Accent app and the Accent gateway.
///
/// This package has no dependencies and no Flutter import, so the same code
/// compiles on the phone and on the server. A change to a request or response
/// shape therefore becomes a compile error on both sides instead of a runtime
/// surprise discovered on a device.
library;

export 'src/catalog.dart';
export 'src/chat.dart';
