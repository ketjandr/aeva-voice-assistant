import 'package:flutter/material.dart';
import 'package:aevavoiceassistant/main.dart';
import 'package:aevavoiceassistant/utils/user_simple_preferences.dart';

class AboutPage extends StatelessWidget {

  int? themeSelect =  UserSimplePreferences.getTheme() ?? 1;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: themeSelect == 1 ? Color(0xff121212) : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_left,
            size: 32,
          ),
          onPressed: () =>
              goToHome(context),
        ),
        title: Text(
            "About",
                style: TextStyle(
                  fontSize: 18.0,
                  fontFamily: 'NotoSansBold',
                ),
        ),
        centerTitle: true,
        backgroundColor: themeSelect == 1 ? Color(0xff2e2e36) : Color(0xffffbf00),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, left: 15, right: 15),
          child: SingleChildScrollView(
            child: Theme(
              data: ThemeData(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width/2,
                      height: MediaQuery.of(context).size.width/2,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30.0),
                          image: DecorationImage(
                            image: AssetImage('assets/images/machine_learning.png'),
                          ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      "About AEVA",
                      style: TextStyle(fontSize: 22, color: Color(0xff618bce), fontFamily: "NotoSansBold"),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      "What is AEVA",
                      style: TextStyle(fontSize: 18, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSansBold"),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "The Artificially Engineered Virtual Assistant or “AEVA” is a form of artificial intelligence programmed to virtually assist users in terms of general activity, navigating through their devices, and easing accessibility through installed external programs. With a range of commands available in the built-in library, users are able to interact with the AI through voice recognition that is derived upon Natural Language Input and Natural Language Processing – NLI and NLP semantics. AEVA’s responses are mainly constructed through Machine Learning algorithms that process the user’s command obtained from NLP to output the most suitable response for the convenience of clients and clientele. After refining the acquired response from the user, AEVA would subsequently assist them through virtual means, i.e. basic user activity. ",
                    style: TextStyle(fontSize: 12, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSans"),
                    textAlign: TextAlign.left,
                  ),

                  const SizedBox(height: 28),

                  Text(
                    "Purpose and Intent",
                    style: TextStyle(fontSize: 18, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSansBold"),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Integrating Machine Learning and Natural Language Processing into an artificial intelligence program, and producing the AEVA mobile application was born out of intentions in improving user experience within their mobile devices such that navigation can be achieved more effectively. Through the medium of direct communication with AEVA, accessibility of various functions in the device is pragmatically compassed. AEVA is also configured to compensate user needs and fulfill their satisfactions in terms of general assistance within their device or more simply in starting simple, light-hearted banters or conversations. Furthermore, AEVA would also mark the prominence of inducing simulated machine intelligence through AI – which is a centralized and fundamental aspect of the Fourth Industrial Revolution and beyond.",
                    style: TextStyle(fontSize: 12, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSans"),
                    textAlign: TextAlign.left,
                  ),

                  const SizedBox(height: 28),

                  Text(
                      'Using AEVA',
                      style: TextStyle(fontSize: 18, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSansBold")
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "To use AEVA, enable required permissions embedded within the app settings. Under the usage policy of non-commercial uses only, you would agree that its services are not to be used for commercial or performance monitoring purposes. AEVA’s privacy policy would also feature protection of your information and ensuring that the application’s access to internal services within the mobile device is encrypted and kept private. Moreover, AEVA respects the copyright policy of infringement, including external parties, i.e. clients and other developers. If one would believe to have witnessed a violation in the copyright claim policy of the application, submit your claim through the Feedback" " panel within the “Settings” tab.",
                    style: TextStyle(fontSize: 12, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSans"),
                    textAlign: TextAlign.left,
                  ),

                  const SizedBox(height: 28),

                  Text(
                      'Developer Info',
                      style: TextStyle(fontSize: 18, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSansBold")
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "AEVA was developed and programmed by Kenzo Eugenio Tjandra using the Flutter software development kit – an open source UI-SDK first established by Google LLC, which primarily utilizes Dart – a high-level, interpreted and garbage-collected programming language. As part of the product of the IB MYP Personal Project, this application is also meant to expand Kenzo’s interest in computer science, software engineering, and artificial intelligence. This AI program was first developed since September 6th, 2021, marking the initiation of the product assembly process in the PP.",
                    style: TextStyle(fontSize: 12, color: themeSelect == 1 ? Color(0xffc9c9c9) : Color(0xff575757), fontFamily: "NotoSans"),
                    textAlign: TextAlign.left,
                  ),

                  const SizedBox(height: 30),



                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void goToHome(context) => Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => SpeechScreen()),
  );


}