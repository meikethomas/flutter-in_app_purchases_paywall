import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_countdown_timer/countdown_timer_controller.dart';
import 'package:flutter_countdown_timer/flutter_countdown_timer.dart';
import 'package:in_app_purchases_paywall_ui/in_app_purchases_paywall_ui.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // custom icon theme
        iconTheme: const IconThemeData(color: Colors.green),
        // your colorScheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  PurchaseHandler purchaseHandler = PurchaseHandler();
  late final CountdownTimerController _countdownController;

  @override
  void initState() {
    super.initState();
    _countdownController = CountdownTimerController(
      endTime: DateTime.now()
          .add(const Duration(days: 2, hours: 7))
          .millisecondsSinceEpoch,
    );
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaywallScaffold(
      // appBarTitle for scaffold
      appBarTitle: "Premium",
      child: SimplePaywall(
        // set a custom header
        headerContainer: Container(
          margin: const EdgeInsets.all(16),
          height: 100,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            image: DecorationImage(
              fit: BoxFit.cover,
              alignment: FractionalOffset.center,
              image: AssetImage('assets/images/premium_bg.png'),
            ),
          ),
          child: Container(),
        ),
        // Title Bar
        title: "Go Premium",
        // SubTitle
        subTitle: "All features at a glance",
        // Add as many bullet points as you like
        bulletPoints: const [
          IconAndText(Icons.stop_screen_share_outlined, "No Ads"),
          IconAndText(Icons.hd, "Premium HD"),
          IconAndText(Icons.sort, "Access to All Premium Articles"),
        ],
        // Your subscriptions that you want to offer to the user
        subscriptionListData: [
          SubscriptionData(
            durationTitle: "Yearly",
            durationShort: "1 year",
            price: "€14,99€",
            dealPercentage: 69,
            productDetails: "Dynamic purchase data",
            index: 0,
          ),
          SubscriptionData(
            durationTitle: "Quarterly",
            durationShort: "3 Months",
            price: "€6,99",
            dealPercentage: 42,
            productDetails: "Dynamic purchase data",
            index: 2,
          ),
          SubscriptionData(
            durationTitle: "Monthly",
            durationShort: "1 month",
            price: "3,99€",
            dealPercentage: 0,
            productDetails: "Dynamic purchase data",
            index: 3,
          ),
        ],
        // Shown if isPurchaseSuccess == true
        successTitle: "Thank you",
        // Shown if isPurchaseSuccess == true
        successSubTitle: "for being a premium user!",
        // Widget can be anything. Shown if isPurchaseSuccess == true
        /*successWidget: Container(
              padding: EdgeInsets.only(top: 8, bottom: 8),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(
                  child: Text("Read about all premium features"),
                  onPressed: () {
                    print("let‘s go to the home widget again");
                  },
                )
              ])),*/
        activePlanList: const [
          // GooglePlayGeneralActivePlan(),
          // GooglePlayActivePlan("yearly_pro", "com.tnx.packed"),
          AppleAppStoreActivePlan(),
        ],
        // set true if subscriptions are loading
        isSubscriptionLoading: false,
        // if purchase is in progress, set to true. this will show a fullscreen progress indicator
        isPurchaseInProgress: false,
        // to show the success widget
        purchaseState: PurchaseState.PURCHASED,

        // callback Interface for restore and purchase tap events. Extend DefaultPurchaseHandler
        callbackInterface: purchaseHandler,
        purchaseStateStreamInterface: purchaseHandler,
        // provide your TOS
        tosData: const TextAndUrl(
          "Terms of Service",
          "https://www.linkfive.io/tos",
        ),
        // provide your PP
        ppData: const TextAndUrl(
          "Privacy Policy",
          "https://www.linkfive.io/privacy",
        ),
        // add a custom campaign widget
        campaignWidget: CampaignBanner(
          headline: "🥳 Summer Special Sale",
          subContent: Container(
            padding: const EdgeInsets.all(8),
            child: CountdownTimer(controller: _countdownController),
          ),
        ),
      ),
    );
  }
}

class PurchaseHandler extends DefaultPurchaseHandler {
  @override
  Future<bool> purchase(SubscriptionData productDetails) async {
    print("purchase start");
    isPendingPurchase = true;
    await Future.delayed(const Duration(seconds: 1));
    print("purchase done");
    purchaseState = PurchaseState.PURCHASED;
    isPendingPurchase = false;
    return true;
  }

  @override
  Future<bool> restore() async {
    isPendingPurchase = true;
    await Future.delayed(const Duration(seconds: 1));
    purchaseState = PurchaseState.PURCHASED;
    isPendingPurchase = false;
    return true;
  }
}
