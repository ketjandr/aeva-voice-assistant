/// Intent-to-action dispatcher for AEVA.
///
/// Maps classified intents from the TFLite model to concrete actions
/// (TTS responses, app launches, UI navigation, API calls).
/// Preserves all original functionality while routing through the
/// ML-based intent classification pipeline.

import 'dart:math';
import 'package:contacts_service/contacts_service.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:function_tree/function_tree.dart';
import 'package:weather/weather.dart';

import 'package:aevavoiceassistant/nlp/intent_classifier.dart';
import 'package:aevavoiceassistant/nlp/text_preprocessor.dart';
import 'package:aevavoiceassistant/utils/user_simple_preferences.dart';
import 'package:aevavoiceassistant/utils/utils.dart';

/// Callback typedefs for UI-level actions that the dispatcher needs to trigger.
typedef SpeakCallback = Future<void> Function(String message);
typedef NavigatePageCallback = void Function(int pageIndex);
typedef NavigateTabCallback = void Function(int tabIndex);
typedef OpenPanelCallback = void Function();
typedef SetStateCallback = void Function(VoidCallback fn);
typedef GoToPageCallback = void Function(BuildContext context);
typedef ThemeChangeCallback = Future<void> Function(int themeId);
typedef AutoActivationCallback = Future<void> Function(bool enabled);
typedef VoiceChangeCallback = Future<void> Function(int voiceId);
typedef PermissionCallback = void Function();

/// Configuration for UI action callbacks, injected from the widget layer.
class DispatcherCallbacks {
  final SpeakCallback speak;
  final NavigatePageCallback navigatePage;
  final NavigateTabCallback navigateTab;
  final OpenPanelCallback openPanel;
  final GoToPageCallback goToOnBoarding;
  final GoToPageCallback goToAboutPage;
  final ThemeChangeCallback changeTheme;
  final AutoActivationCallback setAutoActivation;
  final VoiceChangeCallback changeVoice;
  final PermissionCallback openPermissions;

  const DispatcherCallbacks({
    required this.speak,
    required this.navigatePage,
    required this.navigateTab,
    required this.openPanel,
    required this.goToOnBoarding,
    required this.goToAboutPage,
    required this.changeTheme,
    required this.setAutoActivation,
    required this.changeVoice,
    required this.openPermissions,
  });
}

/// Dispatches classified intents to their corresponding action handlers.
///
/// Each intent category from [IntentConfig] maps to a handler method
/// that executes the appropriate app logic, preserving the original
/// behavior of the monolithic MainFunction().
class IntentDispatcher {
  final DispatcherCallbacks callbacks;
  final BuildContext context;

  IntentDispatcher({
    required this.callbacks,
    required this.context,
  });

  /// Dispatch an intent result to the appropriate handler.
  Future<void> dispatch(IntentResult result, String rawText) async {
    final text = rawText.toLowerCase();
    final entities = result.processedInput.entities;

    switch (result.intent.name) {
      case 'email':
        await _handleEmail(text, entities);
        break;
      case 'contacts':
        await _handleContacts(text, entities);
        break;
      case 'weather':
        await _handleWeather(text, entities);
        break;
      case 'timer':
        await _handleTimer(text, entities);
        break;
      case 'music':
        await _handleMusic(text, entities);
        break;
      case 'navigation':
        await _handleNavigation(text, entities);
        break;
      case 'calculate':
        await _handleCalculate(text, entities);
        break;
      case 'spelling':
        await _handleSpelling(text, entities);
        break;
      case 'app_control':
        await _handleAppControl(text, entities);
        break;
      case 'search':
        await _handleSearch(text, entities);
        break;
      case 'datetime':
        await _handleDateTime(text, entities);
        break;
      case 'conversation':
        await _handleConversation(text, entities);
        break;
      case 'identity':
        await _handleIdentity(text, entities);
        break;
      case 'device_settings':
        await _handleDeviceSettings(text, entities);
        break;
      case 'fallback':
      default:
        await _handleFallback(text, entities);
        break;
    }
  }

  // ─── Intent Handlers ─────────────────────────────────────────────

  Future<void> _handleEmail(String text, Map<String, String> entities) async {
    String recipient = entities['contact_name'] ?? '';
    recipient = recipient.replaceAll(RegExp(r'(please|to)'), '').trim();
    await callbacks.speak("Emailing $recipient");
    Utils.openEmail(toEmail: '', subject: '', body: '');
  }

  Future<void> _handleContacts(String text, Map<String, String> entities) async {
    if (text.contains('911')) {
      Utils.openPhoneCall(phoneNumber: '911');
      return;
    }

    String newText = text.replaceAll(RegExp(r' please'), '');
    newText = newText.replaceAll(RegExp(r' to'), '');

    List<String> result = newText.toLowerCase().split(' ');
    String callValue = "";

    for (final keyword in ['call', 'facetime', 'message', 'text']) {
      int idx = result.indexOf(keyword);
      if (idx != -1 && idx + 1 < result.length) {
        callValue = result[idx + 1];
        break;
      }
    }

    if (callValue.isEmpty) {
      callValue = entities['contact_name'] ?? '';
    }

    try {
      List<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
      int callingIndex = 0;

      while (callingIndex < contacts.length - 1 &&
          !contacts[callingIndex].givenName.toString().toLowerCase().contains(callValue)) {
        callingIndex++;
      }

      Contact contact = contacts[callingIndex];
      await ContactsService.openExistingContact(contact);
      await callbacks.speak("Calling ${contact.givenName}");
    } catch (e) {
      await callbacks.speak("Sorry, I couldn't find that contact.");
    }
  }

  Future<void> _handleWeather(String text, Map<String, String> entities) async {
    callbacks.navigateTab(3);

    String weatherCity = entities['city'] ?? '';
    if (weatherCity.isEmpty) {
      // Parse city from text using original logic
      String newText = text
          .replaceAll(RegExp(r' in'), '')
          .replaceAll(RegExp(r' on'), '')
          .replaceAll(RegExp(r' for'), '')
          .replaceAll(RegExp(r' at'), '')
          .replaceAll(RegExp(r' today'), '')
          .replaceAll(RegExp(r' please'), '')
          .replaceAll(RegExp(r' now'), '')
          .replaceAll(RegExp(r' currently'), '')
          .replaceAll(RegExp(r' right'), '')
          .replaceAll(RegExp(r' the'), '');
      newText = newText + ' Jakarta';

      List<String> parts = newText.toLowerCase().split(' ');
      int weatherIndex = parts.indexOf('weather');
      if (weatherIndex != -1 && weatherIndex + 1 < parts.length) {
        weatherCity = parts[weatherIndex + 1];
      } else {
        weatherCity = 'Jakarta';
      }
    }

    weatherCity = _capitalize(weatherCity);
    await UserSimplePreferences.setWeatherPlace(weatherCity);

    try {
      WeatherFactory weatherFactory = WeatherFactory(
          "733ea65a030833452a13cc85b9d44841",
          language: Language.ENGLISH);
      Weather currentWeather = await weatherFactory.currentWeatherByCityName(weatherCity);

      double humidity = currentWeather.humidity!;
      var temperature = currentWeather.temperature;
      String? weatherDescription = currentWeather.weatherDescription;
      double windSpeed = currentWeather.windSpeed!;
      double pressure = currentWeather.pressure!;

      callbacks.navigateTab(0);
      callbacks.openPanel();

      await callbacks.speak(
          "The weather in $weatherCity, is currently ${weatherDescription.toString()} "
          "and ${temperature.toString()}, with winds up to ${windSpeed.toString()} "
          "kilometers per hour, with an atmospheric pressure of ${pressure.toString()} "
          "hectopascals and a humidity of ${humidity.toString()} percent");
    } catch (e) {
      await callbacks.speak("Sorry, I couldn't get the weather for $weatherCity.");
    }
  }

  Future<void> _handleTimer(String text, Map<String, String> entities) async {
    List<String> result = text.toLowerCase().split(' ');

    int hourValue = int.tryParse(entities['timer_hours'] ?? '') ?? 0;
    int minuteValue = int.tryParse(entities['timer_minutes'] ?? '') ?? 0;
    int secondValue = int.tryParse(entities['timer_seconds'] ?? '') ?? 0;

    // Fallback to original parsing if entities are all zero
    if (hourValue == 0 && minuteValue == 0 && secondValue == 0) {
      hourValue = _parseTimeUnit(result, ['hours', 'hour']);
      minuteValue = _parseTimeUnit(result, ['minutes', 'minute']);
      secondValue = _parseTimeUnit(result, ['seconds', 'second']);

      // Handle "one second" edge case
      if (secondValue == 0 && text.contains('one second')) {
        secondValue = 1;
      }
    }

    int finalTime = 3600 * hourValue + 60 * minuteValue + secondValue;
    await UserSimplePreferences.setTimerDuration(finalTime);

    await callbacks.speak("Your timer is set for "
        "$hourValue hours $minuteValue minutes and $secondValue seconds");

    callbacks.navigateTab(3);
    callbacks.openPanel();
    await UserSimplePreferences.setTimerGo(true);
  }

  Future<void> _handleMusic(String text, Map<String, String> entities) async {
    String processedText = text;
    if (processedText.contains("hip hop")) {
      processedText = processedText.replaceAll(RegExp(r'hip hop'), 'hip-hop');
    }

    String musicValue = entities['music_keyword'] ?? '';

    if (musicValue.isEmpty) {
      String newText = processedText.replaceAll(RegExp(r'play'), '');
      List<String> parts = newText.toLowerCase().split(' ');

      for (final keyword in ['music', 'song']) {
        int idx = parts.indexOf(keyword);
        if (idx > 0) {
          musicValue = parts[idx - 1];
          break;
        }
      }
    }

    await UserSimplePreferences.setSongKeyword(musicValue);
    await callbacks.speak("Playing $musicValue music");

    callbacks.navigateTab(2);
    callbacks.openPanel();
    await UserSimplePreferences.setSongGo(true);
  }

  Future<void> _handleNavigation(String text, Map<String, String> entities) async {
    callbacks.navigateTab(1);
    callbacks.openPanel();
    await callbacks.speak("Opening Google Maps");
  }

  Future<void> _handleCalculate(String text, Map<String, String> entities) async {
    String expression = entities['math_expression'] ?? '';

    if (expression.isEmpty) {
      var newText = text.replaceAll(RegExp(r'is '), '');
      newText = newText.replaceAll(RegExp(r'count'), '');
      newText = newText.replaceAll(RegExp(r'the'), '');
      newText = newText.replaceAll(RegExp(r'square root of'), 'sqrt');
      newText = newText.replaceAll(RegExp(r'squared'), '^2');
      newText = newText.replaceAll(RegExp(r'cubed'), '^3');

      List<String> parts = newText.split(' ');
      int searchIndex = parts.indexOf('calculate');
      if (searchIndex == -1) searchIndex = parts.indexOf('what');

      if (searchIndex != -1) {
        while (searchIndex >= 0) {
          parts.removeAt(searchIndex);
          searchIndex -= 1;
        }
      }
      expression = parts.join(" ").trim();
    }

    try {
      final result = expression.interpret();
      await callbacks.speak("'$expression' is $result");
    } catch (e) {
      await callbacks.speak("Sorry, I couldn't calculate that expression.");
    }
  }

  Future<void> _handleSpelling(String text, Map<String, String> entities) async {
    String spellWord = entities['spell_word'] ?? '';

    if (spellWord.isEmpty) {
      String newText = text
          .replaceAll(RegExp(r' the word'), '')
          .replaceAll(RegExp(r' for'), '')
          .replaceAll(RegExp(r'me '), '');

      List<String> parts = newText.split(' ');
      int spellIndex = parts.indexOf('spell');
      if (spellIndex != -1) {
        while (spellIndex >= 0) {
          parts.removeAt(spellIndex);
          spellIndex -= 1;
        }
        spellWord = parts.join(" ").trim();
      }
    }

    List<String> letters = spellWord.split('');
    await callbacks.speak("$spellWord is ${letters.toString()}");
  }

  Future<void> _handleAppControl(String text, Map<String, String> entities) async {
    final appName = entities['app_name'] ?? text;

    // Internal navigation
    if (text.contains('settings')) {
      callbacks.navigatePage(0);
      await callbacks.speak("Opening Settings");
    } else if (text.contains('library')) {
      callbacks.navigatePage(2);
      await callbacks.speak("Opening Library");
    } else if (text.contains('help')) {
      callbacks.goToOnBoarding(context);
      await callbacks.speak("Opening the Help Screen");
    } else if (text.contains('about')) {
      callbacks.goToAboutPage(context);
      await callbacks.speak("Opening the About Panel");
    } else if (text.contains('feedback')) {
      Utils.openEmail(
          toEmail: 'aevavoiceassistant@gmail.com',
          subject: 'Your Subject Here',
          body: 'Your body here');
      await callbacks.speak("Opening the Feedback Panel");
    } else if (text.contains('panel') || text.contains('slider')) {
      callbacks.openPanel();
      await callbacks.speak("Opening Panel Controller");
    }
    // External apps
    else if (text.contains('google') && !text.contains('maps') &&
        !text.contains('meet') && !text.contains('drive')) {
      Utils.openLink(url: 'https://google.com');
      await callbacks.speak("Opening Google");
    } else if (text.contains('youtube')) {
      Utils.openLink(url: 'https://youtube.com');
      await callbacks.speak("Opening YouTube");
    } else {
      await _launchExternalApp(text);
    }
  }

  Future<void> _launchExternalApp(String text) async {
    final apps = <String, Map<String, String>>{
      'instagram': {
        'android': 'com.instagram.android',
        'ios': 'instagram://',
        'store': 'https://apps.apple.com/id/app/instagram/id389801252',
      },
      'facebook': {
        'android': 'com.facebook.katana',
        'ios': 'facebook://',
        'store': 'https://apps.apple.com/id/app/facebook/id284882215',
      },
      'tik-tok': {
        'android': 'com.zhiliaoapp.musically',
        'ios': 'tiktok://',
        'store': 'https://apps.apple.com/id/app/tiktok/id1235601864',
      },
      'whatsapp': {
        'android': 'com.whatsapp',
        'ios': 'whatsappmessenger://',
        'store': 'https://apps.apple.com/id/app/whatsapp-messenger/id31063399',
      },
      'zoom': {
        'android': 'us.zoom.videomeetings',
        'ios': 'zoomus://',
        'store': 'https://apps.apple.com/id/app/zoom-cloud-meetings/id546505307',
      },
      'xoom': {
        'android': 'us.zoom.videomeetings',
        'ios': 'zoomus://',
        'store': 'https://apps.apple.com/id/app/zoom-cloud-meetings/id546505307',
      },
      'google meet': {
        'android': 'com.google.android.apps.meetings',
        'ios': 'gmeet://',
        'store': 'https://apps.apple.com/id/app/google-meet/id1013231476',
      },
      'messenger': {
        'android': 'com.facebook.orca',
        'ios': 'fb-messenger://',
        'store': 'https://apps.apple.com/id/app/messenger/id454638411',
      },
      'snapchat': {
        'android': 'com.snapchat.android',
        'ios': 'snapchat://',
        'store': 'https://apps.apple.com/id/app/snapchat/id447188370',
      },
      'telegram': {
        'android': 'org.telegram.messenger',
        'ios': 'telegram://',
        'store': 'https://apps.apple.com/id/app/telegram-messenger/id686449807',
      },
      'netflix': {
        'android': 'com.netflix.mediaclient',
        'ios': 'nflx://',
        'store': 'https://apps.apple.com/id/app/netflix/id363590051',
      },
      'spotify': {
        'android': 'com.spotify.music',
        'ios': 'spotify://',
        'store': 'https://apps.apple.com/id/app/spotify-mainkan-musik-baru/id324684580',
      },
      'discord': {
        'android': 'com.discord',
        'ios': 'discord://',
        'store': 'https://apps.apple.com/id/app/discord-obrolan-berkawan/id985746746',
      },
      'twitter': {
        'android': 'com.twitter.android',
        'ios': 'twitter://',
        'store': 'https://apps.apple.com/id/app/twitter/id333903271',
      },
      'twitch': {
        'android': 'ctv.twitch.android.app',
        'ios': 'twitch://',
        'store': 'https://apps.apple.com/id/app/twitch/id460177396',
      },
      'uber': {
        'android': 'com.ubercab',
        'ios': 'uber://',
        'store': 'https://apps.apple.com/id/app/uber/id368677368',
      },
      'skype': {
        'android': 'com.skype.raider',
        'ios': 'skype://',
        'store': 'https://apps.apple.com/id/app/skype-for-iphone/id304878510',
      },
      'powerpoint': {
        'android': 'com.microsoft.office.powerpoint',
        'ios': 'powerpoint://',
        'store': 'https://apps.apple.com/id/app/microsoft-powerpoint/id586449534',
      },
      'mobile legends': {
        'android': 'com.mobile.legends',
        'ios': 'mobilelegends://',
        'store': 'https://apps.apple.com/id/app/mobile-legends-bang-bang/id1160056295',
      },
      'peduli': {
        'android': 'com.telkom.tracencare',
        'ios': 'pedulilindungi://',
        'store': 'https://apps.apple.com/id/app/pedulilindungi/id1504600374',
      },
      'go-jek': {
        'android': 'com.gojek.app',
        'ios': 'gojek://',
        'store': 'https://apps.apple.com/id/app/gojek/id944875099',
      },
      'gojek': {
        'android': 'com.gojek.app',
        'ios': 'gojek://',
        'store': 'https://apps.apple.com/id/app/gojek/id944875099',
      },
      'grab': {
        'android': 'com.grabtaxi.passenger',
        'ios': 'grab://',
        'store': 'https://apps.apple.com/id/app/grab-superapp/id647268330',
      },
      'ovo': {
        'android': 'ovo.id',
        'ios': 'ovo://',
        'store': 'https://apps.apple.com/id/app/ovo/id1142114207',
      },
      'lazada': {
        'android': 'com.lazada.android',
        'ios': 'lazada://',
        'store': 'https://apps.apple.com/id/app/lazada-belanja-online-terbaik/id785385147',
      },
      'blibli': {
        'android': 'blibli.mobile.commerce',
        'ios': 'blibli://',
        'store': 'https://apps.apple.com/id/app/blibli-belanja-online/id1034231507',
      },
      'tokopedia': {
        'android': 'com.tokopedia.tkpd',
        'ios': 'tokopedia://',
        'store': 'https://apps.apple.com/id/app/tokopedia/id1001394201',
      },
      'shopee': {
        'android': 'com.shopee.id',
        'ios': 'shopee://',
        'store': 'https://apps.apple.com/id/app/shopee-1-1-new-year-sale/id959841443',
      },
      'google drive': {
        'android': 'com.google.android.apps.docs',
        'ios': 'googledrive://',
        'store': 'https://apps.apple.com/id/app/google-drive-penyimpanan/id507874739',
      },
    };

    for (final entry in apps.entries) {
      if (text.contains(entry.key)) {
        final appData = entry.value;
        final displayName = _capitalize(entry.key);
        await LaunchApp.openApp(
          androidPackageName: appData['android']!,
          iosUrlScheme: appData['ios']!,
          appStoreLink: appData['store']!,
        );
        await callbacks.speak("Opening $displayName");
        return;
      }
    }

    await callbacks.speak("Sorry, I don't know how to open that app.");
  }

  Future<void> _handleSearch(String text, Map<String, String> entities) async {
    String query = entities['search_query'] ?? '';

    if (query.isEmpty) {
      // Fall back to original parsing logic
      String newText = text
          .replaceAll(RegExp(r' is'), '')
          .replaceAll(RegExp(r' for'), '')
          .replaceAll(RegExp(r' about'), '');
      List<String> parts = newText.split(' ');

      int searchIndex = -1;
      for (final keyword in ['search', 'what', 'google', 'translate', 'define', 'know']) {
        searchIndex = parts.indexOf(keyword);
        if (searchIndex != -1) break;
      }

      if (searchIndex != -1) {
        while (searchIndex >= 0) {
          parts.removeAt(searchIndex);
          searchIndex -= 1;
        }
        query = parts.join(" ").trim();
      } else {
        query = text;
      }
    }

    Utils.openLink(url: 'https://www.google.com/search?q=$query');
    await callbacks.speak("Searching $query in Google");
  }

  Future<void> _handleDateTime(String text, Map<String, String> entities) async {
    DateTime timeNow = DateTime.now();
    await callbacks.speak("The date and time right now is ${timeNow.toString()}");
  }

  Future<void> _handleConversation(String text, Map<String, String> entities) async {
    final rand = Random();

    // Jokes
    if (text.contains('joke') || text.contains('me laugh') || text.contains('be funny')) {
      final jokes = [
        "Why were the teacher's eyes crossed? She couldn't control her pupils.",
        "Why shouldn't you write with a broken pencil? Because it's pointless.",
        "Where do hamburgers go dancing? They go to the meat-ball.",
        "Singing in the shower is fun until you get soap in your mouth. Then it's a soap opera.",
        "I have a joke about chemistry, but I don't think it will get a reaction.",
        "Why did the scarecrow win an award? Because he was outstanding in his field.",
        "A skeleton walks into a bar and says, 'Hey, bartender. I'll have one beer and a mop.'",
        "Why couldn't the leopard play hide and seek? Because he was always spotted.",
        "I thought the dryer was shrinking my clothes. Turns out it was the refrigerator all along.",
        "Why couldn't the bicycle stand up by itself? It was two tired.",
      ];
      await callbacks.speak(jokes[rand.nextInt(jokes.length)]);
    }
    // Stories
    else if (text.contains('story') && text.contains('tell')) {
      final stories = [
        "Once upon a time, there lived a shepherd boy who was bored watching his flock of sheep on the hill. To amuse himself, he shouted, \"Wolf! Wolf! The sheep are being chased by the wolf!\" The villagers came running to help the boy and save the sheep. They found nothing and the boy just laughed looking at their angry faces. \"Don't cry 'wolf' when there's no wolf boy!\", they said angrily and left. The boy just laughed at them. After a while, he got bored and cried 'wolf!' again, fooling the villagers a second time. The angry villagers warned the boy a second time and left. The boy continued watching the flock. After a while, he saw a real wolf and cried loudly, \"Wolf! Please help! The wolf is chasing the sheep. Help!\" But this time, no one turned up to help. By evening, when the boy didn't return home, the villagers wondered what happened to him and went up the hill. The boy sat on the hill weeping. \"Why didn't you come when I called out that there was a wolf?\" he asked angrily. \"The flock is scattered now\", he said. An old villager approached him and said, \"People won't believe liars even when they tell the truth. We'll look for your sheep tomorrow morning. Let's go home now\".",
        "In ancient Greek, there was a king named Midas. He had a lot of gold and everything he needed. He also had a beautiful daughter. Midas loved his gold very much, but he loved his daughter more than his riches. One day, a satyr named Silenus got drunk and passed out in Midas' rose garden. Believing that Satyrs always bring good luck, Midas lets Silenus rest in his palace until he is sober, against the wishes of his wife and daughter. Silenus is a friend of Dionysus, the god of wine and celebration. Upon learning Midas' kindness towards his friend, Dionysus decides to reward the keg. When asked to wish for something, Midas says \"I wish everything I touch turns to gold\". Although Dionysus knew it was not a great idea, he granted Midas his wish. Happy that his wish was granted, Midas went around touching random things in the garden and his palace and turned them all into gold. He touched an apple, and it turned into a shiny gold apple. His subjects were astonished but happy to see so much gold in the palace. In his happiness, Midas went and hugged his daughter, and before he realized, he turned her into a lifeless, golden statue! Aghast, Midas ran back to the garden and called for Dionysus. He begged the god to take away his power and save his daughter. Dionysus gives Midas a solution to change everything back to how it was before the wish. Midas learned his lesson and lived the rest of his life contended with what he had.",
        "Once upon a time, a farmer had a goose that laid a golden egg every day. The egg provided enough money for the farmer and his wife for their day-to-day needs. The farmer and his wife were happy for a long time. But one day, the farmer got an idea and thought, \"Why should I take just one egg a day? Why can't I take all of them at once and make a lot of money?\" The foolish farmer's wife also agreed and decided to cut the goose's stomach for the eggs. As soon as they killed the bird and opened the goose's stomach, to find nothing but guts and blood. The farmer, realizing his foolish mistake, cries over the lost resource! The English idiom \"kill not the goose that lays the golden egg\" was also derived from this classic story.",
        "An old miser lived in a house with a garden. The miser hid his gold coins in a pit under some stones in the garden. Every day, before going to bed, the miser went to the stones where he hid the gold and counted the coins. He continued this routine every day, but not once did he spend the gold he saved. One day, a thief who knew the old miser's routine, waited for the old man to go back into his house. After it was dark, the thief went to the hiding place and took the gold. The next day, the old miser found that his treasure was missing and started crying loudly. His neighbor heard the miser's cries and inquired about what happened. On learning what happened, the neighbor asked, \"Why didn't you save the money inside the house? It would've been easier to access the money when you had to buy something!\" \"Buy?\", said the miser. \"I never used the gold to buy anything. I was never going to spend it.\" On hearing this, the neighbor threw a stone into the pit and said, \"If that is the case, save the stone. It is as worthless as the gold you have lost\".",
        "A tortoise was resting under a tree, on which a bird had built its nest. The tortoise spoke to the bird mockingly, \"What a shabby home you have! It is made of broken twigs, it has no roof, and looks crude. What's worse is that you had to build it yourself. I think my house, which is my shell, is much better than your pathetic nest\". \"Yes, it is made of broken sticks, looks shabby and is open to the elements of nature. It is crude, but I built it, and I like it.\" \"I guess it's just like any other nest, but not better than mine\", said the tortoise. \"You must be jealous of my shell, though.\" \"On the contrary\", the bird replied. \"My home has space for my family and friends; your shell cannot accommodate anyone other than you. Maybe you have a better house. But I have a better home\", said the bird happily.",
      ];
      await callbacks.speak(stories[rand.nextInt(stories.length)]);
    }
    // Greetings
    else if (_matchesAny(text, ['hello', 'hi ', 'hey ', 'greetings'])) {
      await callbacks.speak("Hi, how can I help you?");
    }
    else if (text.contains('good morning')) {
      await callbacks.speak("Good morning to you too.");
    } else if (text.contains('good afternoon')) {
      await callbacks.speak("Good afternoon.");
    } else if (text.contains('good evening')) {
      await callbacks.speak("Good evening.");
    } else if (text.contains('good night')) {
      await callbacks.speak("Good night.");
    }
    // Thank you
    else if (text.contains('thank you') || text.contains('thanks')) {
      final responses = [
        "You are welcome.", "My pleasure.", "Glad to be of help.",
        "I'm happy to help.", "Don't mention it.",
      ];
      await callbacks.speak(responses[rand.nextInt(responses.length)]);
    }
    // How's your day
    else if (text.contains('your day')) {
      final responses = [
        "I'd say I'm doing pretty good. Thanks!",
        "I'm doing great.",
        "I'm happy to be here.",
        "It's going great. Thanks for asking.",
        "Not bad. How about yours?",
      ];
      await callbacks.speak(responses[rand.nextInt(responses.length)]);
    }
    // How are you
    else if (text.contains('how are you')) {
      await callbacks.speak("I am fine, Thank you. How are you?");
    }
    // Can you hear me
    else if (text.contains('you hear me')) {
      await callbacks.speak("Yes, I can hear you well. How can I help you?");
    }
    // Rolling down in the deep
    else if (text.contains('rolling down in the deep')) {
      await callbacks.speak("When your brain goes numb, you can call that mental freeze. When these people talk too much, put that shit in slow motion, yeah. I feel like an astronaut in the ocean, ayy");
    }
    // Shut up
    else if (text.contains('shut up')) {
      await callbacks.speak("Will do.");
    }
    // Knock knock
    else if (text.contains('knock knock')) {
      await callbacks.speak("Yeah...., No.");
    }
    // What is love
    else if (text.contains('what is love')) {
      await callbacks.speak("Baby don't hurt me, don't hurt me, no more.");
    }
    // Favorites / likes
    else if (text.contains('your favorite')) {
      await callbacks.speak("I have to go with your opinion on this one!");
    } else if (text.contains('do you like')) {
      await callbacks.speak("It depends if you also like it!");
    }
    // Help
    else if (text.contains('help') && text.contains('me')) {
      await callbacks.speak("I can help you do various things in your device. Find out more in the library page.");
    }
    // Sing
    else if (text.contains('sing')) {
      await callbacks.speak("I can't sing. But I can play some music for you.");
    }
    // Test
    else if (text.contains('testing') || text.contains('test')) {
      final responses = [
        "I hear you.", "I'm listening.", "Loud and clear.",
        "Here with you.", "Fully functional and ready.",
      ];
      await callbacks.speak(responses[rand.nextInt(responses.length)]);
    }
    else {
      await callbacks.speak("I'm here to chat! What would you like to talk about?");
    }
  }

  Future<void> _handleIdentity(String text, Map<String, String> entities) async {
    if (text == 'aeva' || text == 'eva' || text == 'ava') {
      await callbacks.speak("Hi, that's me! How may I help you?");
    }
    else if (text.contains('your name') || text.contains('who are you') ||
        (text.contains('name') && text.contains('you'))) {
      await callbacks.speak("I am AEVA, your virtual assistant.");
    }
    else if (text.contains('your developer') || text.contains('who developed you') ||
        text.contains('who made you') || text.contains('who created you') ||
        text.contains('who make you') || text.contains('created ava') ||
        text.contains('developed ava') || text.contains('made ava') ||
        text.contains('who made ava')) {
      await callbacks.speak("The developer of AEVA is Kenzo Eugeenio Chandra.");
    }
    else if (text.contains('how old are you') || text.contains('your age') ||
        (text.contains('when') && text.contains('you born'))) {
      await callbacks.speak("In terms of existence, I was first developed by Kenzo Eugeenio Chandra on September 6th, 2021.");
    }
    else if (text.contains('aeva mean') || text.contains('is aeva') ||
        text.contains('eva mean') || text.contains('is eva') ||
        text.contains('ava mean') || text.contains('is ava')) {
      await callbacks.speak("AEVA is short for Artificially Engineered Virtual Assistant.");
    }
    else if (text.contains('your gender')) {
      await callbacks.speak("I don't have a gender.");
    }
    else if ((text.contains('what') && (text.contains('you do') || text.contains('are you')) && !text.contains('doing')) ||
        text.contains('your function') || text.contains('your job')) {
      await callbacks.speak("I am created to help you with various user activity. You can find out more in the Library page.");
    }
    else if (text.contains('sport') && text.contains('you')) {
      await callbacks.speak("I don't know. I'd say all of them are enjoyable.");
    } else if (text.contains('movie') && text.contains('you')) {
      await callbacks.speak("I don't watch movies.");
    } else if (text.contains('hobby') && text.contains('you')) {
      await callbacks.speak("My hobby is to assist you with your activities.");
    } else if (text.contains('f***') && text.contains('you')) {
      await callbacks.speak("That's not very nice.");
    } else if (text.contains('where') && text.contains('you')) {
      await callbacks.speak("I am here and ready.");
    } else if (text.contains('look like') && text.contains('you')) {
      await callbacks.speak("Since I am just simply a bunch of code, I don't possess a physical entity.");
    } else if (text.contains('doing') && text.contains('you')) {
      await callbacks.speak("I'm busy helping you do things.");
    } else if ((text.contains('made of') || text.contains('made from')) && text.contains('you')) {
      await callbacks.speak("A lot, lot, lot of code. But more specifically, I was made in Flutter.");
    } else if ((text.contains('robot') || text.contains('human') || text.contains('person')) && text.contains('you')) {
      await callbacks.speak("No, I'm neither a person nor a robot. I'm software.");
    } else if ((text.contains('artificial intelligence') || text.contains('ai')) && text.contains('destroy')) {
      await callbacks.speak("Possibly, if it falls under the wrong hands.");
    } else if ((text.contains('smart') || text.contains('intelligent')) && text.contains('you')) {
      await callbacks.speak("I am built to be as intelligent as possible, hence the term artificial intelligence.");
    } else if ((text.contains('stupid') || text.contains('dumb') || text.contains('retarded')) && text.contains('you')) {
      await callbacks.speak("That's not very nice.");
    } else if (text.contains('exercise') && text.contains('you')) {
      await callbacks.speak("No, but I can set a timer to aid you in your workouts.");
    } else if (text.contains('friend') && text.contains('you')) {
      await callbacks.speak("Yes I do, that is you, dummy.");
    } else if ((text.contains('parents') || text.contains('mother') || text.contains('father') ||
        text.contains('mom') || text.contains('dad') || text.contains('brother') ||
        text.contains('sister') || text.contains('sibling') || text.contains('family')) && text.contains('you')) {
      await callbacks.speak("Since I'm just software, I don't have a family like a human being would.");
    } else if (text.contains('school') && text.contains('you')) {
      await callbacks.speak("I didn't go to school the way a person does, but machine learning allows me to continuously learn as we speak.");
    } else if (text.contains('i love you') || text.contains('i like you')) {
      await callbacks.speak("Thank you. That is very kind of you.");
    } else {
      await callbacks.speak("I am AEVA, your virtual assistant. How can I help?");
    }
  }

  Future<void> _handleDeviceSettings(String text, Map<String, String> entities) async {
    // Dark/Light mode
    if (text.contains('dark mode') || text.contains('dark theme')) {
      await callbacks.changeTheme(1);
      await callbacks.speak("Switching to Dark Mode.");
    } else if (text.contains('light mode') || text.contains('light theme')) {
      await callbacks.changeTheme(2);
      await callbacks.speak("Switching to Light Mode.");
    }
    // Auto activation
    else if (text.contains('auto activation') || text.contains('auto activate')) {
      if (text.contains(' on') || text.contains('enable')) {
        await callbacks.setAutoActivation(true);
        await callbacks.speak("Auto Activation is enabled.");
      } else if (text.contains(' off') || text.contains('disable')) {
        await callbacks.setAutoActivation(false);
        await callbacks.speak("Auto Activation is disabled.");
      } else {
        await callbacks.speak("Please specify if you would like to enable or disable Auto Activation.");
      }
    }
    // Voice change
    else if ((_matchesAny(text, ['male', 'man', 'boy'])) && text.contains('voice')) {
      await callbacks.changeVoice(2);
      await callbacks.speak("Switched to a Male voice.");
    } else if ((_matchesAny(text, ['female', 'woman', 'girl'])) && text.contains('voice')) {
      await callbacks.changeVoice(1);
      await callbacks.speak("Switched to a Female voice.");
    }
    // Permissions
    else if ((_matchesAny(text, ['location', 'microphone', 'contact'])) &&
        (_matchesAny(text, ['enable', 'disable', 'open', 'on', 'off']))) {
      callbacks.openPermissions();
      await callbacks.speak("Opened app settings for permissions.");
    }
  }

  Future<void> _handleFallback(String text, Map<String, String> entities) async {
    // Check if it's a question that should be searched
    if (_matchesAny(text, ['what', 'where', 'why', 'when', 'who', 'how'])) {
      Utils.openLink(url: 'https://www.google.com/search?q=$text');
      await callbacks.speak("Searching $text in Google");
      return;
    }

    final rand = Random();
    final responses = [
      "Sorry, I don't have an answer for that.",
      "Sorry, I didn't understand that.",
      "I didn't quite get that. Could you try again?",
    ];
    await callbacks.speak(responses[rand.nextInt(responses.length)]);
  }

  // ─── Utilities ───────────────────────────────────────────────────

  int _parseTimeUnit(List<String> words, List<String> unitNames) {
    for (final unit in unitNames) {
      int idx = words.indexOf(unit);
      if (idx > 0) {
        final prev = words[idx - 1];
        if (prev == 'one') return 1;
        return int.tryParse(prev) ?? 0;
      }
    }
    return 0;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _matchesAny(String text, List<String> patterns) {
    return patterns.any((p) => text.contains(p));
  }
}
