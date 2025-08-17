class User {
  final int id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String website;
  final Address address;
  final Company company;
  final UserPreferences preferences;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.website,
    required this.address,
    required this.company,
    this.preferences = const UserPreferences(),
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return switch (json) {
    // Complete user data
      {
      'id': final dynamic id,
      'name': final dynamic name,
      'username': final dynamic username,
      'email': final dynamic email,
      'address': final Map<String, dynamic> addressJson,
      'company': final Map<String, dynamic> companyJson,
      } => User(
        id: _parseInt(id),
        name: _parseString(name),
        username: _parseString(username),
        email: _parseEmail(email),
        phone: _parseString(json['phone']),
        website: _parseString(json['website']),
        address: Address.fromJson(addressJson),
        company: Company.fromJson(companyJson),
        preferences: UserPreferences.fromJson(json['preferences']),
      ),

    // Minimal user data
      {
      'id': final dynamic id,
      'name': final dynamic name,
      } => User(
        id: _parseInt(id),
        name: _parseString(name),
        username: _parseString(json['username']) ?? 'user${_parseInt(id)}',
        email: _parseEmail(json['email']),
        phone: _parseString(json['phone']),
        website: _parseString(json['website']),
        address: Address.fromJson(json['address']),
        company: Company.fromJson(json['company']),
        preferences: UserPreferences.fromJson(json['preferences']),
      ),

      _ => throw FormatException('Invalid user JSON: missing required fields (id, name)'),
    };
  }

  static int _parseInt(dynamic value) {
    return switch (value) {
      int intValue => intValue,
      String stringValue => int.tryParse(stringValue) ?? 0,
      _ => 0,
    };
  }

  static String _parseString(dynamic value) {
    return switch (value) {
      String stringValue when stringValue.isNotEmpty => stringValue,
      _ => '',
    };
  }

  static String _parseEmail(dynamic value) {
    return switch (value) {
      String email when email.contains('@') => email,
      String email => '$email@example.com',
      _ => 'user@example.com',
    };
  }

  String get displayName => '$name (@$username)';
  String get contactInfo => '📧 $email | 📞 $phone';
  bool get isValidUser => id > 0 && name.isNotEmpty && email.contains('@');
}

class Address {
  final String street;
  final String suite;
  final String city;
  final String zipcode;
  final GeoLocation? geo;

  const Address({
    required this.street,
    required this.suite,
    required this.city,
    required this.zipcode,
    this.geo,
  });

  factory Address.fromJson(dynamic json) {
    return switch (json) {
      Map<String, dynamic> addressMap => switch (addressMap) {
        {
        'street': final String street,
        'city': final String city,
        } => Address(
          street: street,
          suite: addressMap['suite']?.toString() ?? '',
          city: city,
          zipcode: addressMap['zipcode']?.toString() ?? '',
          geo: _parseGeo(addressMap['geo']),
        ),
        _ => const Address(street: '', suite: '', city: '', zipcode: ''),
      },
      _ => const Address(street: '', suite: '', city: '', zipcode: ''),
    };
  }

  static GeoLocation? _parseGeo(dynamic geoData) {
    return switch (geoData) {
      Map<String, dynamic> geoMap => GeoLocation.fromJson(geoMap),
      _ => null,
    };
  }

  String get fullAddress => [street, suite, city, zipcode]
      .where((part) => part.isNotEmpty)
      .join(', ');
}

class GeoLocation {
  final double lat;
  final double lng;

  const GeoLocation({required this.lat, required this.lng});

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {'lat': final dynamic latRaw, 'lng': final dynamic lngRaw} => GeoLocation(
        lat: _parseDouble(latRaw),
        lng: _parseDouble(lngRaw),
      ),
      _ => const GeoLocation(lat: 0.0, lng: 0.0),
    };
  }

  static double _parseDouble(dynamic value) {
    return switch (value) {
      double doubleValue => doubleValue,
      int intValue => intValue.toDouble(),
      String stringValue => double.tryParse(stringValue) ?? 0.0,
      _ => 0.0,
    };
  }
}

class Company {
  final String name;
  final String catchPhrase;
  final String bs;
  final CompanySize size;

  const Company({
    required this.name,
    required this.catchPhrase,
    required this.bs,
    this.size = CompanySize.unknown,
  });

  factory Company.fromJson(dynamic json) {
    return switch (json) {
      Map<String, dynamic> companyMap => Company(
        name: companyMap['name']?.toString() ?? 'Unknown Company',
        catchPhrase: companyMap['catchPhrase']?.toString() ?? '',
        bs: companyMap['bs']?.toString() ?? '',
        size: _parseCompanySize(companyMap['size']),
      ),
      _ => const Company(name: 'Unknown Company', catchPhrase: '', bs: ''),
    };
  }

  static CompanySize _parseCompanySize(dynamic value) {
    return switch (value) {
      'small' => CompanySize.small,
      'medium' => CompanySize.medium,
      'large' => CompanySize.large,
      'enterprise' => CompanySize.enterprise,
      _ => CompanySize.unknown,
    };
  }
}

enum CompanySize { small, medium, large, enterprise, unknown }

class UserPreferences {
  final String theme;
  final bool notifications;
  final String language;

  const UserPreferences({
    this.theme = 'light',
    this.notifications = true,
    this.language = 'en',
  });

  factory UserPreferences.fromJson(dynamic json) {
    return switch (json) {
      Map<String, dynamic> prefsMap => UserPreferences(
        theme: prefsMap['theme']?.toString() ?? 'light',
        notifications: prefsMap['notifications'] as bool? ?? true,
        language: prefsMap['language']?.toString() ?? 'en',
      ),
      _ => const UserPreferences(),
    };
  }
}
