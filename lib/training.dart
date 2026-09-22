import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}
const orangeSeed = Color(0xFFFFA500);



const darkMode_black = Color(0xFF000111);
const darkMode_gray = Color(0xFF2F2F2F);
const darkMode_white = Color(0xFFF6F6F6);
const darkMode_gold = Color(0xFFFFCB74);




class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(

          colorScheme: ColorScheme.fromSeed(
              seedColor: darkMode_black)
      ),
      home: const MyHomePage(title: 'Home Page'),
    );
  }
}






class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});


  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}




class _MyHomePageState extends State<MyHomePage> {
  // int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
        leading: Icon(Icons.eighteen_up_rating_sharp , color: Color.fromARGB(221, 203, 20, 15),),
      ),
      body: Center(

        // child:Container(
        //
        //   width: double.infinity,
        //   height: double.infinity,
        //
        //   margin: EdgeInsets.all(50),
        //   padding: EdgeInsets.all(80),
        //   decoration: BoxDecoration(
        //     borderRadius: BorderRadius.circular(20.5),
        //     color: Colors.red,
        //
        //   ),
        //   child: Container(
        //
        //     width: double.infinity,
        //     height: double.infinity,
        //
        //     // margin: EdgeInsets.all(50),
        //     padding: EdgeInsets.all(10),
        //     decoration: BoxDecoration(
        //       borderRadius: BorderRadius.circular(20.5),
        //       color: Colors.green,
        //
        //     ),
        //     child: Text(
        //       "Hello" ,
        //       style: TextStyle(
        //           color: Colors.orangeAccent,
        //           fontSize: 50,
        //           fontStyle: FontStyle.italic
        //       ),
        //     ),
        //   ),
        // ),

        //Column
        // child:Column(
        //
        //   mainAxisAlignment: MainAxisAlignment.start,
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     Container(
        //       height: 100,
        //       width: 200,
        //       decoration: BoxDecoration(
        //         color: Color.fromARGB(60, 0, 30, 10),
        //         borderRadius: BorderRadius.circular(10),
        //       ),
        //     ),
        //
        //     Container(
        //       height: 100,
        //       width: double.infinity,
        //       decoration: BoxDecoration(
        //         borderRadius: BorderRadius.circular(15),
        //           color:Color.fromARGB(252, 255, 90, 17)
        //       ),
        //     )
        //   ],
        // )

        //Row
        // child: Container(
        //   height: double.infinity,
        //   child:Row(
        //
        //   crossAxisAlignment: CrossAxisAlignment.start        ,
        //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        //   // mainAxisSize: MainAxisSize.min,
        //   children: [
        //     Container(
        //       height: 120,
        //       width: 120,
        //       decoration: BoxDecoration(
        //           borderRadius: BorderRadius.circular(20),
        //           color: Color.fromARGB(250, 25, 250, 170)
        //       ),
        //     ),
        //
        //     Container(
        //       height: 120,
        //       width: 180,
        //       decoration: BoxDecoration(
        //           borderRadius: BorderRadius.circular(20),
        //           color: Color.fromARGB(250, 25, 20, 170)
        //       )
        //       )
        //   ],
        // ),)

        //Center
        // child: Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        //   children: [
        //     Container(
        //       height: 100,
        //       width: 120,
        //       color: Color.fromARGB(250, 152, 121, 12),
        //       child: Center(
        //         child: Text("data")
        //         ,
        //       ),
        //     ),
        //     Container(
        //       height: 110,
        //       width: 110,
        //       color: Color.fromARGB(120, 12, 210, 81),
        //       child: Center(
        //         child: Text("data2"),
        //
        //       ),
        //     )
        //
        //   ],
        // ),

        //online image
        // child: Container(
        //   height: double.infinity,
        //   width: double.infinity,
        //
        // // child: Image.network("https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSYTRzLea_0zPoz0O7aO_fsZNjo8V5g5FEEpA&s",
        // //     fit:BoxFit.contain)
        //
        //   child: Image.asset("assets/images/Ihub.jpg",
        //   fit: BoxFit.cover)
        // )

        //Sized Box + Stack
        // child: Container(
        //   child: Stack(
        //     children: [
        //       SizedBox(
        //         child:Image.asset("assets/images/Ihub.jpg",
        //             fit: BoxFit.cover),
        //       ),
        //       Center(child:Text("FCIS 2026" ,
        //         style:
        //         TextStyle(color: Color.fromARGB(200, 230, 140, 18)),
        //       ))
        //     ],
        //   )
        // )




        //Padding
        // child: Container(
        //   child: Padding(padding:EdgeInsets.all(85.0),
        //   child:Container(height: double.infinity,
        //   width:double.infinity,
        //   color:Color.fromARGB(200, 152, 70, 230),
        //   ))
        // )


        //LisTile + leading + tileColor + trailing
        // child: Column(
        //   mainAxisAlignment: MainAxisAlignment.end,
        //   children: [
        //     ListTile(
        //       leading: Icon(Icons.home , color: Color.fromARGB(201, 183, 32, 200),),
        //       tileColor:Colors.greenAccent,
        //       title:Text("My title"),
        //       trailing: Text("End Trailing"),
        //       onTap: (){
        //         print("Clicked");
        //       },
        //     ),

        // ],
        // )
        //wrap
        // child: Wrap(
        //   children: [
        //     Center(child:Text("That is my first Flutter Application this day"
        //         "That is my first Flutter Application this day"
        //         "That is my first Flutter Application this day"
        //         "That is my first Flutter Application this day"
        //         "That is my first Flutter Application this day"
        //         "That is my first Flutter Application this day"),),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //     Text("That is my first Flutter Application this day"),
        //   ],
        //
        // ),






      ),





      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
