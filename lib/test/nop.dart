// // main_screen.dart
// import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// // import 'coin_drawer.dart';
//
// class RewardScreen extends StatefulWidget {
//   const RewardScreen({super.key});
//
//   @override
//   State<RewardScreen> createState() => _RewardScreenState();
// }
//
// class _RewardScreenState extends State<RewardScreen> {
//   int availableCoins = 100;
//   RewardedAd? _rewardedAd;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadRewardedAd();
//   }
//
//   void _loadRewardedAd() {
//     RewardedAd.load(
//       adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ad unit ID
//       request: const AdRequest(),
//       rewardedAdLoadCallback: RewardedAdLoadCallback(
//         onAdLoaded: (ad) {
//           _rewardedAd = ad;
//         },
//         onAdFailedToLoad: (error) {
//           debugPrint('RewardedAd failed to load: $error');
//         },
//       ),
//     );
//   }
//
//   void _showRewardedAd() {
//     if (_rewardedAd != null) {
//       _rewardedAd!.show(
//         onUserEarnedReward: (_, reward) {
//           setState(() {
//             availableCoins += reward.amount.toInt();
//           });
//         },
//       );
//       _rewardedAd = null;
//       _loadRewardedAd();
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Ad not ready yet. Please try again later.')),
//       );
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         actions: [
//           GestureDetector(
//             onTap: () {
//               showModalBottomSheet(
//                 context: context,
//                 builder: (context) => CoinDrawer(
//                   availableCoins: availableCoins,
//                   onWatchAd: _showRewardedAd,
//                 ),
//               );
//             },
//             child: Container(
//               margin: const EdgeInsets.only(right: 16),
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//               decoration: BoxDecoration(
//                 color: Colors.amber[100],
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.monetization_on, color: Colors.amber),
//                   const SizedBox(width: 4),
//                   Text(
//                     availableCoins.toString(),
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: const Center(
//         child: Text('Main Screen Content'),
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _rewardedAd?.dispose();
//     super.dispose();
//   }
// }
// //
// // // coin_drawer.dart
// // import 'package:flutter/material.dart';
//
// class CoinDrawer extends StatelessWidget {
//   final int availableCoins;
//   final VoidCallback onWatchAd;
//
//   const CoinDrawer({
//     super.key,
//     required this.availableCoins,
//     required this.onWatchAd,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Your Coins',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               Row(
//                 children: [
//                   const Icon(Icons.monetization_on, color: Colors.amber),
//                   const SizedBox(width: 4),
//                   Text(
//                     availableCoins.toString(),
//                     style: const TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           ElevatedButton.icon(
//             onPressed: onWatchAd,
//             icon: const Icon(Icons.play_circle_outline),
//             label: const Text('Watch Ad for Rewards'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.amber,
//               foregroundColor: Colors.black,
//               minimumSize: const Size(double.infinity, 50),
//             ),
//           ),
//           const SizedBox(height: 12),
//           ElevatedButton.icon(
//             onPressed: () {
//               // Add more options functionality here
//             },
//             icon: const Icon(Icons.more_horiz),
//             label: const Text('More Options'),
//             style: ElevatedButton.styleFrom(
//               minimumSize: const Size(double.infinity, 50),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }