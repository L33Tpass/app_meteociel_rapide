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

String str_key_lastURL = "lasturl";
String str_key_favoris = "favoris";




// ---------------
// ----------- APP
// ---------------

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, //my_color,
        scaffoldBackgroundColor: Color.fromRGBO(0xEF, 0xEF, 0xEF, 1),
      ),
      home: MainActivity(title: 'Météo'),
    );
  }
}



// ----------------
// ----------- HOME
// ----------------
class MainActivity extends StatefulWidget {
  const MainActivity({super.key, required this.title}); //parameters of the function
  final String title;

  @override
  _MainActivityState createState() => _MainActivityState();
}



// -----------------
// ----------- CLASS
// -----------------
class _MainActivityState extends State<MainActivity> {
  /*-------------------------------------------------------------------*/
  /*-----------------------  VARS DEFINITION  -------------------------*/
  /*-------------------------------------------------------------------*/
  /*---------- Here is defined the behaviour of the activity ----------*/
  /*-------------------------------------------------------------------*/
  double webviewHeight = 0;
  bool loading_meteo = false;
  bool loading_meteo_finish = false;
  double webview_opacity = 0.5;
  bool init_url_validity = false;
  String lastUrl = "zzzz";
  String realUrlShown = "zzzz";
  String init_url = "";
  String nomVille = "Bonjour !";
  String nomFete = "";
  List<String> favoris = [];
  WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

  int colNomVille = 1;
  int colUrlVille = 2;
  int nbColonnes = 2;

  String head_CSS = "<head><style type=\"text/css\">" +
      "a {max-width: 100%!important;color:#808080; text-decoration:none;width:auto!important; height: auto!important;}" + // ici pour modif apparence liens
      "table{cellpadding=\"0\";width: 100%; height: auto;}" + //Affichage liste villes avec même code postal
      //"@font-face {font-family: raleway; src: url(\"file:///android_asset/raleway.ttf\")}" + //Changement police texte (ne fonctionne pas pour le moment)
      "tr {font-size:36px!important;}" + //lignes tableau
      "body {background-color:#EFEFEF;font-family: raleway!important;color: #000000;}</style></head>"; //Background color


  /*-------------------------------------------------------------------*/
  /*---------------------  BEHAVIOR DEFINITION  -----------------------*/
  /*-------------------------------------------------------------------*/
  /*---------- Here is defined the behavior of the activity -----------*/
  /*-------------------------------------------------------------------*/


  @override
  void initState() {
    super.initState();
    initWebview(); // MANDATORY
    /*State.initState() must be a void method without an `async` keyword.
    Rather than awaiting on asynchronous work directly inside of initState,
    call a separate method to do this work without awaiting it.*/
  }

  initWebview() async {
    Future<String> tempo_url = getLastUrlLoaded();
    String buffer_url = await tempo_url; //get String from Future<String>
    if(isValidWeatherURL(buffer_url)) { //to not update global var 'init_url' if wrong
      init_url = buffer_url;
      launchWebsite(init_url);
    } else {
      setState(() {
        init_url_validity = false;
      });
    }
  }

  void setStateLoading() {
    setState(() {
      loading_meteo = true;
      loading_meteo_finish = false;
      init_url_validity = true;
      webview_opacity = 0.5;
    });
  }

  void setStateLoadingFinish() {
    setState(() {
      loading_meteo = false;
      loading_meteo_finish = true;
      init_url_validity = true;
      webview_opacity = 1;
    });
  }

  Future<String> getLastUrlLoaded() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getString(str_key_lastURL) ?? "-2");
  }

  /* ----- FAVORITES RELATED FUNCTIONS ----- */

  Future<bool> isCurrentURLAFavorite(String currentURL) async {
    bool result = await getFavoriteIndex(currentURL) >= 0;
    return result;
  }

  Future<List<String>> getFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favorites = (prefs.getStringList(str_key_favoris) ?? []);
    return favorites;
  }

  Future<void> setFavorites(List<String> favorites) async {
    print("FAVORITES CHANGED ===============>  " + favorites.toString());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(str_key_favoris, favorites);
  }

  Future<int> getFavoriteIndex(String currentURL) async {
    // returns -1 if it is not a favorite
    List<String> favorites = await getFavorites();
    int alreadyFavoriteIndex = -1;
    for (int i = 0; i < favorites.length; i = i + 2) {
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
      //Favorites list is composed of city names and associated URLs, we check if current URL is already a favorite
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
      setState((){});
    }
  }

  bool isValidWeatherURL(String URL) {
    return URL.contains("meteociel.fr/previsions"); //Check if the HTML page is a meteociel weather forecast
  }

  void launchWebsite(String url) {
    if (!url.contains(lastUrl)) { // if it's not current page
      setStateLoading();
      realUrlShown = "zzzz";
      print("URL LOADED =============> " + url);

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
              String content = table.parent!.innerHtml;
              content = content.replaceAll("href=\"/pre", "href=\"https://www.meteociel.fr/pre");
              String htmlContent = "<html>" + head_CSS + "<body>" + content + "<br><br>" + "</body></html>";
              htmlContent = htmlContent.replaceAll("http://", "https://");
              lastUrl = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8).toString();
              setStateLoadingFinish();
              break;
            } else { //qu'une ville
              lastUrl = url;
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
                content_previsions = table.parent!.innerHtml;
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
                content_tendances = table.parent!.innerHtml;

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

          //Favorites management
          realUrlShown = url;

          // Merge previsions and tendances forecasts
          String final_content = content_previsions + content_tendances;

          // Reform and load HTML
          final_content = final_content.replaceAll("Humidité", "Hum."); //Shorten column title
          final_content = final_content.replaceAll("<img ", "<img style=\"width:55%;\" "); //Set images bigger
          String htmlContent = "<html>" + head_CSS + "<body>" + final_content + "</body></html>";
          htmlContent = htmlContent.replaceAll("http://", "https://");
          lastUrl = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8).toString();
          setStateLoadingFinish();

        } else { //URL quelconque
          lastUrl = url;
          setStateLoading();
        }

        controller.loadRequest(Uri.parse(lastUrl));
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
              padding: init_url_validity ? EdgeInsets.only(top: 50) : EdgeInsets.only(top:150),
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                      children: [
                        Container(
                          child: Text(
                            '$nomVille',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: init_url_validity ? 24 : 40,
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
                  Visibility(
                    visible: isValidWeatherURL(realUrlShown),
                    child: Container(
                      padding: EdgeInsets.only(left: 10),
                      child: buildIconButtonAddFavorites(), //IconButton Future builder
                    ),
                  ),
                ],
              ),
            ), //CITY/FETE/FAVORITE
            Visibility(
              visible: init_url_validity,
              child: Opacity( //WEBVIEW
              opacity: webview_opacity,
              child: Container(
                margin: EdgeInsets.only(top: 15, right: 10, left: 10),
                height: 800,
                child: WebViewWidget(
                  controller: controller
                ),
              ),
            ), //WEBVIEW
            ),
            Container(
              width: 250,
              padding: init_url_validity ? EdgeInsets.only(top: 20) : EdgeInsets.only(top:350),
              child: TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  labelText: 'Ville, code postal, ...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (String input) {
                  launchWebsite('https://www.meteociel.fr/prevville.php?action=getville&ville=' + input + '&envoyer=ici');
                },
              ),
            ), //SEARCHVIEW
            Container(
              child: buildListViewFavorites(), // ListView Future builder
            ), //FAVORITES LIST
          ],
        ),
      ),
    );
  }

  Widget buildListViewFavorites() {
    return FutureBuilder<List<String>>(
      future: getFavorites(),
      builder: (context, snapshot) {
        List<String>? list = snapshot.data;
        List<String> list1 = [];
        if (list!=null){list1=list.toList();}
        int count = (list1.length/2).round();
        return ListView.builder(
          padding: EdgeInsets.only(top: 10, bottom: 10), //remove padding top
          shrinkWrap: true, //auto height
          physics: NeverScrollableScrollPhysics(), //not scrollable
          itemCount: count,
          itemBuilder: (context, index) {
            final item = list1[index * 2];
            return Card(
              elevation: 0, //remove shadow
              color: const Color(0xFFEFEFEF),
              child: ListTile(
                title: Text(item, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold),),
                onTap: () {
                  launchWebsite(list1[index*2+1]);
                },
              ),
            );
          }
        );
      }
    );
  }

  Widget buildIconButtonAddFavorites(){
    return FutureBuilder<bool>(
        future:isCurrentURLAFavorite(realUrlShown),
        builder: (context, snapshot){
          bool? isFav = snapshot.data;
          isFav ??= false;
          return IconButton(
            iconSize: 32.0,
            icon: isFav ?
              const Icon(Icons.bookmark_added, color: Colors.black) :
              const Icon(Icons.bookmark_add_outlined, color: Colors.black),
            tooltip: 'Add to Favorites',
            onPressed: updateFavorites,
          );
        }
    );
  }
}
