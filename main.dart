import 'package:aevavoiceassistant/assets/aeva_icons.dart';
import 'package:aevavoiceassistant/page/icon_widget.dart';
import 'package:aevavoiceassistant/page/onboarding_page.dart';
import 'package:aevavoiceassistant/page/about_page.dart';
import 'package:aevavoiceassistant/page/command_library.dart';
import 'package:aevavoiceassistant/data/command_data.dart';
import 'package:aevavoiceassistant/utils/utils.dart';
import 'package:aevavoiceassistant/widget/search_widget.dart';
import 'package:aevavoiceassistant/widget/tab_widget.dart';
import 'package:aevavoiceassistant/nlp/nlp_service.dart';
import 'package:aevavoiceassistant/nlp/intent_dispatcher.dart';
import 'package:app_settings/app_settings.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aevavoiceassistant/utils/user_simple_preferences.dart';


int? initScreen;

Future<void> main() async {
  //smooth gradient
  Paint.enableDithering = true;
  //force portrait
  WidgetsFlutterBinding.ensureInitialized();
  //force portrait
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  //shared preferences initiate
  await Settings.init(cacheProvider: SharePreferenceCache());

  //initiate onboarding screen

  SharedPreferences preferences = await SharedPreferences.getInstance();
  initScreen = await preferences.getInt('initScreen');
  await preferences.setInt('initScreen', 1);

  //initiate user simple preferences
  await UserSimplePreferences.init();

  //run app
  runApp(MyApp());
}

//remove glow scroll
class MyBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Settings.getValue<bool>(SpeechScreenState.keyDarkMode, false);

    return ValueChangeObserver<bool>(
      cacheKey: SpeechScreenState.keyDarkMode,
      defaultValue: false,
      builder: (_, isDarkMode, __) => MaterialApp(
        title: 'AEVA Voice Assistant',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blueGrey,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          //highlightColor: Colors.blue.withOpacity(.5),
          //splashColor: Colors.red,

          //scaffoldBackgroundColor: const Color(0xff2e2e36),
        ),
        initialRoute:
            initScreen == 0 || initScreen == null ? 'onboard' : 'home',
        routes: {
          'home': (context) => SpeechScreen(),
          'onboard': (context) => OnBoardingPage(),
        },
      ),
    );
  }
}

class SpeechScreen extends StatefulWidget {
  @override
  SpeechScreenState createState() => SpeechScreenState();
}

class SpeechScreenState extends State<SpeechScreen>
    with TickerProviderStateMixin {
  final Map<String, HighlightedWord> _highlights = {};

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _autoActivation = false;
  int? _selectedTheme = UserSimplePreferences.getTheme() ?? 1;
  int? _selectedVoice;
  String _text = 'Press the button and start speaking!';
  String _heading = 'Tap to Activate';
  double _confidence = 1.0;
  final FlutterTts flutterTts = FlutterTts();

  late stt.SpeechToText _speechDetector;
  String textDetector = '';
  bool isListeningDetector = false;

  late AnimationController _animationController;
  late Animation<double> _animation;
  int activeIndex = 1;
  Color dotColor = Colors.white;
  static const keyDarkMode = 'key-dark-mode';

  late List<CommandLibrary> books;
  String query = '';

  double _pitch = 1;

  /// On-device NLP service — TFLite intent classification pipeline.
  final NlpService _nlpService = NlpService();

  //late Location location;
  //late LocationData _locationData;

  final style = SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xff121212),
    systemNavigationBarDividerColor: Color(0xff121212),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  final styleLight = SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xffed8600),
    systemNavigationBarDividerColor: Color(0xffed8600),
    systemNavigationBarIconBrightness: Brightness.light,
  );

  final panelController = PanelController();
  double tabBarHeight = 120;
  bool scrollableBool = true;
  bool _isPanelOpened = false;

  late TabController tabController;

  bool _isDraggableSlider = true;
  int? _currentSliderIndex;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _speechDetector = stt.SpeechToText();
    books = allBooks;


    //save auto activation state
    _autoActivation = UserSimplePreferences.getActivate() ?? false;

    //save theme appearance
    _selectedTheme = UserSimplePreferences.getTheme() ?? 1;

    //save voice appearance
    _selectedVoice = UserSimplePreferences.getVoice() ?? 1;

    //set pitch of voice
    if (_selectedVoice == 1) {
      _pitch = 1;
    } else {
      _pitch = 0.5;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 4.0, end: 4.3).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animationController.forward();

    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed)
        _animationController.reverse();
      else if (status == AnimationStatus.dismissed)
        _animationController.forward();
    });

    SystemChrome.setSystemUIOverlayStyle(
        _selectedTheme == 1 ? style : styleLight);

   tabController = TabController(length: 4, vsync: this);

   //getLocationNow();

    // Initialize the on-device NLP pipeline (TFLite model + vocabulary).
    _initializeNlpService();

    if (_autoActivation == true) {
      _listen();
      flutterTts.stop();
    }

  }

  /// Initialize the TFLite intent-classification pipeline and configure
  /// the dispatcher with UI action callbacks.
  Future<void> _initializeNlpService() async {
    await _nlpService.initialize();

    // Deferred dispatcher setup — needs BuildContext from first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nlpService.configureDispatcher(
        context: context,
        callbacks: DispatcherCallbacks(
          speak: _speak,
          navigatePage: (index) => onAddButtonTapped(index),
          navigateTab: (index) => onAddTabControllerJumped(index),
          openPanel: () => panelController.open(),
          goToOnBoarding: (ctx) => goToOnBoarding(ctx),
          goToAboutPage: (ctx) => goToAboutPage(ctx),
          changeTheme: (themeId) async {
            await UserSimplePreferences.setTheme(themeId);
            setState(() {
              _selectedTheme = themeId;
              dotColorCheck();
              SystemChrome.setSystemUIOverlayStyle(
                  themeId == 1 ? style : styleLight);
            });
          },
          setAutoActivation: (enabled) async {
            setState(() => _autoActivation = enabled);
            await UserSimplePreferences.setActivate(enabled);
          },
          changeVoice: (voiceId) async {
            await UserSimplePreferences.setVoice(voiceId);
            setState(() {
              _selectedVoice = voiceId;
              _pitch = voiceId == 1 ? 1.0 : 0.5;
            });
          },
          openPermissions: () => AppSettings.openAppSettings(),
        ),
      );
    });
  }

  @override
  void dispose() {
    tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future _speak(msg) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(_pitch);
    await flutterTts.speak(msg);
  }

  String capitalize(String string) {
    if (string.isEmpty) {
      return string;
    }
    return string[0].toUpperCase() + string.substring(1);
  }

  String decapitalize(String string) {
    if (string.isEmpty) {
      return string;
    }
    return string[0].toLowerCase() + string.substring(1);
  }

  correctAeva(String string) {
    if (string.isEmpty) {
      return string;
    } else if (string.contains('Ava') == true) {
      return string.replaceAll('Ava', 'AEVA');
    } else if (string.contains('Eva') == true) {
      return string.replaceAll('Eva', 'AEVA');
    } else {
      return string;
    }
  }

  PageController pageController = PageController(
    initialPage: 1,
    keepPage: true,
  );



  void onAddButtonTapped(int index) {
    pageController.animateToPage(index,
        duration: Duration(milliseconds: 300), curve: Curves.decelerate);
    if (index == 0 || index == 2) {
      setState(() => scrollableBool = true);
    }
  }

  void onAddButtonJumped(int index) {
    pageController.jumpToPage(index);
    if (index == 0 || index == 2) {
      setState(() => scrollableBool = true);
    }
  }

  void dotColorCheck() {
    if (activeIndex == 1) {
      dotColor = Colors.white;
    } else {
      //dotColor = Colors.indigo;
      dotColor = _selectedTheme == 1 ? Colors.white : Colors.white;
    }
  }

  void onAddTabControllerTapped(int index) {
    tabController.animateTo(index,
        duration: Duration(milliseconds: 300), curve: Curves.decelerate);
    checkForScroll(index);
  }

  void onAddTabControllerJumped(int index) {
    tabController.animateTo(index);
    checkForScroll(index);
  }

  void checkForScroll(index) {
    if (index == 1 && _isPanelOpened == true) {
      setState(() {
        _isDraggableSlider = false;
      });
    } else {
      setState(() {
        _isDraggableSlider = true;
      });
    }
  }

  void stopSpeech() {
    setState(() => _isListening = false);
    _animationController.forward();
    _heading = "Tap to Activate";
    _speech.stop();
  }
/*
  void getLocationNow() async {
    location = new Location();
    _locationData = await location.getLocation();
  }

 */


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff121212),
/*
      appBar: AppBar(
        title: Text('Confidence: ${(_confidence * 100.0).toStringAsFixed(1)}%'),
      ),
*/

      body: ScrollConfiguration(
        behavior: MyBehavior(),
        child: Stack(
          children: <Widget>[
            PageView(
                controller: pageController,
                onPageChanged: (index) {
                  print(index.toString());
                  setState(() => _isListening = false);
                  _animationController.forward();
                  _heading = "Tap to Activate";
                  _speech.stop();
                  setState(() => activeIndex = index);
                  dotColorCheck();
                },
                physics: scrollableBool == true ? AlwaysScrollableScrollPhysics() : NeverScrollableScrollPhysics(),

                children: <Widget>[
                  //settings

                  Scaffold(
                    backgroundColor:
                        _selectedTheme == 1 ? Color(0xff121212) : Colors.white,
                    body: Container(
                      /*
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.thhhopCenter,
                            end: Alignment.bottomCenter,
                            //stops: [0.1, 1],
                            colors: [Color(0xff000000), Color(0xff2e2e36)])),

                     */
                      child: Theme(
                        data: ThemeData(
                          splashColor: Color(0xffababab).withOpacity(0.3),
                          splashFactory: InkRipple.splashFactory,
                          highlightColor: Colors.transparent,
                        ),
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: Container(
                                //color: _selectedTheme == 1 ? Colors.transparent : Color(0xffffbf00),
                                decoration: new BoxDecoration(
                                  color: _selectedTheme == 1
                                      ? Color(0xff121212)
                                      : Color(0xffffbf00),
                                  /*
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedTheme == 1 ? Colors.transparent : Colors.black,
                                      blurRadius: 3.0,
                                      spreadRadius: 0.0,
                                      offset: Offset(0, 0),
                                    )
                                  ],

                                   */
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Settings',
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontFamily: 'NotoSansBold',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: ListView(
                                padding: EdgeInsets.all(0),
                                children: <Widget>[

                                  ListTile(
                                    title: Text(
                                      'GENERAL',
                                      style: TextStyle(
                                          color: _selectedTheme == 1
                                              ? Color(0xff0049bf)
                                              : Colors.blueAccent,
                                          fontFamily: "RobotoBold",
                                          fontSize: 13),
                                    ),
                                    visualDensity: VisualDensity(
                                        horizontal: 0, vertical: -4),
                                  ),
                                  SettingsDivider(0, 0),
                                  Column(
                                      //title: 'General',
                                      children: <Widget>[
                                        buildAppearance(),
                                        buildAutoActivate(),
                                        buildBattery(),
                                        buildVoice(),
                                        buildAppSettings(),
                                      ]),
                                  SettingsDivider(0, 0),
                                  const SizedBox(height: 24),

                                  ListTile(
                                    title: Text(
                                      'PERMISSIONS',
                                      style: TextStyle(
                                          color: _selectedTheme == 1
                                              ? Color(0xff0049bf)
                                              : Colors.blueAccent,
                                          fontFamily: "RobotoBold",
                                          fontSize: 13),
                                    ),
                                    visualDensity: VisualDensity(
                                        horizontal: 0, vertical: -4),
                                  ),
                                  SettingsDivider(0, 0),
                                  Column(
                                    //title: 'Support',
                                      children: <Widget>[
                                        buildMicrophone(),
                                        buildLocations(),
                                        buildContacts(),
                                      ]),
                                  SettingsDivider(0, 0),
                                  const SizedBox(height: 24),

                                  ListTile(
                                    title: Text(
                                      'SUPPORT',
                                      style: TextStyle(
                                          color: _selectedTheme == 1
                                              ? Color(0xff0049bf)
                                              : Colors.blueAccent,
                                          fontFamily: "RobotoBold",
                                          fontSize: 13),
                                    ),
                                    visualDensity: VisualDensity(
                                        horizontal: 0, vertical: -4),
                                  ),
                                  SettingsDivider(0, 0),
                                  Column(
                                      //title: 'Support',
                                      children: <Widget>[
                                        buildHelp(),
                                        buildAbout(),
                                        buildFeedback(),
                                      ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  //mainpage
                  Scaffold(
                    backgroundColor: _selectedTheme == 1
                        ? Color(0xff121212)
                        : Color(0xffed8600),
                    floatingActionButtonLocation:
                        FloatingActionButtonLocation.centerFloat,
                    floatingActionButton:
                        //title
                        SlidingUpPanel(
                          controller: panelController,
                          maxHeight: MediaQuery.of(context).size.height - (MediaQuery.of(context).size.height / 3.5),
                          minHeight: 50,
                          isDraggable: _isDraggableSlider,

                          panelBuilder: (scrollController) => buildSlidingPanel(
                            scrollController: scrollController,
                            panelController: panelController,
                          ),

                          onPanelSlide: (double pos) {
                            if (pos > 0.0) {
                              setState(() {
                                if (scrollableBool == true) {
                                  scrollableBool = false;
                                  _isPanelOpened = true;
                                  stopSpeech();
                                }
                              });
                            } else {
                              setState(() {
                                scrollableBool = true;
                                _isPanelOpened = false;
                              });
                            }
                          },
                          onPanelClosed: () { _isPanelOpened = false; checkForScroll(activeIndex); onAddTabControllerJumped(0);},
                          onPanelOpened: () => _isPanelOpened = true,
                          body: Container(
                      decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                //stops: [0.1, 1],
                                colors: [
                              _selectedTheme == 1
                                  ? Color(0xff2e2e36)
                                  : Color(0xffffdb70),
                              _selectedTheme == 1
                                  ? Color(0xff121212)
                                  : Color(0xffed8600)
                            ])),
                      child: Stack(
                          children: <Widget>[
                            Column(
                              children: <Widget>[
                                Expanded(
                                  flex: 2,
                                  child: Theme(
                                    data: ThemeData(
                                      splashColor: Colors.transparent,
                                      splashFactory: InkRipple.splashFactory,
                                      highlightColor:
                                          Color(0xffababab).withOpacity(0.7),
                                    ),
                                    child: Container(
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                              flex: 1,
                                              child: Container(
                                                alignment: Alignment.center,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  //borderRadius: BorderRadius.circular(100),

                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: <Widget>[
                                                      Container(
                                                        height: 35,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.settings,
                                                            size: 28,
                                                          ),
                                                          color: Colors.white,
                                                          onPressed: () {
                                                            onAddButtonTapped(0);
                                                          },
                                                          splashRadius: 20,
                                                          padding:
                                                              EdgeInsets.only(
                                                                  bottom: 0),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Settings',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontFamily: 'NotoSans',
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )),
                                          Expanded(
                                            flex: 3,
                                            child: Container(),
                                          ),
                                          Expanded(
                                              flex: 1,
                                              child: Container(
                                                alignment: Alignment.center,
                                                child: Material(
                                                  color: Colors.transparent,
                                                  //borderRadius: BorderRadius.circular(100),

                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: <Widget>[
                                                      Container(
                                                        height: 35,
                                                        child: IconButton(
                                                          icon: const Icon(
                                                            Icons.local_library,
                                                            size: 28,
                                                          ),
                                                          color: Colors.white,
                                                          onPressed: () {
                                                            onAddButtonTapped(2);
                                                          },
                                                          splashRadius: 20,
                                                          padding:
                                                              EdgeInsets.only(
                                                                  bottom: 0),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Library',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontFamily: 'NotoSans',
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 0,
                                  child: Container(),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Container(
                                    //color: Colors.red,
                                    child: TextHighlight(
                                      text: _heading,
                                      words: _highlights,
                                      textAlign: TextAlign.center,
                                      textStyle: const TextStyle(
                                        fontSize: 20.0,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w400,
                                        fontFamily: "NotoSansBold",
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(),
                                ),
                              ],
                            ),

                            //button
                            Column(
                              children: <Widget>[
                                Expanded(
                                  flex: 16,
                                  child: Container(
                                    //color: Colors.red,
                                    padding: const EdgeInsets.fromLTRB(
                                        30.0, 0.0, 30.0, 0),
                                    child: ScaleTransition(
                                      scale: _animation,
                                      child: AvatarGlow(
                                        animate: _isListening,
                                        glowColor: Colors.grey,
                                        endRadius: 75.0,
                                        duration:
                                            const Duration(milliseconds: 2000),
                                        repeatPauseDuration:
                                            const Duration(milliseconds: 100),
                                        repeat: true,
                                        child: FloatingActionButton(
                                          onPressed: () {
                                            _listen();
                                            flutterTts.stop();
                                          },
                                          backgroundColor: _selectedTheme == 1
                                              ? Color(0xff4d4d4d)
                                              : Color(0xffffc363),
                                          child: Container(
                                            padding: const EdgeInsets.fromLTRB(
                                                0.0, 0.0, 0.0, 5),
                                            child: Icon(
                                              _isListening
                                                  ? AevaIcons.aeva_icon_filled
                                                  : AevaIcons.aeva_icon_none,
                                              size: 50,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(),
                                ),
                              ],
                            ),

                            Column(
                              children: <Widget>[
                                Expanded(
                                  flex: 4,
                                  child: Container(),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    //color: Colors.blue,
                                    child: SingleChildScrollView(
                                      reverse: true,
                                      child: Container(
                                        //height: (MediaQuery.of(context).size.height),
                                        //color: Colors.red,
                                        padding: const EdgeInsets.fromLTRB(
                                            35.0, 0.0, 35.0, 30.0),

                                        child: TextHighlight(
                                          text: correctAeva(capitalize(_text)),
                                          words: _highlights,
                                          textAlign: TextAlign.center,
                                          textStyle: const TextStyle(
                                            fontSize: 16.0,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w400,
                                            fontFamily: "NotoSans",
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(),
                                ),
                              ],
                            ),
                          ],
                      ),
                    ),
                        ),
                  ),

                  //library page
                  Scaffold(
                    backgroundColor:
                        _selectedTheme == 1 ? Color(0xff121212) : Colors.white,
                    body: Container(
                      child: Theme(
                        data: ThemeData(
                          splashColor: Color(0xffababab).withOpacity(0.3),
                          splashFactory: InkRipple.splashFactory,
                          highlightColor: Colors.transparent,
                        ),
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: new BoxDecoration(
                                  color: _selectedTheme == 1
                                      ? Color(0xff121212)
                                      : Color(0xffffbf00),
                                ),
                                child: Text(
                                  'Library',
                                  style: TextStyle(
                                    fontSize: 18.0,
                                    fontFamily: 'NotoSansBold',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 14,
                              child: Column(
                                children: <Widget>[
                                  buildSearch(),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: books.length,
                                      itemBuilder: (context, index) {
                                        final book = books[index];

                                        return buildBook(book);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
            Container(
              alignment: Alignment.topCenter,
              child: Column(
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                            flex: 1,
                            child: Container(
                              alignment: Alignment.center,
                            )),
                        Expanded(
                          flex: 1,
                          child: Container(
                            alignment: Alignment.center,
                            child: AnimatedSmoothIndicator(
                              activeIndex: activeIndex,
                              count: 3,
                              effect: WormEffect(
                                spacing: 8.0,
                                radius: 4.0,
                                dotWidth: 8.0,
                                dotHeight: 8.0,
                                dotColor: _selectedTheme == 1
                                    ? Colors.grey
                                    : Color(0xffadadad).withOpacity(0.6),
                                activeDotColor: dotColor,
                              ),
                            ),
                          ),
                        ),
                        Expanded(flex: 1, child: Container()),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAppearance() => ListTile(
        title: Text(
          'Appearance',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Customize visual theme and appearance',
            style: TextStyle(color: Color(0xff949494)),
          ),
        ),
        visualDensity: VisualDensity(horizontal: 0, vertical: 2),
        hoverColor: Colors.red,
        onTap: () async {
          await showInformationDialog(context);
        },
      );

  Widget buildAutoActivate() => SwitchListTile(
        title: Text(
          'Auto Activation',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Set AEVA to activate automatically when opened',
            style: TextStyle(color: Color(0xff949494)),
          ),
        ),
        //visualDensity: VisualDensity(horizontal: 0, vertical: 2),
        //activeColor: Colors.green,
        visualDensity: VisualDensity(horizontal: 0, vertical: 4),
        inactiveTrackColor: Color(0xff595959),
        activeColor: Colors.blueAccent,
        value: _autoActivation,
        onChanged: (bool value) async {
          setState(() => _autoActivation = value);
          //print(_autoActivation);
          await UserSimplePreferences.setActivate(value);
        },
      );

  Widget buildVoice() => ListTile(
        title: Text(
          'Voice',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Change the voice of AEVA',
            style: TextStyle(color: Color(0xff949494)),
          ),
        ),
        visualDensity: VisualDensity(horizontal: 0, vertical: 2),
        onTap: () async {
          await showVoiceDialog(context);
        },
      );

  Widget buildMicrophone() => ListTile(
        title: Text(
          'Microphone',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Enable the microphone for voice recognition',
            style: TextStyle(color: Color(0xff949494)),
          ),
        ),
        visualDensity: VisualDensity(horizontal: 0, vertical: 2),
        onTap: () => AppSettings.openAppSettings(),
      );

  Widget buildLocations() => ListTile(
    title: Text(
      'Location',
      style: TextStyle(
          color: _selectedTheme == 1 ? Colors.white : Colors.black),
    ),
    subtitle: Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        'Enable location for Google Maps services',
        style: TextStyle(color: Color(0xff949494)),
      ),
    ),
    visualDensity: VisualDensity(horizontal: 0, vertical: 2),
    onTap: () => AppSettings.openLocationSettings(),
  );

  Widget buildContacts() => ListTile(
    title: Text(
      'Contacts',
      style: TextStyle(
          color: _selectedTheme == 1 ? Colors.white : Colors.black),
    ),
    subtitle: Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        'Enable location for contacts services',
        style: TextStyle(color: Color(0xff949494)),
      ),
    ),
    visualDensity: VisualDensity(horizontal: 0, vertical: 2),
    onTap: () => AppSettings.openAppSettings(),
  );

  Widget buildAppSettings() => ListTile(
    title: Text(
      'App Settings',
      style: TextStyle(
          color: _selectedTheme == 1 ? Colors.white : Colors.black),
    ),
    subtitle: Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        'Adjust general app settings',
        style: TextStyle(color: Color(0xff949494)),
      ),
    ),
    visualDensity: VisualDensity(horizontal: 0, vertical: 2),
    onTap: () => AppSettings.openAppSettings(),
  );

  Widget buildBattery() => ListTile(
        title: Text(
          'Battery and Performance',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text(
            'Adjust the battery usage and performance',
            style: TextStyle(color: Color(0xff949494)),
          ),
        ),
        //leading: IconWidget(icon: Icons.logout, color: Colors.blue),
        visualDensity: VisualDensity(horizontal: 0, vertical: 2),
        onTap: () => AppSettings.openBatteryOptimizationSettings(),
      );

  Widget buildHelp() => ListTile(
        title: Text(
          'Help',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        visualDensity: VisualDensity(horizontal: 0, vertical: 0),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 28,
          color: _selectedTheme == 1 ? Colors.white : Color(0xff7d7d7d),
        ),
        onTap: () => goToOnBoarding(context),
      );

  Widget buildAbout() => ListTile(
        title: Text(
          'About',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        visualDensity: VisualDensity(horizontal: 0, vertical: 0),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 28,
          color: _selectedTheme == 1 ? Colors.white : Color(0xff7d7d7d),
        ),
        onTap: () => goToAboutPage(context),
      );

  Widget buildFeedback() => ListTile(
        title: Text(
          'Feedback',
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        visualDensity: VisualDensity(horizontal: 0, vertical: 0),
        trailing: Icon(
          Icons.keyboard_arrow_right,
          size: 28,
          color: _selectedTheme == 1 ? Colors.white : Color(0xff7d7d7d),
        ),
        onTap: () => Utils.openEmail(
          toEmail: 'aevavoiceassistant@gmail.com',
          subject: 'Your Subject Here',
          body: 'Your body here',
        ),
      );

  Widget buildDarkMode() => SwitchSettingsTile(
        settingKey: keyDarkMode,
        title: 'Dark Mode',
        subtitle: '',
        leading: IconWidget(icon: Icons.logout, color: Colors.blue),
        onChange: (_) {},
        //onTap: () => Utils.showSnackBar(context, 'Clicked Logout'),
      );

  void goToOnBoarding(context) => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OnBoardingPage()),
      );

  void goToAboutPage(context) => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AboutPage()),
      );

  Widget buildSearch() => SearchWidget(
        text: query,
        hintText: 'Search for commands or queries',
        onChanged: searchBook,
      );

  Widget buildBook(CommandLibrary book) => ListTile(
        /*
        leading: Image.network(
          book.urlImage,
          fit: BoxFit.cover,
          width: 50,
          height: 50,
        ),
         */
        title: Text(
          book.title,
          style: TextStyle(
              color: _selectedTheme == 1 ? Colors.white : Colors.black),
        ),
        subtitle: Text(
          book.author,
          style: TextStyle(color: Color(0xff949494)),
        ),
        onTap: () {
          flutterTts.stop();
          onAddButtonTapped(1);
          setState(() => _text = book.urlImage);
          MainFunction();
        },
      );

  Widget SettingsDivider(double firstIndent, double secondIndent) => Divider(
        height: 0,
        color: Color(0xff7a7a7a).withOpacity(0.6),
        indent: firstIndent,
        endIndent: secondIndent,
      );

  void searchBook(String query) {
    final books = allBooks.where((book) {
      final titleLower = book.title.toLowerCase();
      final authorLower = book.author.toLowerCase();
      final searchLower = query.toLowerCase();

      return titleLower.contains(searchLower) ||
          authorLower.contains(searchLower);
    }).toList();

    setState(() {
      this.query = query;
      this.books = books;
    });
  }

  Widget buildSlidingPanel({
    required PanelController panelController,
    required ScrollController scrollController,
  }) =>
      DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: buildTabBar(
              onClicked: () {
            _isPanelOpened == false ? panelController.open() : panelController.close();
            stopSpeech();
          }

          ),
          body: TabBarView(
            controller: tabController,
            physics: NeverScrollableScrollPhysics(),
            children: [
              WeatherApp(scrollController: scrollController),
              GoogleMapApp(scrollController: scrollController),
              MusicApp(scrollController: scrollController),
              TimerCountdownApp(scrollController: scrollController),
            ],
          ),
        ),
      );

  PreferredSizeWidget buildTabBar({
    required VoidCallback onClicked,
  }) =>
      PreferredSize(
        preferredSize: Size.fromHeight(90),
        child: GestureDetector(
          onTap: onClicked,
          child: AppBar(
            backgroundColor: _selectedTheme == 1 ? Color(0xff5d5f66) : Color(0xffffae00),
            title: buildDragIcon(), // Icon(Icons.drag_handle),
            centerTitle: true,
            bottom: TabBar(
              controller: tabController,
              indicatorColor: _selectedTheme == 1 ? Color(0xff9e9e9e) : Colors.white,
              onTap: (int index){
                setState(() => print(index));
                setState(() => _currentSliderIndex = index);
                //onAddTabControllerJumped(index);
                checkForScroll(index);
              },
              tabs: [
                Tab(child: Text('Weather')),
                Tab(child: Text('Maps')),
                Tab(child: Text('Music')),
                Tab(child: Text('Timer')),
              ],
            ),
          ),
        ),
      );

  Widget buildDragIcon() => Container(
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    width: 40,
    height: 8,
  );

  Future<void> showInformationDialog(BuildContext context) async {
    return await showDialog(
        context: context,
        builder: (context) {
          int? selectedValue = _selectedTheme;
          return AlertDialog(
            backgroundColor: Color(0xff262930),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Theme(
                  data: ThemeData(
                    splashColor: Colors.transparent,
                    splashFactory: InkRipple.splashFactory,
                    highlightColor: Color(0xffababab).withOpacity(0.3),
                    unselectedWidgetColor: Color(0xffbfbfbf),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            'Select an Appearance',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: RadioListTile(
                          title: const Text(
                            'Dark Mode',
                            style: TextStyle(color: Colors.white),
                          ),
                          groupValue: selectedValue,
                          value: 1,
                          activeColor: Colors.blueAccent,
                          onChanged: (value) async {
                            setState(() => selectedValue = 1);
                            await UserSimplePreferences.setTheme(
                                selectedValue!);
                            _selectedTheme =
                                UserSimplePreferences.getTheme() ?? 1;
                            setState(() => dotColorCheck());

                            setState(() =>
                                SystemChrome.setSystemUIOverlayStyle(style));

                            onAddButtonJumped(1);
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: RadioListTile(
                          title: const Text(
                            'Light Mode',
                            style: TextStyle(color: Colors.white),
                          ),
                          groupValue: selectedValue,
                          value: 2,
                          activeColor: Colors.blueAccent,
                          onChanged: (value) async {
                            setState(() => selectedValue = 2);
                            await UserSimplePreferences.setTheme(
                                selectedValue!);
                            _selectedTheme =
                                UserSimplePreferences.getTheme() ?? 1;
                            setState(() => dotColorCheck());

                            setState(() => SystemChrome.setSystemUIOverlayStyle(
                                styleLight));

                            onAddButtonJumped(1);
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text("CANCEL")),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
  }

  Future<void> showVoiceDialog(BuildContext context) async {
    return await showDialog(
        context: context,
        builder: (context) {
          int? selectedValue = _selectedVoice;
          return AlertDialog(
            backgroundColor: Color(0xff262930),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Theme(
                  data: ThemeData(
                    splashColor: Colors.transparent,
                    splashFactory: InkRipple.splashFactory,
                    highlightColor: Color(0xffababab).withOpacity(0.3),
                    unselectedWidgetColor: Color(0xffbfbfbf),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            'Select a Voice',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: RadioListTile(
                          title: const Text(
                            'Female',
                            style: TextStyle(color: Colors.white),
                          ),
                          groupValue: selectedValue,
                          value: 1,
                          activeColor: Colors.blueAccent,
                          onChanged: (value) async {
                            setState(() => selectedValue = 1);
                            await UserSimplePreferences.setVoice(
                                selectedValue!);
                            _selectedVoice =
                                UserSimplePreferences.getVoice() ?? 1;
                            setState(() => _pitch = 1);
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.topLeft,
                        child: RadioListTile(
                          title: const Text(
                            'Male',
                            style: TextStyle(color: Colors.white),
                          ),
                          groupValue: selectedValue,
                          value: 2,
                          activeColor: Colors.blueAccent,
                          onChanged: (value) async {
                            setState(() => selectedValue = 2);
                            await UserSimplePreferences.setVoice(
                                selectedValue!);
                            _selectedVoice =
                                UserSimplePreferences.getVoice() ?? 1;
                            setState(() => _pitch = 0.5);
                          },
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text("SAVE")),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
  }

  /// Process user input through the on-device TFLite intent-classification
  /// pipeline:
  ///   1. Text preprocessing (normalization, tokenization, sequence encoding)
  ///   2. TFLite model inference (~93% accuracy, sub-100ms latency)
  ///   3. Entity extraction (contact names, cities, durations, etc.)
  ///   4. Intent dispatch to the appropriate action handler
  void MainFunction() async {
    _text = decapitalize(_text);

    // Run the full NLP pipeline: preprocess → classify → dispatch
    final result = await _nlpService.processInput(_text);
    debugPrint('[AEVA] Intent: ${result.intent.name} '
        '(confidence: ${(result.confidence * 100).toStringAsFixed(1)}%, '
        'latency: ${result.latencyMs}ms)');
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
          onStatus: (val) => print('onStatus: $val'),
          onError: (val) {
            print('onError: $val');
            setState(() => _isListening = false);
            _animationController.forward();
            _heading = "Tap to Activate";
            if (_text == "") {
              _text = 'Press the button and start speaking!';
            }
          });
      if (available) {
        setState(() => _isListening = true);
        _animationController.stop();

        if (Platform.isIOS) {
          _heading = "Tap Again to Finish";
        } else {
          _heading = "Listening...";
        }

        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;

            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;

              if (Platform.isAndroid) {
                setState(() => _isListening = false);
                _speech.stop();
                _animationController.forward();
                print(_text);
                _heading = "Tap to Activate";
                MainFunction();

                if (_text == "") {
                  _text = 'Press the button and start speaking!';
                }
              }
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _animationController.forward();
      _heading = "Tap to Activate";
      _speech.stop();
      print(_text);

      if (_text == "") {
        _text = 'Press the button and start speaking!';
      }

      if (Platform.isIOS) {
        MainFunction();
      }
    }
  }

}


