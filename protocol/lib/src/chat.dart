/// Chat wire types.
///
/// These exist in one place so that the app and the gateway cannot disagree
/// about them. Changing a field here breaks compilation on both sides, which is
/// the entire reason this package is shared rather than duplicated.
library;

/// Who produced a message.
enum ChatRole {
  user,
  assistant,
  system;

  static ChatRole fromJson(String value) => ChatRole.values.firstWhere(
        (role) => role.name == value,
        orElse: () => throw FormatException('unknown chat role: $value'),
      );

  String toJson() => name;
}

/// A non-text part of a message: an image, a file, a recording.
///
/// The bytes never travel inside a [ChatMessage]. They are uploaded separately
/// and referenced by [id] — a chat history is replayed on every turn, and
/// inlining a video in it would resend the video on every turn too. That is the
/// same trap as an unstable cache prefix, one order of magnitude worse.
class Attachment {
  const Attachment({
    required this.id,
    required this.mimeType,
    required this.sizeBytes,
    this.filename,
    this.transcript,
  });

  final String id;
  final String mimeType;
  final int sizeBytes;
  final String? filename;

  /// Set by the gateway for audio that was recognised as speech. The app shows
  /// it so the user can see what the model will actually read.
  final String? transcript;

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        id: json['id'] as String,
        mimeType: json['mime_type'] as String,
        sizeBytes: json['size_bytes'] as int,
        filename: json['filename'] as String?,
        transcript: json['transcript'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        if (filename != null) 'filename': filename,
        if (transcript != null) 'transcript': transcript,
      };
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.attachments = const [],
  });

  final ChatRole role;
  final String text;
  final List<Attachment> attachments;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: ChatRole.fromJson(json['role'] as String),
        text: json['text'] as String,
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .map((item) => Attachment.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'role': role.toJson(),
        'text': text,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
      };
}

class ChatRequest {
  const ChatRequest({
    required this.model,
    required this.messages,
    this.conversationId,
  });

  final String model;
  final List<ChatMessage> messages;

  /// Lets the gateway keep a stable prompt prefix per conversation. Without it
  /// the gateway would have to guess which history a request belongs to, and a
  /// wrong guess costs a cache miss on every turn.
  final String? conversationId;

  factory ChatRequest.fromJson(Map<String, dynamic> json) => ChatRequest(
        model: json['model'] as String,
        messages: (json['messages'] as List<dynamic>)
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        conversationId: json['conversation_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        if (conversationId != null) 'conversation_id': conversationId,
      };
}

/// What a single call actually consumed.
///
/// The cache fields are here, in the protocol, on purpose: caching breaks
/// silently, and the only defence is making it visible. The app can show that a
/// turn read its prefix from cache instead of paying for it, so a regression
/// surfaces the moment it happens rather than on the next invoice.
class Usage {
  const Usage({
    required this.inputTokens,
    required this.outputTokens,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
    this.costUsd,
  });

  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;

  /// Reported by the provider, not computed from a price list. Null while the
  /// provider has not published the figure yet.
  final double? costUsd;

  /// True when this turn reused a cached prefix. The share of turns where this
  /// is false is the number worth watching.
  bool get servedFromCache => cacheReadTokens > 0;

  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
        inputTokens: json['input_tokens'] as int,
        outputTokens: json['output_tokens'] as int,
        cacheReadTokens: json['cache_read_tokens'] as int? ?? 0,
        cacheWriteTokens: json['cache_write_tokens'] as int? ?? 0,
        costUsd: (json['cost_usd'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'cache_read_tokens': cacheReadTokens,
        'cache_write_tokens': cacheWriteTokens,
        if (costUsd != null) 'cost_usd': costUsd,
      };
}

/// One frame of a streamed answer.
///
/// A frame carries either a piece of text or the end of the turn — never both.
/// [usage] is only present on the final frame, because token counts are not
/// known until generation stops.
class ChatChunk {
  const ChatChunk({this.text, this.done = false, this.usage, this.model});

  final String? text;
  final bool done;
  final Usage? usage;

  /// Which model actually served the turn. Not always the one that was
  /// requested — a router may substitute, and silent substitution is exactly
  /// what makes a bill inexplicable.
  final String? model;

  factory ChatChunk.fromJson(Map<String, dynamic> json) => ChatChunk(
        text: json['text'] as String?,
        done: json['done'] as bool? ?? false,
        usage: json['usage'] == null
            ? null
            : Usage.fromJson(json['usage'] as Map<String, dynamic>),
        model: json['model'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (text != null) 'text': text,
        if (done) 'done': true,
        if (usage != null) 'usage': usage!.toJson(),
        if (model != null) 'model': model,
      };
}
