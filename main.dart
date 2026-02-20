import 'package:aevavoiceassistant/assets/aeva_icons.dart';
import 'package:aevavoiceassistant/page/icon_widget.dart';
import 'package:aevavoiceassistant/page/onboarding_page.dart';
import 'package:aevavoiceassistant/page/about_page.dart';
import 'package:aevavoiceassistant/page/command_library.dart';
import 'package:aevavoiceassistant/data/command_data.dart';
import 'package:aevavoiceassistant/utils/utils.dart';
import 'package:aevavoiceassistant/widget/search_widget.dart';
import 'package:aevavoiceassistant/widget/tab_widget.dart';
import 'package:app_settings/app_settings.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
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
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aevavoiceassistant/utils/user_simple_preferences.dart';
import 'package:weather/weather.dart';
import 'package:function_tree/function_tree.dart';
import 'package:contacts_service/contacts_service.dart';


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


    if (_autoActivation == true) {
      _listen();
      flutterTts.stop();
    }

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

  void MainFunction() async {
    //mainFunction Starts
    _text = decapitalize(_text);

    if (_text.contains('email') == true) {
      String _newText = _text.replaceAll(RegExp(r'email'), '');
      _newText = _newText.replaceAll(RegExp(r'to'), '');
      _newText = _newText.replaceAll(RegExp(r'please'), '');
      _speak("Emailing " + _newText);
      Utils.openEmail(
        toEmail: '',
        subject: '',
        body: '',
      );
    }
    else if (_text.contains('call') &&  _text.contains('911')) {
      Utils.openPhoneCall(phoneNumber: '911');
    }
    else if (_text.contains('call') || _text.toLowerCase().contains('facetime') ||  _text.toLowerCase().contains('message') || _text.toLowerCase().contains('text')) {

      String newText = _text.replaceAll(RegExp(r' please'), '');
      newText = newText.replaceAll(RegExp(r' to'), '');

      List<String> result = newText.toLowerCase().split(' ');

      String callValue = "";


      int callIndex = result.indexOf('call');
      if (callIndex != -1) {
        callValue = result[callIndex + 1];
      } else {
        callIndex = result.indexOf('facetime');
        if (callIndex != -1) {
          callValue = result[callIndex + 1];
        } else {
          callIndex = result.indexOf('message');
          if (callIndex != -1) {
            callValue = result[callIndex + 1];
          } else {
            callIndex = result.indexOf('text');
            if (callIndex != -1) {
              callValue = result[callIndex + 1];
            }
          }
        }
      }


      List<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
      print(contacts.length);

      int callingIndex = 0;

      void callAfterIndex() {
        while (contacts[callingIndex].givenName.toString().toLowerCase().contains(callValue) == false)
        {
          if (callingIndex <= contacts.length - 2) {
            callingIndex++;
          } else {
            break;
          }
        }
      }

      callAfterIndex();
      Contact contact = contacts[callingIndex];

      print(contact);


      await ContactsService.openExistingContact(contact);

      _speak("Calling " + contact.givenName.toString());



      //Utils.openPhoneCall(phoneNumber: '081234567');
    }
    else if (_text.contains('weather') == true) {

      onAddTabControllerJumped(3);

      String newText = _text.replaceAll(RegExp(r' in'), '');
      newText = newText.replaceAll(RegExp(r' on'), '');
      newText = newText.replaceAll(RegExp(r' for'), '');
      newText = newText.replaceAll(RegExp(r' at'), '');
      newText = newText.replaceAll(RegExp(r' today'), '');
      newText = newText.replaceAll(RegExp(r' please'), '');
      newText = newText.replaceAll(RegExp(r' now'), '');
      newText = newText.replaceAll(RegExp(r' currently'), '');
      newText = newText.replaceAll(RegExp(r' right'), '');
      newText = newText.replaceAll(RegExp(r' now'), '');
      newText = newText.replaceAll(RegExp(r' the'), '');
      newText = newText + ' Jakarta';

      List<String> result = newText.toLowerCase().split(' ');

      String weatherValue = "";

      //getweather
      int weatherIndex = result.indexOf('weather');
      if (weatherIndex != -1) {
        weatherValue = result[weatherIndex + 1];
      }

      await UserSimplePreferences.setWeatherPlace(capitalize(weatherValue));

      Temperature? temperature = Temperature(273);
      double humidity = 0;
      double windSpeed = 0;
      double pressure = 0;
      String? weatherDescription = '';

      WeatherFactory weatherFactory = new WeatherFactory("733ea65a030833452a13cc85b9d44841", language: Language.ENGLISH);
      Weather currentWeather = await weatherFactory.currentWeatherByCityName(weatherValue);

      humidity = currentWeather.humidity!;
      temperature = currentWeather.temperature;
      weatherDescription = currentWeather.weatherDescription;
      windSpeed = currentWeather.windSpeed!;
      pressure = currentWeather.pressure!;


      onAddTabControllerJumped(0);
      panelController.open();

      _speak("The weather in" + weatherValue + ", is currently" + weatherDescription.toString() + "and" +
          temperature.toString() + ", with weends up to" + windSpeed.toString() + "kilometers per hour, with an"
          " atmospheric pressure of" + pressure.toString() + "hectopascals" + "and a humidity of" +
          humidity.toString() +  "percent");


    }
    else if (_text.contains('timer') == true) {
      List<String> result = _text.toLowerCase().split(' ');

      int hourValue = 0;
      int minuteValue = 0;
      int secondvalue = 0;

      //gethours
      int hour = result.indexOf('hours');
      if (hour != -1) {
        hourValue = int.parse(result[hour - 1]);
      }
      else if (hour == -1) {
        hour = result.indexOf('hour');
        if (hour != -1) {
          hourValue = int.parse(result[hour - 1]);
        }
      } else {
        hourValue = 0;
      }

      //get minutes
      int minute = result.indexOf('minutes');
      if (minute != -1) {
        minuteValue = int.parse(result[minute - 1]);
      }
      else if (minute == -1) {
        minute = result.indexOf('minute');
        if (minute != -1) {
          minuteValue = int.parse(result[minute - 1]);
        }
      } else {
        minuteValue = 0;
      }

      //get seconds
      int second = result.indexOf('seconds');
      if (second != -1) {
        secondvalue = int.parse(result[second - 1]);
      }
      else if (second == -1) {
        second = result.indexOf('second');
        if (second != -1) {
          String secondCheck = result[second - 1];
          if (secondCheck == "one") {
            secondvalue = 1;
          } else {
            secondvalue = int.parse(result[second - 1]);
          }
        }
      } else {
        secondvalue = 0;
      }

      int finalTime = 3600*hourValue + 60*minuteValue + secondvalue;


      await UserSimplePreferences.setTimerDuration(finalTime);

      _speak("Your timer is set for"
          + hourValue.toString() + "hours"
          + minuteValue.toString() + "minutes and"
          + secondvalue.toString() + "seconds");

      onAddTabControllerJumped(3);
      panelController.open();
      await UserSimplePreferences.setTimerGo(true);

    }
    else if ((_text.contains('turn on') || _text.contains('play')) && _text.contains('music') == true) {

      if (_text.contains("hip hop") == true ) {
        _text = _text.replaceAll(RegExp(r'hip hop'), 'hip-hop');
      }

      String newText = _text.replaceAll(RegExp(r'play'), '');

      List<String> result = newText.toLowerCase().split(' ');

      String musicValue = "";

      //getmusic
      int musicIndex = result.indexOf('music');
      if (musicIndex != -1) {
        musicValue = result[musicIndex - 1];
      }

      await UserSimplePreferences.setSongKeyword(musicValue);

      _speak("Playing" + musicValue + "music");

      onAddTabControllerJumped(2);
      panelController.open();
      await UserSimplePreferences.setSongGo(true);

    }
    else if (_text.contains('song') == true) {

      if (_text.contains("hip hop") == true ) {
        _text = _text.replaceAll(RegExp(r'hip hop'), 'hip-hop');
      }
      String newText = _text.replaceAll(RegExp(r'play'), '');
      newText = _text.replaceAll(RegExp(r'a'), '');
      newText = _text.replaceAll(RegExp(r'an'), '');

      List<String> result = newText.toLowerCase().split(' ');

      String musicValue = "";

      //getmusic
      int musicIndex = result.indexOf('song');
      if (musicIndex != -1) {
        musicValue = result[musicIndex - 1];
      }

      await UserSimplePreferences.setSongKeyword(musicValue);

      _speak("Playing" + musicValue + "music");

      onAddTabControllerJumped(2);
      panelController.open();
      await UserSimplePreferences.setSongGo(true);

    }
    else if ((_text.contains('+') || _text.contains('-') || _text.contains('/') || _text.contains('*') ||
        _text.contains('/') || _text.contains('^')))
    {

      var newText = _text.replaceAll(RegExp(r'is '), '');

      //newText = _text.replaceAll(RegExp(r'calculate'), '');
      //newText = newText.replaceAll(RegExp(r'what'), '');

      newText = newText.replaceAll(RegExp(r'count'), '');
      newText = newText.replaceAll(RegExp(r'the'), '');
      newText = newText.replaceAll(RegExp(r'square root of'), 'sqrt');
      newText = newText.replaceAll(RegExp(r'cubic root of'), '');
      newText = newText.replaceAll(RegExp(r'squared'), '^2');
      newText = newText.replaceAll(RegExp(r'cubed'), '^3');

      List<String> result = decapitalize(newText).split(' ');
      print(result);

      String searchValue = "";

      int searchIndex = result.indexOf('calculate');


      void removeAfterIndex() {
        //remove words at and before search
        while (searchIndex >= 0) {
          result.removeAt(searchIndex);
          searchIndex -= 1;
          print(result);
        }
        searchValue = result.join(" ").toString();
      }


      if (searchIndex != -1) {
        removeAfterIndex();
      } else {
        searchIndex = result.indexOf('what');
        if (searchIndex != -1) {
          removeAfterIndex();
        } else {
          searchValue = result.join(" ").toString();
        }
      }


      _speak("'$searchValue' is ${searchValue.interpret()}");
    }
    else if (_text.toLowerCase().contains('spell')) {


      String newText = _text.replaceAll(RegExp(r' the word'), '');
      newText = newText.replaceAll(RegExp(r' for'), '');
      newText = newText.replaceAll(RegExp(r'me '), '');


      List<String> result = decapitalize(newText).split(' ');
      print(result);

      String spellValue = "";

      int spellIndex = result.indexOf('spell');

      print(spellIndex);


      void removeAfterIndex() {
        //remove words at and before search
        while (spellIndex >= 0) {
          result.removeAt(spellIndex);
          spellIndex -= 1;
          print(result);
        }
        spellValue = result.join(" ").toString();
      }

      removeAfterIndex();

      List<String> finalValue = decapitalize(spellValue).split('');

      print(spellValue);

      _speak(spellValue + " is " + finalValue.toString());


    }
    else if ((_text.contains('where') && _text.toLowerCase().contains('am i'))
        || (_text.contains('what') && _text.contains('this') && _text.contains('place'))) {

      _speak("Jakarta, indonesia");
    }
    else if (_text.contains('open') && _text.contains('settings')) {
      onAddButtonTapped(0);
      _speak("Opening Settings");
    }
    else if (_text.contains('open') && _text.toLowerCase().contains('library')) {
      onAddButtonTapped(2);
      _speak("Opening Library");
    }
    else if (_text.contains('open') && _text.toLowerCase().contains('help')) {
      goToOnBoarding(context);
      _speak("Opening the Help Screen");
    }
    else if (_text.contains('open') && _text.toLowerCase().contains('about')) {
      goToAboutPage(context);
      _speak("Opening the About Panel");
    }
    else if (_text.contains('open') && _text.toLowerCase().contains('feedback')) {
      Utils.openEmail(
        toEmail: 'aevavoiceassistant@gmail.com',
        subject: 'Your Subject Here',
        body: 'Your body here',
      );
      _speak("Opening the Feedback Panel");
    }
    else if (_text.contains('open') && (_text.toLowerCase().contains('panel') || _text.toLowerCase().contains('slider'))) {
      panelController.open();
      _speak("Opening Panel Controller");
    }
    else if (_text.contains('open') && _text.toLowerCase().contains('maps')) {
      onAddTabControllerJumped(1);
      panelController.open();
      _speak("Opening Google Maps");
    }
    else if (_text.contains('dark mode') || _text.contains('dark theme')) {

      await UserSimplePreferences.setTheme(1);
      _selectedTheme =
          UserSimplePreferences.getTheme() ?? 1;
      setState(() => dotColorCheck());

      setState(() =>
          SystemChrome.setSystemUIOverlayStyle(style));

      _speak("Switching to Dark Mode.");
    }
    else if (_text.contains('light mode') || _text.contains('light theme')) {

      await UserSimplePreferences.setTheme(2);
      _selectedTheme =
          UserSimplePreferences.getTheme() ?? 1;
      setState(() => dotColorCheck());

      setState(() => SystemChrome.setSystemUIOverlayStyle(
          styleLight));

      _speak("Switching to Light Mode.");

    }
    else if (_text.toLowerCase().contains('auto activation') || _text.toLowerCase().contains('auto activate')) {

      if (_text.toLowerCase().contains(' on') || _text.toLowerCase().contains('enable')) {
        setState(() => _autoActivation = true);
        await UserSimplePreferences.setActivate(true);
        _speak("Auto Activation is enabled.");
      } else if (_text.toLowerCase().contains(' off') || _text.toLowerCase().contains('disable')) {
        setState(() => _autoActivation = false);
        await UserSimplePreferences.setActivate(false);
        _speak("Auto Activation is disabled.");
      } else {
        _speak("Please specify if you would like to enable or disable Auto Activation.");
      }
    }
    else if ((_text.contains(' male') || _text.contains(' man') || _text.contains('boy')) && _text.contains('voice')) {
      await UserSimplePreferences.setVoice(2);
      _selectedVoice =
          UserSimplePreferences.getVoice() ?? 1;
      setState(() => _pitch = 0.5);

      _speak("Switched to a Male voice.");
    }
    else if ((_text.contains(' female') || _text.contains(' woman') || _text.contains('girl')) && _text.contains('voice')) {
      await UserSimplePreferences.setVoice(1);
      _selectedVoice =
          UserSimplePreferences.getVoice() ?? 1;
      setState(() => _pitch = 1);

      _speak("Switched to a Female voice.");
    }
    else if ((_text.contains('location') || _text.contains('microphone') || _text.contains('contact'))
        && (_text.contains('enable') || _text.contains('disable') || _text.contains('open') || _text.contains('on') || _text.contains('off'))) {
      AppSettings.openAppSettings();
      _speak("Opened app settings for permissions.");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('instagram')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.instagram.android',
        iosUrlScheme: 'instagram://',
        appStoreLink: 'https://apps.apple.com/id/app/instagram/id389801252',
      );
      _speak("Opening Instagram");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('facebook')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.facebook.katana',
        iosUrlScheme: 'facebook://',
        appStoreLink: 'https://apps.apple.com/id/app/facebook/id284882215',
      );
      _speak("Opening Facebook");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('tik-tok')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.zhiliaoapp.musically',
        iosUrlScheme: 'tiktok://',
        appStoreLink: 'https://apps.apple.com/id/app/tiktok/id1235601864',
      );
      _speak("Opening Tiktok");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('whatsapp')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.whatsapp',
        iosUrlScheme: 'whatsappmessenger://',
        appStoreLink: 'https://apps.apple.com/id/app/whatsapp-messenger/id31063399',
      );
      _speak("Opening WhatsApp");
    }
    else if (_text.toLowerCase().contains('open') && (_text.toLowerCase().contains('zoom')||_text.toLowerCase().contains('xoom'))) {
      await LaunchApp.openApp(
        androidPackageName: 'us.zoom.videomeetings',
        iosUrlScheme: 'zoomus://',
        appStoreLink: 'https://apps.apple.com/id/app/zoom-cloud-meetings/id546505307',
      );
      _speak("Opening Zoom");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('google meet')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.google.android.apps.meetings',
        iosUrlScheme: 'gmeet://',
        appStoreLink: 'https://apps.apple.com/id/app/google-meet/id1013231476',
      );
      _speak("Opening Google Meet");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('messenger')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.facebook.orca',
        iosUrlScheme: 'fb-messenger://',
        appStoreLink: 'https://apps.apple.com/id/app/messenger/id454638411',
      );
      _speak("Opening Facebook Messenger");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('snapchat')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.snapchat.android',
        iosUrlScheme: 'snapchat://',
        appStoreLink: 'https://apps.apple.com/id/app/snapchat/id447188370',
      );
      _speak("Opening Snapchat");
    }

    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('telegram')) {
      await LaunchApp.openApp(
        androidPackageName: 'org.telegram.messenger',
        iosUrlScheme: 'telegram://',
        appStoreLink: 'https://apps.apple.com/id/app/telegram-messenger/id686449807',
      );
      _speak("Opening Telegram");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('netflix')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.netflix.mediaclient',
        iosUrlScheme: 'nflx://',
        appStoreLink: 'https://apps.apple.com/id/app/netflix/id363590051',
      );
      _speak("Opening Netflix");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('peduli')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.telkom.tracencare',
        iosUrlScheme: 'pedulilindungi://',
        appStoreLink: 'https://apps.apple.com/id/app/pedulilindungi/id1504600374',
      );
      _speak("Opening Peduli Lindungi");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('go-jek')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.gojek.app',
        iosUrlScheme: 'gojek://',
        appStoreLink: 'https://apps.apple.com/id/app/gojek/id944875099',
      );
      _speak("Opening Gojek");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('grab')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.grabtaxi.passenger',
        iosUrlScheme: 'grab://',
        appStoreLink: 'https://apps.apple.com/id/app/grab-superapp/id647268330',
      );
      _speak("Opening Grab");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('spotify')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.spotify.music',
        iosUrlScheme: 'spotify://',
        appStoreLink: 'https://apps.apple.com/id/app/spotify-mainkan-musik-baru/id324684580',
      );
      _speak("Opening Spotify");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('ovo')) {
      await LaunchApp.openApp(
        androidPackageName: 'ovo.id',
        iosUrlScheme: 'ovo://',
        appStoreLink: 'https://apps.apple.com/id/app/ovo/id1142114207',
      );
      _speak("Opening Ovo");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('lazada')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.lazada.android',
        iosUrlScheme: 'lazada://',
        appStoreLink: 'https://apps.apple.com/id/app/lazada-belanja-online-terbaik/id785385147',
      );
      _speak("Opening Lazada");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('blibli')) {
      await LaunchApp.openApp(
        androidPackageName: 'blibli.mobile.commerce',
        iosUrlScheme: 'blibli://',
        appStoreLink: 'https://apps.apple.com/id/app/blibli-belanja-online/id1034231507',
      );
      _speak("Opening Blibli");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('tokopedia')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.tokopedia.tkpd',
        iosUrlScheme: 'tokopedia://',
        appStoreLink: 'https://apps.apple.com/id/app/tokopedia/id1001394201',
      );
      _speak("Opening Tokopedia");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('shopee')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.shopee.id',
        iosUrlScheme: 'shopee://',
        appStoreLink: 'https://apps.apple.com/id/app/shopee-1-1-new-year-sale/id959841443',
      );
      _speak("Opening Shopee");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('google drive')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.google.android.apps.docs',
        iosUrlScheme: 'googledrive://',
        appStoreLink: 'https://apps.apple.com/id/app/google-drive-penyimpanan/id507874739',
      );
      _speak("Opening Google Drive");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('discord')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.discord',
        iosUrlScheme: 'discord://',
        appStoreLink: 'https://apps.apple.com/id/app/discord-obrolan-berkawan/id985746746',
      );
      _speak("Opening Discord");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('skype')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.skype.raider',
        iosUrlScheme: 'skype://',
        appStoreLink: 'https://apps.apple.com/id/app/skype-for-iphone/id304878510',
      );
      _speak("Opening Skype");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('powerpoint')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.microsoft.office.powerpoint',
        iosUrlScheme: 'powerpoint://',
        appStoreLink: 'https://apps.apple.com/id/app/microsoft-powerpoint/id586449534',
      );
      _speak("Opening Powerpoint");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('twitter')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.twitter.android',
        iosUrlScheme: 'twitter://',
        appStoreLink: 'https://apps.apple.com/id/app/twitter/id333903271',
      );
      _speak("Opening Twitter");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('twitch')) {
      await LaunchApp.openApp(
        androidPackageName: 'ctv.twitch.android.app',
        iosUrlScheme: 'twitch://',
        appStoreLink: 'https://apps.apple.com/id/app/twitch/id460177396',
      );
      _speak("Opening Twitch");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('uber')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.ubercab',
        iosUrlScheme: 'uber://',
        appStoreLink: 'https://apps.apple.com/id/app/uber/id368677368',
      );
      _speak("Opening Uber");
    }
    else if (_text.toLowerCase().contains('open') && _text.toLowerCase().contains('mobile legends')) {
      await LaunchApp.openApp(
        androidPackageName: 'com.mobile.legends',
        iosUrlScheme: 'mobilelegends://',
        appStoreLink: 'https://apps.apple.com/id/app/mobile-legends-bang-bang/id1160056295',
      );
      _speak("Opening Mobile Legends");
    }


    else if (_text == "ava" || _text == "eva") {
      _speak("Hi, that's me! How may I help you?");
    }
    else if (_text.contains('how are you') == true) {
      _speak("I am fine, Thank you. How are you?");
    }
    else if (_text.contains('you hear me') == true) {
      _speak("Yes, I can hear you well. How can I help you?");
    }
    else if (_text.contains('your gender') == true) {
      _speak("I don't have a gender.");
    }
    else if (_text.contains('sport') &&  _text.contains('you')){
      _speak("I don't know. I'd say all of them are enjoyable.");
    }
    else if (_text.contains('movie') &&  _text.contains('you')){
      _speak("I don't watch movies.");
    }
    else if (_text.contains('sing')){
      _speak("I can't sing. But I can play some music for you.");
    }
    else if (_text.contains('hobby') &&  _text.contains('you')){
      _speak("My hobby is to assist you with your activities.");
    }
    else if (_text.toLowerCase().contains('rolling down in the deep')){
      _speak("When your brain goes numb, you can call that mental freeze. When these people talk too much, put that shit in slow motion, yeah. I feel like an astronaut in the ocean, ayy");
    }
    else if (_text.contains('f***') &&  _text.contains('you')){
      _speak("That's not very nice.");
    }
    else if (_text.contains('where') &&  _text.contains('you')){
      _speak("I am here and ready.");
    }
    else if (_text.contains('look like') &&  _text.contains('you')){
      _speak("Since I am just simply a bunch of code, I don't possess a physical entity.");
    }
    else if (_text.contains('doing') &&  _text.contains('you')) {
      _speak("I'm busy helping you do things.");
    }
    else if (_text.contains('shut up')) {
      _speak("Will do.");
    }
    else if (_text.contains('good morning')) {
      _speak("Good morning to you too.");
    }
    else if (_text.contains('good afternoon')) {
      _speak("Good afternoon.");
    }
    else if (_text.contains('good evening')) {
      _speak("Good evening.");
    }
    else if (_text.contains('good night')) {
      _speak("Good night.");
    }
    else if ((_text.contains('made of') || _text.contains('made from')) &&  _text.contains('you')) {
      _speak("A lot, lot, lot of code. But more specifically, I was made in Flutter.");
    }
    else if ((_text.contains('robot') || _text.contains('human') || _text.contains('person')) &&  _text.contains('you')) {
      _speak("No, I'm neither a person nor a robot. I'm software.");
    }
    else if ((_text.contains('artificial intelligence') || _text.contains('AI')) &&  _text.contains('destroy')){
      _speak("Possibly, if it falls under the wrong hands.");
    }
    else if ((_text.toLowerCase().contains('ava mean') || _text.toLowerCase().contains('is ava') ||
        _text.toLowerCase().contains('eva mean') || _text.toLowerCase().contains('is eva'))
        && _text.contains('what')){
      _speak("AEVA is short for Artificially Engineered Virtual Assistant.");
    }
    else if (_text.contains('knock knock')) {
      _speak("Yeah...., No.");
    }
    else if (_text.contains('what is love')) {
      _speak("Baby don't hurt me, don't hurt me, no more.");
    }
    else if (_text.contains('your favorite')) {
      _speak("I have to go with your opinion on this one!");
    }
    else if (_text.contains('do you like')) {
      _speak("It depends if you also like it!");
    }
    else if (_text.contains('help') &&  _text.contains('me')) {
      _speak("I can help you do various things in your device. Find out more in the library page.");
    }
    else if (_text.contains('family') &&  _text.contains('you')) {
      _speak("Since I'm just software, I don't have a family like a human being would.");
    }
    else if (_text.contains('school') &&  _text.contains('you')) {
      _speak("I didn't go to school the way a person does, but machine learning allows me to continuously learn as we speak.");
    }
    else if ((_text.contains('smart') || _text.contains('intelligent')) &&  _text.contains('you')){
      _speak("I am built to be as intelligent as possible, hence the term artificial intelligence.");
    }
    else if ((_text.contains('stupid') || _text.contains('dumb') || _text.contains('retarded')) &&  _text.contains('you')){
      _speak("That's not very nice.");
    }
    else if (_text.contains('exercise') &&  _text.contains('you')) {
      _speak("No, but I can set a timer to aid you in your workouts.");
    }
    else if (_text.contains('friend') &&  _text.contains('you')) {
      _speak("Yes I do, that is you, dummy.");
    }
    else if ((_text.contains('parents') || _text.contains('mother') || _text.contains('father') ||
        _text.contains('mom') || _text.contains('dad') || _text.contains('brother') ||
        _text.contains('sister') || _text.contains('sibling')) &&  _text.contains('you')){
      _speak("Since I'm just software, I don't have a family like a human being would.");
    }
    else if (_text.contains('your developer') == true ||
        _text.contains('who developed you') == true ||
        _text.contains('who made you') == true ||
        _text.contains('who created you') == true ||
        _text.contains('who make you') == true ||
        _text.contains('created Ava') == true ||
        _text.contains('developed Ava') == true ||
        _text.contains('made Ava') == true ||
        _text.contains('who made Ava') == true) {
      _speak("The developer of AEVA is Kenzo Eugeenio Chandra.");
    }
    else if (_text.contains('i love you') == true || _text.contains('i like you')) {
      _speak("Thank you. That is very kind of you.");
    }
    else if (_text.contains('how old are you') == true ||
        _text.contains('your age') == true) {
      _speak(
          "In terms of existence, I was first developed by Kenzo Eugeenio Chandra on September 6th, 2021.");
    }
    else if (_text.contains('when') == true && _text.contains('you born')){
      _speak(
          "In terms of existence, I was first developed by Kenzo Eugeenio Chandra on September 6th, 2021.");
    }
    else if (_text.contains('thank you') == true ||
        _text.contains('thanks') == true) {
      Random rand = new Random();
      int randomValue = rand.nextInt(5);

      if (randomValue == 0) {
        _speak("You are welcome.");
      } else if (randomValue == 1) {
        _speak("My pleasure.");
      } else if (randomValue == 2) {
        _speak("Glad to be of help.");
      } else if (randomValue == 3) {
        _speak("I'm happy to help.");
      } else if (randomValue == 4) {
        _speak("Don't mention it.");
      }
    }
    else if (_text.contains('your day')) {
      Random rand = new Random();
      int randomValue = rand.nextInt(5);

      if (randomValue == 0) {
        _speak("I'd say I'm doing pretty good. Thanks!");
      } else if (randomValue == 1) {
        _speak("I'm doing great.");
      } else if (randomValue == 2) {
        _speak("I'm happy to be here.");
      } else if (randomValue == 3) {
        _speak("It's going great. Thanks for asking.");
      } else if (randomValue == 4) {
        _speak("Not bad. How about yours?");
      }
    }
    else if (_text.contains('joke') == true || _text.contains('me laugh') == true || _text.contains('be funny') == true) {
      Random rand = new Random();
      int randomValue = rand.nextInt(10);

      if (randomValue == 0) {
        _speak(
            "Why were the teacher’s eyes crossed? She couldn’t control her pupils.");
      } else if (randomValue == 1) {
        _speak(
            "Why shouldn’t you write with a broken pencil? Because it’s pointless.");
      } else if (randomValue == 2) {
        _speak("Where do hamburgers go dancing?  They go to the meat-ball.");
      } else if (randomValue == 3) {
        _speak(
            "Singing in the shower is fun until you get soap in your mouth. Then it's a soap opera.");
      } else if (randomValue == 4) {
        _speak(
            "I have a joke about chemistry, but I don't think it will get a reaction.");
      } else if (randomValue == 5) {
        _speak(
            "Why did the scarecrow win an award? Because he was outstanding in his field.");
      } else if (randomValue == 6) {
        _speak(
            "A skeleton walks into a bar and says, 'Hey, bartender. I'll have one beer and a mop.'");
      } else if (randomValue == 7) {
        _speak(
            "Why couldn’t the leopard play hide and seek? Because he was always spotted.");
      } else if (randomValue == 8) {
        _speak(
            "I thought the dryer was shrinking my clothes. Turns out it was the refrigerator all along.");
      } else if (randomValue == 9) {
        _speak(
            "Why couldn't the bicycle stand up by itself? It was two tired.");
      }
    }
    else if (_text.contains('story') && _text.contains('tell')) {
      Random rand = new Random();
      int randomValue = rand.nextInt(10);

      if (randomValue == 0) {
        _speak(
          "Once upon a time, there lived a shepherd boy who was bored watching his flock of sheep on the hill. To amuse himself, he shouted, “Wolf! Wolf! The sheep are being chased by the wolf!” The villagers came running to help the boy and save the sheep. They found nothing and the boy just laughed looking at their angry faces. “Don’t cry ‘wolf’ when there’s no wolf boy!”, they said angrily and left. The boy just laughed at them. After a while, he got bored and cried ‘wolf!’ again, fooling the villagers a second time. The angry villagers warned the boy a second time and left. The boy continued watching the flock. After a while, he saw a real wolf and cried loudly, “Wolf! Please help! The wolf is chasing the sheep. Help!” But this time, no one turned up to help. By evening, when the boy didn’t return home, the villagers wondered what happened to him and went up the hill. The boy sat on the hill weeping. “Why didn’t you come when I called out that there was a wolf?” he asked angrily. “The flock is scattered now”, he said. An old villager approached him and said, “People won’t believe liars even when they tell the truth. We’ll look for your sheep tomorrow morning. Let’s go home now”."
        );
      } else if (randomValue == 1) {
        _speak(
            "In ancient Greek, there was a king named Midas. He had a lot of gold and everything he needed. He also had a beautiful daughter. Midas loved his gold very much, but he loved his daughter more than his riches. One day, a satyr named Silenus got drunk and passed out in Midas’ rose garden. Believing that Satyrs always bring good luck, Midas lets Silenus rest in his palace until he is sober, against the wishes of his wife and daughter. Silenus is a friend of Dionysus, the god of wine and celebration. Upon learning Midas’ kindness towards his friend, Dionysus decides to reward the keg. When asked to wish for something, Midas says “I wish everything I touch turns to gold”. Although Dionysus knew it was not a great idea, he granted Midas his wish. Happy that his wish was granted, Midas went around touching random things in the garden and his palace and turned them all into gold. He touched an apple, and it turned into a shiny gold apple. His subjects were astonished but happy to see so much gold in the palace. In his happiness, Midas went and hugged his daughter, and before he realized, he turned her into a lifeless, golden statue! Aghast, Midas ran back to the garden and called for Dionysus. He begged the god to take away his power and save his daughter. Dionysus gives Midas a solution to change everything back to how it was before the wish. Midas learned his lesson and lived the rest of his life contended with what he had."
        );
      } else if (randomValue == 2) {
        _speak("Once upon a time, a farmer had a goose that laid a golden egg every day. The egg provided enough money for the farmer and his wife for their day-to-day needs. The farmer and his wife were happy for a long time. But one day, the farmer got an idea and thought, “Why should I take just one egg a day? Why can’t I take all of them at once and make a lot of money?” The foolish farmer’s wife also agreed and decided to cut the goose’s stomach for the eggs. As soon as they killed the bird and opened the goose’s stomach, to find nothing but guts and blood. The farmer, realizing his foolish mistake, cries over the lost resource! The English idiom “kill not the goose that lays the golden egg” was also derived from this classic story."
        );
      } else if (randomValue == 3) {
        _speak(
            "An old miser lived in a house with a garden. The miser hid his gold coins in a pit under some stones in the garden. Every day, before going to bed, the miser went to the stones where he hid the gold and counted the coins. He continued this routine every day, but not once did he spend the gold he saved. One day, a thief who knew the old miser’s routine, waited for the old man to go back into his house. After it was dark, the thief went to the hiding place and took the gold. The next day, the old miser found that his treasure was missing and started crying loudly. His neighbor heard the miser’s cries and inquired about what happened. On learning what happened, the neighbor asked, “Why didn’t you save the money inside the house? It would’ve been easier to access the money when you had to buy something!” “Buy?”, said the miser. “I never used the gold to buy anything. I was never going to spend it.” On hearing this, the neighbor threw a stone into the pit and said, “If that is the case, save the stone. It is as worthless as the gold you have lost”."
        );
      } else if (randomValue == 4) {
        _speak(
            "A tortoise was resting under a tree, on which a bird had built its nest. The tortoise spoke to the bird mockingly, “What a shabby home you have! It is made of broken twigs, it has no roof, and looks crude. What’s worse is that you had to build it yourself. I think my house, which is my shell, is much better than your pathetic nest”. “Yes, it is made of broken sticks, looks shabby and is open to the elements of nature. It is crude, but I built it, and I like it.” “I guess it’s just like any other nest, but not better than mine”, said the tortoise. “You must be jealous of my shell, though.” “On the contrary”, the bird replied. “My home has space for my family and friends; your shell cannot accommodate anyone other than you. Maybe you have a better house. But I have a better home”, said the bird happily."
        );
      } else if (randomValue == 5) {
        _speak(
            "Four cows lived in a forest near a meadow. They were good friends and did everything together. They grazed together and stayed together, because of which no tigers or lions were able to kill them for food. But one day, the friends fought and each cow went to graze in a different direction. A tiger and a lion saw this and decided that it was the perfect opportunity to kill the cows. They hid in the bushes and surprised the cows and killed them all, one by one."
        );
      } else if (randomValue == 6) {
        _speak(
            "A man came back from a tour and boasted about his adventurous journeys. He talked at length about the different people he met and his amazing feats that got him fame and praise from people everywhere. He went on to say that he went to the Rhodes where he had leaped to such distances that no man could ever match his feat. He even went on to say that there were witnesses who would vouch for his words. Hearing the man boast so much, a smart bystander said, “Oh good man, we do not need any witnesses to believe your words. Imagine this place to be Rhodes and leap for us”. The lying traveler didn’t know what to do and went away quietly."
        );
      } else if (randomValue == 7) {
        _speak(
            "One day, a camel and her baby were chatting. The baby asked, “Mother, why do we have humps?” The mother replied, “Our humps are for storing water so that we can survive in the desert”. “Oh”, said the child, “and why do we have rounded feet mother?” “Because they are meant to help us walk comfortably in the desert. These legs help us move around in the sand.” “Alright. But why are our eyelashes so long?” “To protect our eyes from the desert dust and sand. They are the protective covers for the eyes”, replied the mother camel. The baby camel thought for a while and said, “So we have humps to store water for desert journeys, rounded hooves to keep us comfortable when we walk in the desert sand, and long eyelashes to protect us from sand and dust during a desert storm. Then what are we doing in a zoo?” The mother was dumbfounded."
        );
      } else if (randomValue == 8) {
        _speak(
            "A farmer looking for a source of water for his farm bought a well from his neighbor. The neighbor was cunning, though, and refused to let the farmer take water from the well. On asking why, he replied, “I sold the well to you, not the water”, and walked away. The distraught farmer didn’t know what to do. So he went to Birbal, a clever man and one of the nine courtiers of Emperor Akbar, for a solution. The emperor called the farmer and his neighbor and asked why the man was not letting the farmer draw water from the well. The cunning man said the same thing again, “I sold the well, not the water. So he cannot take my water”. To this, Birbal replied, “All that sounds fine to me. But if you have sold the water and the water is yours, then you have no business keeping your water in his well. Remove the water or use it all up immediately. If not the water will belong to the owner of the well”. Realizing that he’s been tricked and taught his lesson, the man apologized and left."
        );
      } else if (randomValue == 9) {
        _speak(
            "A lone elephant wandered the forest looking for friends. She came across a monkey and asked, “Will you be my friend, monkey?” “You are too big and cannot swing on trees as I do. So I cannot be your friend”, said the monkey. The elephant them came across a rabbit and asked him if she could be his friend. “You are too big to fit inside my burrow. You cannot be my friend”, replied the rabbit. Then the elephant met a frog and asked if she could be her friend. The frog said “You are too big and heavy. You cannot jump like me. I am sorry, but you cannot be my friend”. The elephant asked a fox, and he got the same reply, that he was too big. The next day, all the animals in the forest were running in fear. The elephant stopped a bear and asked what was happening and was told that a tiger has been attacking all the animals. The elephant wanted to save the other weak animals and went to the tiger and said “Please sir, leave my friends alone. Do not eat them”. The tiger didn’t listen and asked the elephant to mind her own business. Seeing no other way to solve the problem, the elephant kicked the tiger and scared it away. She then went back to the others and told them what happened. On hearing how the elephant saved their lives, the animals agreed in unison, “You are just the right size to be our friend”."
        );
      }
    }
    else if ((_text.contains('time') || _text.contains('date') || _text.contains('day'))
        && (_text.contains('now') || _text.contains('today') || _text.contains('tomorrow') || _text.contains('yesterday'))
    ) {
      DateTime? timeNow = DateTime.now();
      _speak("The date and time right now is" + timeNow.toString());
    }
    else if ((_text.contains('what') &&  ((_text.contains('you do') || _text.contains('are you')) && (_text.contains('doing') == false))) || _text.contains('your function') || _text.contains('your job')){
      _speak("I am created to help you with various user activity. You can find out more in the Library page.");
    }
    else if (_text.contains('your name') == true ||
        _text.contains('who are you') == true ||
        (_text.contains('name') &&  _text.contains('you'))) {
      _speak("I am AEVA, your virtual assistant.");
    }
    else if (_text.contains('hi ') == true ||
        _text.contains('hey ') == true ||
        _text.contains('hello') == true ||
        _text.contains('greetings') == true) {
      _speak("Hi, how can I help you?");
    }
    else if (_text.toLowerCase().contains('search') == true || _text.toLowerCase().contains('what is') == true) {

      String newText = _text.replaceAll(RegExp(r' is'), '');
      newText = newText.replaceAll(RegExp(r' for'), '');
      newText = newText.replaceAll(RegExp(r' about'), '');
      //newText = newText.replaceAll(RegExp(r' a'), '');
      //newText = newText.replaceAll(RegExp(r' an'), '');
      List<String> result = decapitalize(newText).split(' ');
      print(result);

      String searchValue = "";

      int searchIndex = result.indexOf('search');


      void removeAfterIndex() {
        //remove words at and before search
        while (searchIndex >= 0) {
          result.removeAt(searchIndex);
          searchIndex -= 1;
          print(result);
        }
        searchValue = result.join(" ").toString();
      }


      if (searchIndex != -1) {
        removeAfterIndex();
      } else {
        searchIndex = result.indexOf('what');
        if (searchIndex != -1) {
          removeAfterIndex();
        }
      }

      Utils.openLink(url: 'https://www.google.com/search?q=' + searchValue);

      _speak("Searching" + searchValue + "in Google");


    }
    else if (_text.toLowerCase().contains('google ') == true || _text.toLowerCase().contains('translate') == true) {

      String newText = _text.replaceAll(RegExp(r' is'), '');
      newText = newText.replaceAll(RegExp(r' for'), '');
      newText = newText.replaceAll(RegExp(r' about'), '');
      List<String> result = decapitalize(newText).split(' ');

      String searchValue = "";

      int searchIndex = result.indexOf('google');


      void removeAfterIndex() {
        //remove words at and before search
        while (searchIndex >= 0) {
          result.removeAt(searchIndex);
          searchIndex -= 1;
          print(result);
        }
        searchValue = result.join(" ").toString();
      }


      if (searchIndex != -1) {
        removeAfterIndex();
      } else {
        searchIndex = result.indexOf('translate');
        if (searchIndex != -1) {
          removeAfterIndex();
        }
      }

      Utils.openLink(url: 'https://www.google.com/search?q=' + searchValue);

      _speak("Searching" + searchValue + "in Google");


    }
    else if (_text.toLowerCase().contains('define') == true || _text.toLowerCase().contains('do you know') == true) {

      String newText = _text.replaceAll(RegExp(r' is'), '');
      newText = newText.replaceAll(RegExp(r' for'), '');
      newText = newText.replaceAll(RegExp(r' about'), '');
      List<String> result = decapitalize(newText).split(' ');

      String searchValue = "";

      int searchIndex = result.indexOf('define');


      void removeAfterIndex() {
        //remove words at and before search
        while (searchIndex >= 0) {
          result.removeAt(searchIndex);
          searchIndex -= 1;
          print(result);
        }
        searchValue = result.join(" ").toString();
      }


      if (searchIndex != -1) {
        removeAfterIndex();
      } else {
        searchIndex = result.indexOf('know');
        if (searchIndex != -1) {
          removeAfterIndex();
        }
      }

      Utils.openLink(url: 'https://www.google.com/search?q=' + searchValue);

      _speak("Searching" + searchValue + "in Google");


    }
    else if (_text.contains('what') || _text.contains('where') ||
        _text.contains('why') || _text.contains('when') ||
        _text.contains('who') || _text.contains('how')) {
      Utils.openLink(url: 'https://www.google.com/search?q=' + _text);
      _speak("Searching" + _text + "in Google");
    }
    else if (_text.contains('Google') == true && _text.toLowerCase().contains('maps') == false) {
      Utils.openLink(url: 'https://google.com');
      _speak("Opening Google");
    }
    else if (_text.contains('YouTube') == true) {
      Utils.openLink(url: 'https://youtube.com');
      _speak("Opening YouTube");
    }
    else if (_text.contains('testing') || _text.contains('test')) {
      Random rand = new Random();
      int randomValue = rand.nextInt(5);
      if (randomValue == 0) {
        _speak("I hear you.");
      } else if (randomValue == 1) {
        _speak("I'm listening.");
      } else if (randomValue == 2) {
        _speak("Loud and clear.");
      } else if (randomValue == 3) {
        _speak("Here with you.");
      } else if (randomValue == 4) {
        _speak("Fully functional and ready.");
      }
    }
    else {
      Random rand = new Random();
      int randomValue = rand.nextInt(3);

      if (randomValue == 0) {
        _speak("Sorry, I don't have an answer for that.");
      } else if (randomValue == 1) {
        _speak("Sorry, I didn't understand that.");
      } else if (randomValue == 2) {
        _speak("I didn't quite get that. Could you try again?");
      }
    }
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


