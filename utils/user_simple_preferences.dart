import 'package:shared_preferences/shared_preferences.dart';

class UserSimplePreferences {
  static late SharedPreferences _preferences;

  static const _keyActivate = 'activate';
  static const _keyTheme = 'theme';
  static const _keyVoice = 'voice';
  static const _keyTimer = 'timer';
  static const _keyTimerGo = 'timerGo';
  static const _keySong = 'song';
  static const _keySongGo = 'songGo';
  static const _weatherPlace = 'weatherPlace';

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setActivate(bool state) async =>
      await _preferences.setBool(_keyActivate, state);

  static bool? getActivate() => _preferences.getBool(_keyActivate);


  static Future setTheme(int state) async =>
      await _preferences.setInt(_keyTheme, state);

  static int? getTheme() => _preferences.getInt(_keyTheme);


  static Future setVoice(int state) async =>
      await _preferences.setInt(_keyVoice, state);

  static int? getVoice() => _preferences.getInt(_keyVoice);

  //timer
  static Future setTimerDuration(int state) async =>
      await _preferences.setInt(_keyTimer, state);

  static int? getTimerDuration() => _preferences.getInt(_keyTimer);

  static Future setTimerGo(bool state) async =>
      await _preferences.setBool(_keyTimerGo, state);

  static bool? getTimerGo() => _preferences.getBool(_keyTimerGo);

  //music player
  static Future setSongKeyword(String state) async =>
      await _preferences.setString(_keySong, state);

  static String? getSongKeyword() => _preferences.getString(_keySong);

  static Future setSongGo(bool state) async =>
      await _preferences.setBool(_keySongGo, state);

  static bool? getSongGo() => _preferences.getBool(_keySongGo);

  //weather
  static Future setWeatherPlace(String state) async =>
      await _preferences.setString(_weatherPlace, state);

  static String? getWeatherPlace() => _preferences.getString(_weatherPlace);

}