import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../Config/global_state.dart';

class CoinsManagementScreen extends StatefulWidget {
  const CoinsManagementScreen({Key? key}) : super(key: key);

  @override
  _CoinsManagementScreenState createState() => _CoinsManagementScreenState();
}

class _CoinsManagementScreenState extends State<CoinsManagementScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  int _coins = 0; // Starting with 0 coins
  int _consecutiveAdsWatched = 0;
  bool _isLoading = false;
  bool _showRewardPopup = false;
  bool _isAdReady = false;

  // Unity Ads placement ID
  final String _adUnitId = 'Rewarded_Android';

  @override
  void initState() {
    super.initState();
    _initializeUnityAds();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 2.0, end: 15.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeUnityAds() async {
    await UnityAds.init(
      gameId: '5748429', // Replace with your Unity Game ID
      testMode: true,
      onComplete: () => print('Initialization Complete'),
      onFailed: (error, message) => print('Initialization Failed: $error $message'),
    );
    _loadUnityAd();
  }

  Future<void> _loadUnityAd() async {
    setState(() => _isLoading = true);

    try {
      await UnityAds.load(
        placementId: _adUnitId,
        onComplete: (placementId) {
          setState(() {
            _isAdReady = true;
            _isLoading = false;
          });
        },
        onFailed: (placementId, error, message) {
          setState(() {
            _isAdReady = false;
            _isLoading = false;
          });
          print('Unity Ads load failed: $error $message');
        },
      );
    } catch (e) {
      setState(() {
        _isAdReady = false;
        _isLoading = false;
      });
      print('Error loading Unity Ad: $e');
    }
  }

  Future<void> _showRewardedAd() async {
    if (!_isAdReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad is not ready yet. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await UnityAds.showVideoAd(
        placementId: _adUnitId,
        onComplete: (placementId) async {
          final currentCoins = await GlobalState().totalCoins;
          await GlobalState().setTotalCoins(currentCoins + 3); // Add 3 coins

          setState(() {
            _consecutiveAdsWatched = (_consecutiveAdsWatched + 1) % 4;
            _isLoading = false;
            _isAdReady = false;
            _showRewardPopup = true;
          });

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _showRewardPopup = false);
            }
          });

          _loadUnityAd();
        },

        onFailed: (placementId, error, message) {
          setState(() => _isLoading = false);
          print('Unity Ads show failed: $error $message');
        },
        onStart: (placementId) => print('Video Ad Started'),
        onSkipped: (placementId) {
          setState(() => _isLoading = false);
          print('Video Ad Skipped');
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error showing Unity Ad: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAdRewardOption({
    required int adCount,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isActive
                  ? [Colors.purple.shade900, Colors.purple.shade700]
                  : [Colors.grey.shade900, Colors.black],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isActive ? Colors.purple : Colors.purple.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : onTap,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.video_library,
                            color: Colors.purple,
                            size: 24,
                          ),
                          Text(
                            ' ×$adCount',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Watch $adCount ${adCount == 1 ? 'Video' : 'Videos'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Earn 3 coins', // Always show 3 coins
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive && _isAdReady)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade400,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'READY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isLoading && isActive)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Get Coins',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Balance Section
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: _glowAnimation.value / 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Current Balance',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: Colors.purple,
                                  size: 30,
                                ),
                                const SizedBox(width: 8),
                                FutureBuilder<int>(
                                  future: Future.value(GlobalState().totalCoins),
                                  builder: (context, snapshot) {
                                    return Text(
                                      '${snapshot.data ?? 0}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),

                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Watch Ads Section
                  const Text(
                    'Watch & Earn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAdRewardOption(
                    adCount: 1,
                    onTap: _showRewardedAd,
                    isActive: _consecutiveAdsWatched == 0,
                  ),
                  _buildAdRewardOption(
                    adCount: 2,
                    onTap: _showRewardedAd,
                    isActive: _consecutiveAdsWatched == 1,
                  ),
                  _buildAdRewardOption(
                    adCount: 3,
                    onTap: _showRewardedAd,
                    isActive: _consecutiveAdsWatched == 2,
                  ),
                  _buildAdRewardOption(
                    adCount: 4,
                    onTap: _showRewardedAd,
                    isActive: _consecutiveAdsWatched == 3,
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'Watch videos to earn coins!',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Reward Popup
          if (_showRewardPopup)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade900,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.celebration,
                          color: Colors.white,
                          size: 50,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '+3 coins!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Keep watching to earn more!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}