import 'dart:io';

import 'package:accent_gateway/src/catalog.dart';
import 'package:accent_gateway/src/litellm_config.dart';
import 'package:test/test.dart';

/// `litellm/config.yaml` is generated from the catalogue. These tests are what
/// make the catalogue the single source: editing either side alone fails here.
void main() {
  String committed() => File('litellm/config.yaml').readAsStringSync();

  test('the committed config is the rendered catalogue', () {
    expect(
      committed(),
      renderLitellmConfig(modelCatalog),
      reason:
          'regenerate: dart run tool/render_litellm_config.dart '
          '> litellm/config.yaml',
    );
  });

  test('every catalogue model is routed by its exact id', () {
    final config = committed();
    for (final model in modelCatalog.values) {
      expect(config, contains('model: anthropic/${model.id}\n'));
    }
  });
}
