// --------- MAIN
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

String str_lastURL = "lasturl";
String str_favoris = "favoris";

void main() => runApp(MyApp());

Color color = Colors.green;

// --------- APP
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Random random = new Random();
    int randomNumber = random.nextInt(4);
    color = Colors.orange;
    if (randomNumber == 0) {
      color = Colors.green;
    } else if (randomNumber == 1) {
      color = Colors.black;
    }
    print("COLOR " + color.toString());
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    return MaterialApp(
      title: 'Météo',
      theme: ThemeData(
        primarySwatch: color,
        //backgroundColor: Colors.brown,
        scaffoldBackgroundColor: Color.fromRGBO(0xEF, 0xEF, 0xEF, 1),
      ),
      home: HomeScreen(title: 'Météo'),
    );
  }
}

// ----------- HOME
class HomeScreen extends StatefulWidget {
  HomeScreen({Key key, this.title})
      : super(key: key); //parameters of the functiun
  final String title;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}






/*--------------------------------------------------------------------------*/

class _HomeScreenState extends State<HomeScreen> {
  WebViewController controller;
  double webviewHeight = 0;
  bool loading_meteo = false;
  bool loading_meteo_finish = false;
  double webview_opacity = 0.5;
  String lastUrl = "zzzz";
  String init_url;
  String nomVille = "Bonjour !";
  String nomFete = "";
  List<String> favoris = [];

  int colNomVille = 1;
  int colUrlVille = 2;
  int nbColonnes = 2;

  String head = "<head><style type=\"text/css\">" +
      "a {max-width: 100%!important;color:#808080; text-decoration:none;width:auto!important; height: auto!important;}" + // ici pour modif apparence liens
      //"table{cellpadding=\"0\";max-width: 100%; width:auto; height: auto;}" +
      "@font-face {font-family: raleway; src: url(\"file:///android_asset/raleway.ttf\")}" +
      "body {background-color:#EFEFEF;font-family: raleway!important;text-align: justify;color: #000000;margin:1!important;}</style></head>";

  @override
  void initState() {
    super.initState();
    loadLastUrl();
  }

  loadLastUrl() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      init_url = (prefs.getString(str_lastURL) ?? "-2");
      favoris = (prefs.getStringList(str_favoris) ?? []);
      setLoading();
      print("INIT URL AFTER FIRST START ====> " + init_url);
      launchWebsite(init_url);
    });
  }

  void setLoading() {
    setState(() {
      loading_meteo = true;
      loading_meteo_finish = false;
      webview_opacity = 0.5;
    });
  }

  void setLoadingFinish() {
    setState(() {
      loading_meteo = false;
      loading_meteo_finish = true;
      webview_opacity = 1;
    });
  }

  void launchWebsite(String url) {

    if (!url.contains(lastUrl)) { // if it's not current page

      setLoading();

      Future(() async {
        Http.Response response = await Http.get(Uri.parse("https://fetedujour.fr/"));
        Dom.Document doc = Parser.parse(response.body);
        Dom.Element element = doc.getElementsByClassName("bloc h1 fdj").first;
        element.getElementsByTagName("span").first.remove();
        nomFete = "St " + (element.text).trim();
      });

      Future(() async {
        Http.Response response = await Http.get(Uri.parse(url));
        Dom.Document doc = Parser.parse(response.body);
        String html_content = doc.outerHtml;
        List<Dom.Element> tables = doc.getElementsByTagName('table');

        if (url.contains("action=getville")) { //liste des villes car meme code postal
          for (Dom.Element table in tables) {
            LinkedHashMap<dynamic, String> attr = table.attributes;
            if (attr.toString().contains("width: 300px")) {
              String content = table.parent.innerHtml;
              content = content.replaceAll("href=\"/pre", "href=\"http://www.meteociel.fr/pre");
              String htmlContent = "<html>" + head + "<body>" + content + "<br><br>" + "</body></html>";
              lastUrl = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8).toString();
              controller.loadUrl(lastUrl);
              setLoadingFinish();
              break;
            } else { //qu'une ville
              lastUrl = url;
              controller.loadUrl(url);
            }
          }
        } else if (url.contains("meteociel.fr/previsions")) { //ville unique obtenue

          int index_start = html_content.indexOf("Prévisions météo à 3 jours pour ");
          String my_substring = html_content.substring(index_start);
          int index_stop = my_substring.indexOf("(");
          my_substring = my_substring.substring(32, index_stop-1);

          nomVille = my_substring;

          for (Dom.Element table in tables) {
            String text = table.innerHtml.toString();
            print(text);
            if (!text.contains("table")) {
              if (text.contains("Vent km/h")) {
                //save lastURL in storage
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setString(str_lastURL, url);

                //get & set interesting content
                String content = table.parent.innerHtml;
                int index = content.indexOf("<table width=\"100%\"") - 5; // HOW TO SET CORRECT WIDTH ??
                content = content.substring(0, index); // delete page footer
                content = content.replaceAll("//", "http://");

                String setWidth = "<table style=\"border-collapse: collapse;\"";
                content = content.replaceAll(setWidth, setWidth + " width=\"50px\"");

                // Reform and load HTML
                String htmlContent = "<html>" + head + "<body>" + content + "</body></html>";
                lastUrl = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: utf8).toString();
                controller.loadUrl(lastUrl);
                setLoadingFinish();
                break;
              }
            }
          }
        } else { //URL quelconque
          lastUrl = url;
          controller.loadUrl(url);
          setLoading();
        }
      });
    }
  }





  /*--------------------------------------------------------------------------*/


  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Opacity(
              opacity: loading_meteo?1:0,
              child: LinearProgressIndicator(
                backgroundColor: Color.fromRGBO(0xEF, 0xEF, 0xEF, 1),
              ),
            ),
            Column(
              children: [
                Container(height: 50, width: 20,),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                    Column(
                      children:[
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
                          margin: EdgeInsets.only(top:5),
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
                      child:Icon(Icons.grade_outlined, size: 30)),
                    ]
                )
              ],
            ),
            Opacity( //WEBVIEW
              opacity: webview_opacity,
              //visible: loading_meteo_finish,
              child: Container(
                margin: EdgeInsets.only(top: 15, right: 10, left: 10),
                height: 500,
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
            ),
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
                  launchWebsite('http://www.meteociel.fr/prevville.php?action=getville&ville=' + input + '&envoyer=ici');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
