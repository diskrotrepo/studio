class Configuration {
  const Configuration({
    required this.buildEnvironment,
    required this.apiHost,
    required this.secure,
    required this.applicationId,
  });

  final BuildEnvironment buildEnvironment;
  final String apiHost;
  final bool secure;
  final String applicationId;

  static String environmentLookup() {
    const envFromDefine = String.fromEnvironment('BUILD_ENV');
    if (envFromDefine.isNotEmpty) return envFromDefine;

    bool inDebug = false;
    assert(() {
      inDebug = true;
      return true;
    }());

    if (inDebug) {
      return 'local';
    } else {
      return 'prod';
    }
  }
}

enum BuildEnvironment { local, localProd, prod }
