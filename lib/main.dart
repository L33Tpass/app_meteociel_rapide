import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:webview_flutter/webview_flutter.dart';

import 'package:html/parser.dart' as Parser;
import 'package:http/http.dart' as Http;
import 'package:html/dom.dart' as Dom;
import 'dart:convert' show utf8;
import 'dart:math';

String str_key_lastURL = "lasturl";
String str_key_favoris = "favoris";

void main() => runApp(MyApp());

Color my_color = Colors.green;

// --------- APP
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Random random = new Random();
    int randomNumber = random.nextInt(4);
    my_color = Colors.red;
    if (randomNumber == 0) {
      my_color = Colors.green;
    } else if (randomNumber == 1) {
      my_color = Colors.black;
    }
    print("COLOR " + my_color.toString());
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    return MaterialApp(
      title: 'Météo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, //my_color,
        //backgroundColor: Colors.brown,
        scaffoldBackgroundColor: Color.fromRGBO(0xEF, 0xEF, 0xEF, 1),
      ),
      home: MainActivity(title: 'Météo'),
    );
  }
}

// ----------- HOME
class MainActivity extends StatefulWidget {
  MainActivity({Key key, this.title}) : super(key: key); //parameters of the function
  final String title;

  @override
  _MainActivityState createState() => _MainActivityState();
}



/*-------------------------------------------------------------------*/
/*----------------------  CLASS DEFINITION  -------------------------*/
/*-------------------------------------------------------------------*/
/*---------- Here is defined the behaviour of the activity ----------*/
/*-------------------------------------------------------------------*/

class _MainActivityState extends State<MainActivity> {
  WebViewController controller;
  double webviewHeight = 0;
  bool loading_meteo = false;
  bool loading_meteo_finish = false;
  bool isAFavorite = false;
  double webview_opacity = 0.5;
  String lastUrl = "zzzz";
  String init_url;
  String nomVille = "Bonjour !";
  String nomFete = "";
  List<String> favoris = [];

  int colNomVille = 1;
  int colUrlVille = 2;
  int nbColonnes = 2;

  String head_CSS = "<head><style type=\"text/css\">" +
      "a {max-width: 100%!important;color:#808080; text-decoration:none;width:auto!important; height: auto!important;}" + // ici pour modif apparence liens
      //"table{cellpadding=\"0\";max-width: 100%; width:auto; height: auto;}" +
      "@font-face {font-family: raleway; src: url(\"file:///android_asset/raleway.ttf\")}" +
      "tr {font-size:36px!important;}" + //lignes tableau
      "body {background-color:#EFEFEF;font-family: raleway!important;color: #000000;}</style></head>";

  @override
  void initState() {
    super.initState();
    initWebview(); // MANDATORY
    /*State.initState() must be a void method without an `async` keyword.
    Rather than awaiting on asynchronous work directly inside of initState,
    call a separate method to do this work without awaiting it.*/
  }

  initWebview() async {
    setState(() {
      init_url = getLastUrlLoaded() as String;
      favoris = getFavorites() as List<String>;
      setStateLoading();
      print("INIT URL AFTER FIRST START ====> " + init_url);
      launchWebsite(init_url);
    });
  }

  Future<void> setStateFavorite() async {
    bool tempo = await isCurrentURLAFavorite(lastUrl);
    setState(() {
      isAFavorite = tempo;
      print("URL SAVED ====> " + lastUrl);
      print("FAVORIS : " + isAFavorite.toString());
    });
  }

  void setStateLoading() {
    setState(() {
      //loading_meteo = true;
      loading_meteo_finish = false;
      webview_opacity = 0.5;
    });
  }

  void setStateLoadingFinish() {
    setState(() {
      loading_meteo = false;
      loading_meteo_finish = true;
      webview_opacity = 1;
    });
  }

  Future<List<String>> getFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favorites = (prefs.getStringList(str_key_favoris) ?? []);
    return favorites;
  }

  Future<List<String>> getFavoritesTest() async {
    return ["Villeurbanne", "https://www.meteociel.fr/previsions/25767/villeurbanne.htm","Meyzieu", "https://www.meteociel.fr/previsions/25767/villeurbanne.htm"];
  }

  Future<String> getLastUrlLoaded() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getString(str_key_lastURL) ?? "-2");
  }

  Future<void> setFavorites(List<String> favorites) async {
    print("===============  " + favorites.toString());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(str_key_favoris, favorites);
  }

  Future<bool> isCurrentURLAFavorite(String currentURL) async {
    return await getFavoriteIndex(currentURL) > 0;
  }

  Future<int> getFavoriteIndex(String currentURL) async {
    // returns -1 if it is not a favorite
    List<String> favorites = await getFavorites();
    int alreadyFavoriteIndex = -1;
    for (int i = 0; i < favorites.length; i + 2) {
      if (favorites[i + 1].contains(currentURL)) {
        alreadyFavoriteIndex = i;
        break;
      }
    }
    return alreadyFavoriteIndex;
  }

  Future<void> updateFavorites() async {
    String currentCityName = nomVille;
    String currentCityURL = await getLastUrlLoaded();
    if (isValidWeatherURL(currentCityURL) && currentCityName != "Bonjour !") {
      //list is composed of city names and associated URLs, we check if current URL is already a favorite
      List<String> favorites = await getFavorites();
      bool alreadyFavorite = await isCurrentURLAFavorite(currentCityURL);

      // update Favorites
      if (alreadyFavorite) { //suppress favorite
        int alreadyFavoriteIndex = await getFavoriteIndex(currentCityURL);
        favorites.removeAt(alreadyFavoriteIndex + 1); //suppress city URL
        favorites.removeAt(alreadyFavoriteIndex); //suppress city name
      } else { //add favorite
        favorites.add(currentCityName);
        favorites.add(currentCityURL);
      }
      setFavorites(favorites);
      setStateFavorite();
    }
  }

  bool isValidWeatherURL(String URL) {
    return URL.contains("meteociel.fr/previsions"); //Check if the HTML page is a meteociel weather forecast
  }

  void launchWebsite(String url) {
    if (!url.contains(lastUrl)) { // if it's not current page

      setStateLoading();

      // GET FETE DU JOUR
      Future(() async {
        Http.Response response = await Http.get(Uri.parse("https://fetedujour.fr/"));
        Dom.Document doc = Parser.parse(response.body);
        Dom.Element element = doc.getElementsByClassName("bloc h1 fdj").first;
        element.getElementsByTagName("span").first.remove();
        nomFete = "St " + (element.text).trim();
      });

      //GET WEATHER TABLE
      Future(() async {
        Http.Response html_main_weather = await Http.get(Uri.parse(url));
        Dom.Document doc_main_weather = Parser.parse(html_main_weather.body);
        List<Dom.Element> tables_main_weather = doc_main_weather.getElementsByTagName('table');

        if (url.contains("action=getville")) { //liste des villes car meme code postal
          for (Dom.Element table in tables_main_weather) {
            LinkedHashMap<dynamic, String> attr = table.attributes;
            if (attr.toString().contains("width: 300px")) {
              String content = table.parent.innerHtml;
              content = content.replaceAll("href=\"/pre", "href=\"http://www.meteociel.fr/pre");
              String htmlContent = "<html>" + head_CSS + "<body>" + content + "<br><br>" + "</body></html>";
              lastUrl = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8).toString();
              controller.loadUrl(lastUrl);
              setStateLoadingFinish();
              break;
            } else { //qu'une ville
              lastUrl = url;
              controller.loadUrl(url);
            }
          }

        } else if (isValidWeatherURL(url)) { //ville unique obtenue
          //get nom ville
          String html_main_weather = doc_main_weather.outerHtml;
          int index_start = html_main_weather.indexOf("Prévisions météo à 3 jours pour ");
          String my_substring = html_main_weather.substring(index_start);
          int index_stop = my_substring.indexOf("(");
          my_substring = my_substring.substring(32, index_stop - 1);
          nomVille = my_substring;

          //get previsions : 4 jours
          String content_previsions = "";
          for (Dom.Element table in tables_main_weather) {
            String text = table.innerHtml.toString();
            if (!text.contains("table")) {
              if (text.contains("Vent km/h")) {
                //Suppress pressure column
                List<Dom.Element> cells = table.getElementsByTagName('td');
                for (Dom.Element cell in cells) {
                  if(cell.innerHtml.contains("Pression") || cell.innerHtml.contains("hPa")){
                    cell.remove();
                  }
                }

                //save lastURL in storage
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString(str_key_lastURL, url);

                //get & set interesting content
                content_previsions = table.parent.innerHtml;
                int index = content_previsions.indexOf("<table width=\"100%\"") - 5;
                content_previsions = content_previsions.substring(0, index); // Delete page footer
                content_previsions = content_previsions.replaceAll("//", "https://");

                String setWidth = "<table style=\"border-collapse: collapse;\"";
                content_previsions = content_previsions.replaceAll(setWidth, setWidth + " width=\"100%\"");
                break;
              }
            }
          }

          //get tendances : 6 jours suivants
          String url_tendances = url.replaceAll("previsions", "tendances");
          Http.Response response_tendances = await Http.get(Uri.parse(url_tendances));
          Dom.Document doc_tendances = Parser.parse(response_tendances.body);
          List<Dom.Element> tables_tendances = doc_tendances.getElementsByTagName('table');

          String content_tendances = "";
          for (Dom.Element table in tables_tendances) {
            String text = table.innerHtml.toString();
            if (!text.contains("table")) {
              if (text.contains("Vent km/h")) {
                //Suppress pressure column
                List<Dom.Element> cells = table.getElementsByTagName('td');
                for (Dom.Element cell in cells) {
                  if(cell.innerHtml.contains("Pression") || cell.innerHtml.contains("hPa")){
                    cell.remove();
                  }
                }

                //get & set interesting content
                content_tendances = table.parent.innerHtml;

                int index = content_tendances.indexOf("raf.</td>") + 9;
                content_tendances = content_tendances.substring(index); // Delete table header

                index = content_tendances.indexOf("id=\"biolink\"") - 4;
                content_tendances = content_tendances.substring(0, index); // Delete page footer
                content_tendances = content_tendances.replaceAll("//", "https://");

                String setWidth = "<table style=\"border-collapse: collapse;\"";
                content_tendances = content_tendances.replaceAll(setWidth, setWidth + " width=\"100%\"");
                break;
              }
            }
          }

          // Merge previsions and tendances forecasts
          String final_content = content_previsions + content_tendances;

          // Reform and load HTML
          final_content = final_content.replaceAll("Humidité", "Hum."); //Shorten column title
          final_content = final_content.replaceAll("<img ", "<img style=\"width:55%;\" "); //Set images bigger
          String htmlContent = "<html>" + head_CSS + "<body>" + final_content + "</body></html>";
          htmlContent = htmlContent.replaceAll("http://", "https://");
          lastUrl = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8).toString();
          controller.loadUrl(lastUrl);
          setStateLoadingFinish();

        } else { //URL quelconque
          lastUrl = url;
          controller.loadUrl(url);
          setStateLoading();
        }
      });
    }
  }


  /*-------------------------------------------------------------------*/
  /*------------------------  WIDGET TREE  ----------------------------*/
  /*-------------------------------------------------------------------*/
  /*--- Here is defined the graphical configuration of the activity ---*/
  /*-------------------------------------------------------------------*/

  // This method is rerun every time setState is called

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Opacity(
              opacity: loading_meteo ? 1 : 0,
              child: LinearProgressIndicator(
                backgroundColor: Color.fromRGBO(0xEF, 0xEF, 0xEF, 1),
              ),
            ), //LOADING BAR
            Container(
              padding: EdgeInsets.only(top: 50),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                      children: [
                        Container(
                          child: Text(
                            '$nomVille',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Raleway'
                            ),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(top: 5),
                          child: Text(
                            '$nomFete',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                fontFamily: 'Raleway'
                            ),
                          ),
                        ),
                      ]
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 20),
                    child: IconButton(
                      iconSize: 32.0,
                      icon: isAFavorite ? const Icon(
                          Icons.grade, color: Colors.black) : const Icon(
                          Icons.grade_outlined, color: Colors.black),
                      tooltip: 'Add to Favorites',
                      onPressed: updateFavorites,
                    ),
                  ),
                ],
              ),
            ), //CITY/FETE/FAVORITE
            Opacity( //WEBVIEW
              opacity: webview_opacity,
              //visible: loading_meteo_finish,
              child: Container(
                margin: EdgeInsets.only(top: 15, right: 10, left: 10),
                height: 800,
                child: WebView(
                  gestureNavigationEnabled: true,
                  initialUrl: init_url,
                  javascriptMode: JavascriptMode.unrestricted,
                  onWebViewCreated: (WebViewController webViewController) {
                    controller = webViewController;
                  },
                  onPageFinished: (url) {
                    print("URL ======> " + url);
                    setState(() {});
                    launchWebsite(url); // doesnt loop because we check last_url==url?
                  },
                ),
              ),
            ), //WEBVIEW
            Container(
              width: 250,
              padding: EdgeInsets.only(top: 20),
              child: TextField(
                //style: Theme.of(context).textTheme.display1, //text size
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  labelText: 'Ville, code postal, ...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (String input) {
                  //updateWebviewVisibility();
                  setState(() {});
                  launchWebsite('https://www.meteociel.fr/prevville.php?action=getville&ville=' + input + '&envoyer=ici');
                },
              ),
            ), //SEARCHVIEW
            Container(
              height: 400,
              width: 300,
              //padding: EdgeInsets.only(top:0),
              child: buildListViewFavorites(),
              decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black, //color of border
                    width: 2, //width of border
                  ),
                  borderRadius: BorderRadius.circular(10)
              ),

            ), //FAVORITES LIST
          ],
        ),
      ),
    );
  }

  Widget buildListViewFavorites() {
    return FutureBuilder<List<String>>(
      //future: getFavorites(),
      future: getFavoritesTest(),
      builder: (context, snapshot) {
        List<String> list = snapshot.data;
        int count = (list.length / 2).round();
        return ListView.builder(
          itemCount: count,
          itemBuilder: (context, index) {
            final item = list[index * 2];
            return Card(
              color: Colors.yellow,
              child: ListTile(
                title: Text(item),
                onTap: () {
                  setState(() {
                    //TO DO
                  });
                },
              ),
            );
          }
        );
      }
    );
  }
}
