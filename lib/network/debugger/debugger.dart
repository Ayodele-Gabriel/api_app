class JSONParsingDebugger {
  static void analyzeJSON(Map<String, dynamic> json, String context) {
    print('🔍 Analyzing JSON for $context:');
    print('📊 Keys found: ${json.keys.join(', ')}');

    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      final type = value.runtimeType;

      switch (value) {
        case null:
          print('  🔸 $key: null');

        case String stringValue when stringValue.isEmpty:
          print('  ⚠️ $key: empty string');

        case String stringValue:
          print('  ✅ $key: "$stringValue" (String)');

        case int intValue:
          print('  ✅ $key: $intValue (int)');

        case double doubleValue:
          print('  ✅ $key: $doubleValue (double)');

        case bool boolValue:
          print('  ✅ $key: $boolValue (bool)');

        case List<dynamic> listValue:
          print('  📋 $key: List[${listValue.length}] ($type)');

        case Map<String, dynamic> mapValue:
          print('  📦 $key: Map[${mapValue.keys.length}] ($type)');

        default:
          print('  ❓ $key: $value ($type)');
      }
    }
  }

  static void validatePostStructure(Map<String, dynamic> json) {
    final requiredFields = ['userId', 'id', 'title', 'body'];
    final missingFields = <String>[];
    final wrongTypes = <String>[];

    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        missingFields.add(field);
      } else {
        final value = json[field];
        switch (field) {
          case 'userId' || 'id':
            if (value is! int) wrongTypes.add('$field should be int, got ${value.runtimeType}');
          case 'title' || 'body':
            if (value is! String) wrongTypes.add('$field should be String, got ${value.runtimeType}');
        }
      }
    }

    if (missingFields.isNotEmpty) {
      print('❌ Missing required fields: ${missingFields.join(', ')}');
    }

    if (wrongTypes.isNotEmpty) {
      print('⚠️ Type mismatches: ${wrongTypes.join(', ')}');
    }

    if (missingFields.isEmpty && wrongTypes.isEmpty) {
      print('✅ Post structure is valid');
    }
  }

  static void validatePhotoStructure(Map<String, dynamic> json) {
    final requiredFields = ['albumId', 'id', 'title', 'url', 'thumbnailUrl'];
    final missingFields = <String>[];
    final wrongTypes = <String>[];

    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        missingFields.add(field);
      } else {
        final value = json[field];
        switch (field) {
          case 'albumId' || 'id':
            if (value is! int) wrongTypes.add('$field should be int, got ${value.runtimeType}');
          case 'title' || 'url' || 'thumbnailUrl' :
            if (value is! String) wrongTypes.add('$field should be String, got ${value.runtimeType}');
        }
      }
    }

    if (missingFields.isNotEmpty) {
      print('❌ Missing required fields: ${missingFields.join(', ')}');
    }

    if (wrongTypes.isNotEmpty) {
      print('⚠️ Type mismatches: ${wrongTypes.join(', ')}');
    }

    if (missingFields.isEmpty && wrongTypes.isEmpty) {
      print('✅ Photo structure is valid');
    }
  }
}

