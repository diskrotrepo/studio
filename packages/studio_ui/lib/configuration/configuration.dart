import 'package:web/web.dart' as web;

export 'configuration_base.dart';

import 'configuration_base.dart';

Configuration? _configuration;

Configuration get configuration {
  _configuration ??= _fromEnvironment();
  return _configuration!;
}

Configuration _fromEnvironment() {
  final buildEnv = Configuration.environmentLookup();

  final env = switch (buildEnv) {
    'local' => BuildEnvironment.local,
    'localProd' => BuildEnvironment.localProd,
    'prod' => BuildEnvironment.prod,
    _ => throw ArgumentError('Unknown build environment set: $buildEnv'),
  };

  return Configuration(
    buildEnvironment: env,
    apiHost: switch (env) {
      BuildEnvironment.local => '${web.window.location.hostname}:8080',
      BuildEnvironment.localProd => '${web.window.location.hostname}:8080',
      BuildEnvironment.prod => 'api.diskrot.com',
    },
    secure: switch (env) {
      BuildEnvironment.local => false,
      BuildEnvironment.localProd => false,
      BuildEnvironment.prod => true,
    },
    applicationId: 'diskrot-studio',
  );
}
