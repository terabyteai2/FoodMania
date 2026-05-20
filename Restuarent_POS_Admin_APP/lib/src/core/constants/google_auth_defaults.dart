class GoogleAuthDefaults {
  GoogleAuthDefaults._();

  static const String webClientId = String.fromEnvironment(
    'POS_GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '17506890816-phe8hk3uo1ia5tjvaqqt06s7inu43v29.apps.googleusercontent.com',
  );
}
