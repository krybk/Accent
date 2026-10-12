/// Prints `litellm/config.yaml` as rendered from the model catalogue.
///
/// Run from `gateway/`:
/// `dart run tool/render_litellm_config.dart > litellm/config.yaml`
library;

import 'dart:io';

import 'package:accent_gateway/src/catalog.dart';
import 'package:accent_gateway/src/litellm_config.dart';

void main() => stdout.write(renderLitellmConfig(modelCatalog));
