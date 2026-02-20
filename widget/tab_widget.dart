import 'package:aevavoiceassistant/utils/user_simple_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aevavoiceassistant/main.dart';
import 'package:aevavoiceassistant/data/music_data.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_svg/svg.dart';
import 'package:aevavoiceassistant/data/weather_locations.dart';
import 'package:weather/weather.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aevavoiceassistant/utils/directions_model.dart';
import 'package:aevavoiceassistant/utils/directions_repository.dart';
import 'package:aevavoiceassistant/widget/round_button.dart';


class TabWidget extends StatelessWidget {
  const TabWidget({
    Key? key,
    required this.scrollController,
  }) : super(key: key);
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(16),
    controller: scrollController,
    children: [
      Text(
        'Vegetarian cuisine is based on food that meets vegetarian standards by not including meat and animal tissue products. For lacto-ovo vegetarianism, eggs and dairy products are permitted',
        textAlign: TextAlign.center,
      ),
      Container(
        height: 300,
        width: 300,
        child: Image.asset('assets/veg.png'),
      ),
      Text(
          '''1. "Spread love everywhere you go. Let no one ever come to you without leaving happier." -Mother Teresa
2. "When you reach the end of your rope, tie a knot in it and hang on." -Franklin D. Roosevelt
3. "Always remember that you are absolutely unique. Just like everyone else." -Margaret Mead
4. "Don't judge each day by the harvest you reap but by the seeds that you plant." -Robert Louis Stevenson
5. "The future belongs to those who believe in the beauty of their dreams." -Eleanor Roosevelt'''),
    ],
  );
}

class MusicApp extends StatefulWidget {
  @override
  const MusicApp({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  final ScrollController scrollController;

  MusicWidget createState() => MusicWidget();
}

class MusicWidget extends State<MusicApp> {
  @override
  MusicApp get widget => super.widget;

  late ScrollController scrollController;

  bool playing = false;
  IconData playBtn = Icons.play_arrow;

  late AudioPlayer player;
  late AudioCache cache;

  Duration position = new Duration();
  Duration musicLength = new Duration();

  int globalSongIndex = 0;

  String initSongKeyword = UserSimplePreferences.getSongKeyword() ?? "summer";
  bool songGo = UserSimplePreferences.getSongGo() ?? false;


  Widget buildSlider() {
    if (position.inSeconds.toDouble() == null ||
        position.inSeconds.toDouble() > 1.0 ||
        position.inSeconds.toDouble() < 0.0){
      position = Duration(seconds: 0);
    }
    print(position.inSeconds.toDouble());
    return Container(
      width: MediaQuery.of(context).size.width/1.4,
      child: Slider.adaptive(
          activeColor: Colors.blue[800],
          inactiveColor: Colors.grey[350],
          value: position.inSeconds.toDouble(),
          max: musicLength.inSeconds.toDouble(),
          onChanged: (value) {
            seekToSec(value.toInt());
          }),
    );
  }


  @override
  void initState() {
    super.initState();
    scrollController = widget.scrollController;

    player = AudioPlayer();
    cache = AudioCache(fixedPlayer: player);

    player.onDurationChanged.listen((d) {
      setState(() => musicLength = d);
    });

    player.onAudioPositionChanged.listen((p) {
      setState(() => position = p);
    });

    findSong(initSongKeyword);

    if (songGo == true) {
      startPlaying();
    }
  }

  @override
  void dispose() {
    player.stop();
    UserSimplePreferences.setSongGo(false);
    super.dispose();
  }

  void startPlaying() {
    player.play(songList[globalSongIndex].url.toString());
    setState(() {
      playBtn = Icons.pause;
      playing = true;
    });
  }

  void pausePlaying() {
    player.pause();
    setState(() {
      playBtn = Icons.play_arrow;
      playing = false;
    });
  }

  void stopPlaying() {
    player.stop();
    setState(() {
      playBtn = Icons.play_arrow;
      playing = false;
    });
  }

  void seekToSec(int sec) {
    Duration newPos = Duration(seconds: sec);
    player.seek(newPos);
  }

  void findSong(String keyword) {

    int songIndex = 0;

    while (songList[songIndex].title.toString().toLowerCase().contains(keyword) == false &&
        songList[songIndex].artist.toString().toLowerCase().contains(keyword) == false)
    {
      if (songIndex <= songList.length-2) {
        songIndex++;
      } else {
        break;
      }
    }


    String returned = songList[songIndex].title.toString().toLowerCase();
    print(returned);

    setState(() => globalSongIndex = songIndex);
    print(globalSongIndex);


  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: scrollController,
    scrollDirection: Axis.vertical,
    children: [
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue,
                Colors.blueAccent,
              ]),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: 18.0,
          ),
          child: Container(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //Let's add the music cover
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width/2,
                    height: MediaQuery.of(context).size.width/2,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30.0),
                        image: DecorationImage(
                          image: NetworkImage(songList[globalSongIndex].image.toString()), fit: BoxFit.fill,
                        )),
                  ),
                ),

                SizedBox(
                  height: 18.0,
                ),
                Center(
                  child: Text(
                    songList[globalSongIndex].title.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                SizedBox(
                  height: 8.0,
                ),

                Center(
                  child: Text(
                    songList[globalSongIndex].artist.toString(),
                    style: TextStyle(
                      color: Color(0xffbdbdbd),
                      fontSize: 18.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                SizedBox(
                  height: 30.0,
                ),

                Container(
                  height: MediaQuery.of(context).size.height / 5.3,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30.0),
                      topRight: Radius.circular(30.0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              position.inSeconds.remainder(60) < 10
                                  ? "${position.inMinutes}:0${position.inSeconds.remainder(60)}"
                                  : "${position.inMinutes}:${position.inSeconds.remainder(60)}",
                              style: TextStyle(
                                fontSize: 18.0,
                              ),
                            ),
                            buildSlider(),
                            Text(
                              musicLength.inSeconds.remainder(60) < 10
                                  ? "${musicLength.inMinutes}:0${musicLength.inSeconds.remainder(60)}"
                                  : "${musicLength.inMinutes}:${musicLength.inSeconds.remainder(60)}",
                              style: TextStyle(
                                fontSize: 18.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 45.0,
                            color: Colors.blue,
                            onPressed: () {
                              if (position.inSeconds >= 10) {
                                seekToSec(position.inSeconds.toInt() - 10);
                              } else {
                                seekToSec(0);
                              }
                            },
                            icon: Icon(
                              Icons.skip_previous,
                            ),
                          ),
                          IconButton(
                            iconSize: 62.0,
                            color: Colors.blue[800],
                            onPressed: () {
                              //here we will add the functionality of the play button
                              if (!playing) {
                                //now let's play the song
                                //cache.play("sounds/TheFatRat-NeverBeAlone.mp3");
                                player.play(songList[globalSongIndex].url.toString());
                                setState(() {
                                  playBtn = Icons.pause;
                                  playing = true;
                                });
                              } else {
                                pausePlaying();
                              }
                            },
                            icon: Icon(
                              playBtn,
                            ),
                          ),
                          IconButton(
                            iconSize: 45.0,
                            color: Colors.blue,
                            onPressed: () {
                              if (position.inSeconds <=
                                  musicLength.inSeconds - 10) {
                                seekToSec(position.inSeconds.toInt() + 10);
                              } else {
                                seekToSec(musicLength.inSeconds);
                              }
                            },
                            icon: Icon(
                              Icons.skip_next,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class WeatherApp extends StatefulWidget {
  @override
  const WeatherApp({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  final ScrollController scrollController;

  WeatherWidget createState() => WeatherWidget();
}

class WeatherWidget extends State<WeatherApp> {
  @override
  WeatherApp get widget => super.widget;

  late ScrollController scrollController;
  late Weather currentWeather;

  String bgImg = 'images/sunny.jpg';



  Temperature? temperature = Temperature(273);
  double humidity = 0;
  double windSpeed = 0;
  double pressure = 0;
  String? weatherDescription = '';
  DateTime? dateNow = DateTime(0);
  String dateFinal = '';
  String cityNameNow = UserSimplePreferences.getWeatherPlace() ?? "Jakarta";
  String iconUrl = '';
  String weatherNow = '';



  WeatherFactory weatherFactory = new WeatherFactory("733ea65a030833452a13cc85b9d44841", language: Language.ENGLISH);



  @override
  void initState(){
    super.initState();
    scrollController = widget.scrollController;
    findWeather(cityNameNow);
    
  }

  @override
  void dispose() {
    //scrollController.dispose();
    super.dispose();
  }

  void findWeather(String cityName) async {
    currentWeather = await weatherFactory.currentWeatherByCityName(cityName);

    setState(() {
      humidity = currentWeather.humidity!;
      temperature = currentWeather.temperature;
      weatherDescription = currentWeather.weatherDescription;
      windSpeed = currentWeather.windSpeed!;
      pressure = currentWeather.pressure!;
      cityNameNow = cityName;

      dateNow = currentWeather.date ?? DateTime(0);
      DateTime dateNowAfter = dateNow ?? DateTime(0);
      dateFinal = formatISOTime(dateNowAfter);
    });
  }

  static String formatISOTime(DateTime date) {
    var duration = date.timeZoneOffset;
    if (duration.isNegative)
      return (date.toIso8601String() + "-${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes - (duration.inHours * 60)).toString().padLeft(2, '0')}");
    else
      return (date.toIso8601String() + "+${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes - (duration.inHours * 60)).toString().padLeft(2, '0')}");
  }




  @override
  Widget build(BuildContext context) {
    if (weatherDescription?.contains('clear sky') == true) {
      bgImg = 'assets/images/sunny.jpeg';
      iconUrl = 'assets/images/sun.svg';
      weatherNow = 'Clear Sky';
    } else if (weatherDescription?.contains('snow') == true) {
      bgImg = 'assets/images/snow.jpeg';
      iconUrl = 'assets/images/snow.svg';
      weatherNow = 'Snow';
    } else if (weatherDescription?.contains('rain') == true) {
      bgImg = 'assets/images/rainy.jpeg';
      iconUrl = 'assets/images/rain.svg';
      weatherNow = 'Rain';
    } else if (weatherDescription?.contains('thunderstorm') == true) {
      bgImg = 'assets/images/thunderstorm.jpeg';
      iconUrl = 'assets/images/thunderstorm.svg';
      weatherNow = 'Thunderstorm';
    } else if (weatherDescription?.contains('clouds') == true) {
      bgImg = 'assets/images/cloudy.jpeg';
      iconUrl = 'assets/images/cloudy.svg';
      weatherNow = 'Cloudy';
    } else {
      bgImg = 'assets/images/cloudy.jpeg';
      iconUrl = 'assets/images/cloudy.svg';
      weatherNow = 'Cloudy';
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: ListView(
        controller: scrollController,
        children: [
          Container(
            height: MediaQuery.of(context).size.height / 1.4,
            width: MediaQuery.of(context).size.width,
            child: Stack(
              children: [
                Image.asset(
                  bgImg,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  width: double.infinity,
                ),
                Container(
                  decoration: BoxDecoration(color: Colors.black38),
                ),


                Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  cityNameNow.toString(),
                                  style: TextStyle(
                                    fontSize: 35,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  dateFinal.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),


                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  temperature.toString().replaceAll(RegExp(r'Celsius'), '\u2103'),
                                  style: TextStyle(
                                    fontSize: 85,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                  ),
                                ),
                                Row(
                                  children: [
                                    SvgPicture.asset(
                                      iconUrl.toString(),
                                      width: 34,
                                      height: 34,
                                      color: Colors.white,
                                    ),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Text(
                                      weatherNow.toString(),
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 40),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white30,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      'Wind',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      windSpeed.toString(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'km/h',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Stack(
                                      children: [
                                        Container(
                                          height: 5,
                                          width: 50,
                                          color: Colors.white38,
                                        ),
                                        Container(
                                          height: 5,
                                          width:
                                          windSpeed.toDouble() /
                                              2,
                                          color: Colors.greenAccent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'Pressure',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      pressure.toString(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'hPa',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Stack(
                                      children: [
                                        Container(
                                          height: 5,
                                          width: 50,
                                          color: Colors.white38,
                                        ),
                                        Container(
                                          height: 5,
                                          width:
                                          pressure.toDouble() /
                                              200,
                                          color: Colors.redAccent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      'Humidity',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      humidity.toString(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Stack(
                                      children: [
                                        Container(
                                          height: 5,
                                          width: 50,
                                          color: Colors.white38,
                                        ),
                                        Container(
                                          height: 5,
                                          width: humidity.toDouble() /
                                              2,
                                          color: Colors.redAccent,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GoogleMapApp extends StatefulWidget {
  @override
  const GoogleMapApp({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  final ScrollController scrollController;

  GoogleMapWidget createState() => GoogleMapWidget();
}

class GoogleMapWidget extends State<GoogleMapApp> {
  @override
  GoogleMapApp get widget => super.widget;

  late ScrollController scrollController;

  static CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(37.773972, -122.431297),
    zoom: 11.5,
  );




  GoogleMapController? _googleMapController;
  Marker? _origin;
  Marker? _destination;
  Directions? _info;

  @override
  void initState(){
    super.initState();
    scrollController = widget.scrollController;
    //getLocationNow();
  }

  @override
  void dispose() {
    _googleMapController!.dispose();
    super.dispose();
  }
/*
  void getLocationNow() async {
    Location location = new Location();
    LocationData _locationData = await location.getLocation();
    _initialCameraPosition = CameraPosition(
      target: LatLng(_locationData.latitude!, _locationData.longitude!),
      zoom: 11.5,
    );
  }

 */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Google Maps'),
        actions: [
          if (_origin != null)
            TextButton(
              onPressed: () => _googleMapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _origin!.position,
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.green,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('ORIGIN'),
            ),
          if (_destination != null)
            TextButton(
              onPressed: () => _googleMapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _destination!.position,
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.blue,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('DEST'),
            )
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GoogleMap(
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              initialCameraPosition: _initialCameraPosition,
              onMapCreated: (controller) => _googleMapController = controller,
              markers: {
                if (_origin != null) _origin!,
                if (_destination != null) _destination!
              },
              polylines: {
                if (_info != null)
                  Polyline(
                    polylineId: const PolylineId('overview_polyline'),
                    color: Colors.red,
                    width: 5,
                    points: _info!.polylinePoints!
                        .map((e) => LatLng(e.latitude, e.longitude))
                        .toList(),
                  ),
              },
              onLongPress: _addMarker,
            ),
            if (_info != null)
              Positioned(
                top: 20.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6.0,
                    horizontal: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellowAccent,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 6.0,
                      )
                    ],
                  ),
                  child: Text(
                    '${_info!.totalDistance}, ${_info!.totalDuration}',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        onPressed: () => _googleMapController!.animateCamera(
          _info != null
              ? CameraUpdate.newLatLngBounds(_info!.bounds, 100.0)
              : CameraUpdate.newCameraPosition(_initialCameraPosition),
        ),
        child: const Icon(Icons.center_focus_strong),
      ),
    );
  }

  void _addMarker(LatLng pos) async {
    if (_origin == null || (_origin != null && _destination != null)) {
      // Origin is not set OR Origin/Destination are both set
      // Set origin
      setState(() {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon:
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          position: pos,
        );
        // Reset destination
        _destination = null;

        // Reset info
        _info = null;
      });
    } else {
      // Origin is already set
      // Set destination
      setState(() {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          position: pos,
        );
      });

      // Get directions
      /*
      final directions = await DirectionsRepository()
          .getDirections(origin: _origin!.position, destination: pos);
      setState(() => _info = directions);

       */
    }
  }

}

class TimerCountdownApp extends StatefulWidget {
  @override
  const TimerCountdownApp({
    Key? key,
    required this.scrollController,
  }) : super(key: key);

  final ScrollController scrollController;

  TimerCountdownWidget createState() => TimerCountdownWidget();
}

class TimerCountdownWidget extends State<TimerCountdownApp>
    with TickerProviderStateMixin{
  @override
  TimerCountdownApp get widget => super.widget;

  late ScrollController scrollController;
  late AnimationController controller;

  bool isPlaying = false;

  String get countText {
    Duration count = controller.duration! * controller.value;
    return controller.isDismissed
        ? '${controller.duration!.inHours}:${(controller.duration!.inMinutes % 60).toString().padLeft(2, '0')}:${(controller.duration!.inSeconds % 60).toString().padLeft(2, '0')}'
        : '${count.inHours}:${(count.inMinutes % 60).toString().padLeft(2, '0')}:${(count.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  int initTime = UserSimplePreferences.getTimerDuration() ?? 10;
  double progress = 1.0;
  bool timerGo = UserSimplePreferences.getTimerGo() ?? false;

  void notify() {
    if (countText == '0:00:00') {
      FlutterRingtonePlayer.playRingtone();
    }
  }

  void setTime(Duration time) {
    controller.duration = time;
  }

  @override
  void initState(){


    super.initState();
    scrollController = widget.scrollController;
    //initTime = UserSimplePreferences.getTimerDuration() ?? 10;

    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: initTime),
    );

    controller.addListener(() {
      notify();
      if (controller.isAnimating) {
        setState(() {
          progress = controller.value;
        });
      } else {
        setState(() {
          progress = 1.0;
          isPlaying = false;
        });
      }
    });

    if (timerGo == true) {
      controller.reverse(
          from: controller.value == 0 ? 1.0 : controller.value);
      setState(() {
        isPlaying = true;
      });
      FlutterRingtonePlayer.stop();
    }


  }



  @override
  void dispose() {
    controller.dispose();
    UserSimplePreferences.setTimerGo(false);
    FlutterRingtonePlayer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      children: [
        Container(
          height: MediaQuery.of(context).size.height / 1.7,
          child: Scaffold(
            backgroundColor: Color(0xfff5fbff),
            body: Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: CircularProgressIndicator(
                          backgroundColor: Colors.grey.shade300,
                          value: progress,
                          strokeWidth: 6,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (controller.isDismissed) {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Container(
                                height: 300,
                                child: CupertinoTimerPicker(
                                  initialTimerDuration: controller.duration!,
                                  onTimerDurationChanged: (time) {
                                    setState(() {
                                      controller.duration = time;
                                    });
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (context, child) => Text(
                            countText,
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (controller.isAnimating) {
                            controller.stop();
                            setState(() {
                              isPlaying = false;
                            });
                            FlutterRingtonePlayer.stop();
                          } else {
                            controller.reverse(
                                from: controller.value == 0 ? 1.0 : controller.value);
                            setState(() {
                              isPlaying = true;
                            });
                            FlutterRingtonePlayer.stop();
                          }
                        },
                        child: RoundButton(
                          icon: isPlaying == true ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          controller.reset();
                          setState(() {
                            isPlaying = false;
                          });
                          FlutterRingtonePlayer.stop();

                        },
                        child: RoundButton(
                          icon: Icons.stop,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }



}
