import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class  HomeScreen extends StatelessWidget {
  const  HomeScreen
({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(40, 1.2 * kToolbarHeight, 40, 20),
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [


              Align(
                alignment: AlignmentDirectional(3, -0.3),
                child: Container(
                  height: 300,
                  width: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple
                  ),
                ),
              ),


               Align(
                alignment: AlignmentDirectional(-3, -0.3),
                child: Container(
                  height: 300,
                  width: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple
                  ),
                ),
              ),

               Align(
                alignment: AlignmentDirectional(0, -1.2),
                child: Container(
                  height: 300, 
                  width: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    color: Colors.orange
                  ),
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX:  100.0, sigmaY: 100.0),
                child: Container(
                  decoration: BoxDecoration(color: Colors.transparent),
                ),
                ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[ 
                    const Text(
                      '📍 Frankfurt a.M',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500 
                      ),
                    ),
                    SizedBox(height: 8),
                     Text(
                      'Good Morning',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w500 
                      ),
                    ),
                    Image.asset(
                      'assets/1.png'
                    )
                  ],
                ),
              )  
            ],

          ),
        ),),
        
    ); 
  }
}