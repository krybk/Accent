/// Renders `litellm/config.yaml` from the model catalogue, so the catalogue
/// is the one place a model id is written down.
library;

import 'package:accent_protocol/protocol.dart';

const _header =
    '# GENERATED from gateway/lib/src/catalog.dart -- do not edit. '
    'Regenerate: cd gateway && dart run tool/render_litellm_config.dart '
    '> litellm/config.yaml\n';

const _settings = '''
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL

litellm_settings:
  # Per-call spend lands in Postgres. This is the whole reason LiteLLM is here
  # rather than a hand-rolled proxy: without per-call attribution there is no way
  # to tell whether a routing change saved anything.
  success_callback: ["postgres"]
  failure_callback: ["postgres"]
  # Return usage on streamed responses too. Without it the closing frame carries
  # no token counts, and cache hits become invisible precisely where most of the
  # spend happens.
  stream_options:
    include_usage: true
  drop_params: false
''';

/// The complete text of `litellm/config.yaml`: one LiteLLM model per catalogue
/// tier, in map order, each sent to the Anthropic API under its exact id.
String renderLitellmConfig(Map<String, ModelInfo> catalog) {
  final out = StringBuffer(_header)
    ..writeln()
    ..writeln('model_list:');
  for (final MapEntry(key: tier, value: model) in catalog.entries) {
    out
      ..writeln('  - model_name: $tier')
      ..writeln('    litellm_params:')
      ..writeln('      model: anthropic/${model.id}')
      ..writeln('      api_key: os.environ/ANTHROPIC_API_KEY');
  }
  out
    ..writeln()
    ..write(_settings);
  return out.toString();
}
