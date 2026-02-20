import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:aevavoiceassistant/main.dart';
import 'package:aevavoiceassistant/widget/button_widget.dart';
import 'package:aevavoiceassistant/utils/user_simple_preferences.dart';
import 'package:aevavoiceassistant/page/about_page.dart';
import 'package:video_player/video_player.dart';

class OnBoardingPage extends StatefulWidget {
  @override
  OnBoardingState createState() => OnBoardingState();
}

class OnBoardingState extends State<OnBoardingPage> {

  int? themeSelect =  UserSimplePreferences.getTheme() ?? 1;
  /*
  late VideoPlayerController controller;
  final asset = 'lib/assets/AEVA_1.mp4';

   */

  @override
  void initState() {
    super.initState();
    /*
    controller = VideoPlayerController.asset(asset)
      ..addListener(() => setState(() {}))
      ..setLooping(true)
      ..initialize().then((_) => controller.play());

     */
  }
/*
  @override
  void dispose() {
    //controller.dispose();
    super.dispose();
  }

 */

  @override

  Widget build(BuildContext context) => SafeArea(
    child: IntroductionScreen(
      pages: [

        PageViewModel(
          title: 'AEVA the Voice Assistant',
          body: 'An Artificially Engineered Virtual Assistant with Machine Learning AI and Natural Language Processing',
          footer: Container(
            padding: EdgeInsets.only(top: 30),
            child: ButtonWidget(
              text: 'More About AEVA',
              onClicked: () => goToAboutPage(context),
            ),
          ),
          image: themeSelect == 1 ? buildImage('lib/assets/AEVA_1.gif') : buildImage('lib/assets/AEVA_LIGHTMODE_1.gif'),
          decoration: getPageDecoration(),
        ),

        PageViewModel(
          title: 'Tap to Activate',
          body: 'Available right at your fingerprints',
          image: themeSelect == 1 ? buildImage('lib/assets/AEVA_2.gif') : buildImage('lib/assets/AEVA_LIGHTMODE_2.gif'),
          decoration: getPageDecoration(),
        ),
        PageViewModel(
          title: 'Speak and Wait',
          body: 'To generate an appropriate response',
          image: themeSelect == 1 ? buildImage('lib/assets/AEVA_3.gif') : buildImage('lib/assets/AEVA_LIGHTMODE_3.gif'),
          decoration: getPageDecoration(),
        ),
        PageViewModel(
          title: 'AEVA will respond',
          body: 'Based on your command and needs',
          image: themeSelect == 1 ? buildImage('lib/assets/AEVA_4.gif') : buildImage('lib/assets/AEVA_LIGHTMODE_4.gif'),
          decoration: getPageDecoration(),
        ),
        PageViewModel(
          title: 'AEVA will assist you, per any request',
          body: 'Start your journey',

          footer: ButtonWidget(
            text: 'Get Started',
            onClicked: () => goToHome(context),
          ),
          image: buildImageFinal('lib/assets/stock_onboarding.png'),
          decoration: getPageDecoration(),
        ),


      ],
      done: Text('Start', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      onDone: () => goToHome(context),
      showSkipButton: true,
      skip: Text('Skip', style: TextStyle(color: Colors.white),),
      onSkip: () => goToHome(context),
      next: Icon(Icons.arrow_forward),
      dotsDecorator: getDotDecoration(),
      onChange: (index) => print('Page $index selected'),
      globalBackgroundColor: themeSelect == 1 ? Color(0xff121212) : Color(0xffe87800),
      skipFlex: 0,
      nextFlex: 0,
      // isProgressTap: false,
      // isProgress: false,
      // showNextButton: false,
      // freeze: true,
      // animationDuration: 1000,
    ),
  );

  void goToHome(context) => Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => SpeechScreen()),
  );

  void goToAboutPage(context) => Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => AboutPage()),
  );

  Widget buildImage(String path) =>
      Center(
          child: Image.asset(path, fit: BoxFit.cover, width: MediaQuery.of(context).size.width, height: MediaQuery.of(context).size.width,)
      );

  Widget buildImageFinal(String path) =>
      Center(
          child: Image.asset(path, fit: BoxFit.cover, width: MediaQuery.of(context).size.width)
      );

  DotsDecorator getDotDecoration() => DotsDecorator(
    color: Color(0xFFBDBDBD),
    //activeColor: Colors.orange,
    size: Size(10, 10),
    activeSize: Size(22, 10),
    activeShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
  );

  PageDecoration getPageDecoration() => PageDecoration(
    titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
    bodyTextStyle: TextStyle(fontSize: 20, color: Colors.white, height: 1.3),
    descriptionPadding: EdgeInsets.all(16).copyWith(bottom: 0),
    imagePadding: EdgeInsets.only(top: 0),
    pageColor: themeSelect == 1 ? Color(0xff111111): Color(0xffe87800),
    contentMargin: EdgeInsets.only(top: 0),
  );


}