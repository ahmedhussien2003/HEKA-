import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}
Widget navSideDivider() {
  return Container(
    width: 1,
    height: 3,
    margin: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(0.1),
          Colors.black.withOpacity(0.4),
          Colors.black.withOpacity(0.1),
        ],
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build (BuildContext context)
  {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 255, 173, 0),
              brightness: Brightness.light
          ),
        ),
        home: MyDynamic()
    );
  }
}



class MyDynamic extends StatefulWidget {
  const MyDynamic({super.key});

  @override
  State<MyDynamic> createState() => _MyDynamicState();
}

class _MyDynamicState extends State<MyDynamic> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(

        appBar: AppBar(
          title:Text("Heka",
            style:TextStyle(fontSize: 25,
                fontWeight: FontWeight.normal,
                color: Color.fromARGB(255, 74, 63, 53)
            ),
          ),

          leading: Icon(Icons.person),
          centerTitle: true,
          actions: [
            Text("action Part")
          ],
          backgroundColor: Color.fromARGB(255, 255, 194, 62),
        ),

        drawer: Drawer(
          child: Column(
            children: [
              DrawerHeader(
                child: ListTile(
                  title: Text("Welcome"),
                ),
              )
            ],
          ),
        ),

        //Floating Action Button
        floatingActionButton: Row(
          // mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(width: 30,),
              FloatingActionButton(
                onPressed: (){print("Added");},
                child:Icon(Icons.add)
                ,),
              SizedBox(width: 260,),
              FloatingActionButton(
                onPressed: (){print("Added");},
                child:Icon(Icons.card_travel)
                ,),
            ]
        ),


        //Navigation bar
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color.fromRGBO(253, 246, 242, 1.0),


          destinations:[
            NavigationDestination(
                icon: Icon(Icons.home),
                label: "Homes"
            ),
            NavigationDestination(
                icon: Icon(Icons.person),
                label: "Profile"),
            NavigationDestination(
                icon: Icon(Icons.settings),
                label: "settings"
            ),
          ],
          onDestinationSelected: (int value)
          {
            print("Clicked");
            print(value);
          },
          selectedIndex: 0,
        )

    ); // replace with your UI
  }
}
