import 'package:flutter/material.dart';
import 'package:gyrogame/screens/coins_management.dart';
import '../Config/global_state.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/typing_indicator.dart';
import '../database/database_helper.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _messageHistory = [];
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  bool _isTyping = false;
  bool _isWaitingForResponse = false;
  String? _errorMessage;
  bool _isInitialized = false;
  late AnimationController _coinShakeController;
  late Animation<double> _coinShakeAnimation;
  late AnimationController _coinScaleController;
  late Animation<double> _coinScaleAnimation;
  Timer? _coinUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
    _startCoinUpdateTimer();
  }

  void _initializeAnimations() {
    _coinShakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _coinShakeAnimation = Tween(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _coinShakeController, curve: Curves.elasticIn),
    );

    _coinScaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _coinScaleAnimation = Tween(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _coinScaleController, curve: Curves.easeInOut),
    );
  }

  void _startCoinUpdateTimer() {
    _coinUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateCoins();
    });
  }

  Future<void> _updateCoins() async {
    final currentCoins = await GlobalState().totalCoins;
    if (mounted) {
      setState(() {
        _coinScaleController.forward().then((_) {
          _coinScaleController.reverse();
        });
      });
    }
  }

  Future<void> _spendCoins(int amount) async {
    final currentCoins = await GlobalState().totalCoins;
    if (currentCoins >= amount) {
      await GlobalState().setTotalCoins(currentCoins - amount);
      _coinShakeController.forward().then((_) {
        _coinShakeController.reverse();
      });
    } else {
      _showInsufficientCoinsDialog();
    }
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E), // Dark theme background
        title: const Text(
          'Insufficient Coins',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_outlined,
              size: 48,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Text(
              'You don\'t have enough coins for this action.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoinsManagementScreen()),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.amber.withOpacity(0.2),
              ),
              child: const Text(
                'Get More Coins',
                style: TextStyle(color: Colors.amber),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeChat() async {
    if (_isInitialized) return;

    await _loadMessages();

    if (_messages.isEmpty) {
      final welcomeMessage = ChatMessage(
        text: "Hello! How can I help you today?",
        isSent: false,
        timestamp: DateTime.now(),
      );

      await _chatService.saveMessage(welcomeMessage);

      setState(() {
        _messages.add(welcomeMessage);
        _messageHistory.add({
          "content": welcomeMessage.text,
          "isUser": false,
        });
      });
    }

    _isInitialized = true;
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.loadMessages();
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _messageHistory.clear();
        _messageHistory.addAll(messages.map((msg) => {
          'content': msg.text,
          'isUser': msg.isSent,
        }));
      });
    } catch (e) {
      _handleError('Failed to load messages: ${e.toString()}');
    }
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty || _isWaitingForResponse) return;

    final currentCoins = await GlobalState().totalCoins;
    if (currentCoins < 10) {
      _showInsufficientCoinsDialog();
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final userMessage = ChatMessage(
      text: text,
      isSent: true,
      timestamp: DateTime.now(),
      messageStatus: 'sent',
    );

    try {
      await _spendCoins(10);
      await _chatService.saveMessage(userMessage);

      setState(() {
        _messages.add(userMessage);
        _messageHistory.add({
          'content': text,
          'isUser': true,
        });
        _isWaitingForResponse = true;
        _isTyping = true;
      });
      _scrollToBottom();

      final apiResponse = await ApiService.sendMessage(text, _messageHistory);

      if (apiResponse.success) {
        final botMessage = ChatMessage(
          text: apiResponse.message,
          isSent: false,
          timestamp: DateTime.now(),
          messageStatus: 'delivered',
        );

        await _chatService.saveMessage(botMessage);

        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(botMessage);
            _messageHistory.add({
              'content': apiResponse.message,
              'isUser': false,
            });
            _isWaitingForResponse = false;
          });
          _scrollToBottom();
        }
      } else {
        _handleError(apiResponse.message);
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String error) {
    if (mounted) {
      setState(() {
        _isTyping = false;
        _isWaitingForResponse = false;
        _errorMessage = error;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Future<void> _clearChat() async {
    try {
      await _chatService.clearChat();
      setState(() {
        _messages.clear();
        _messageHistory.clear();
        _errorMessage = null;
        _isInitialized = false;
      });
      _initializeChat();
    } catch (e) {
      _handleError('Failed to clear chat: ${e.toString()}');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isTyping) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MinimalTypingIndicator(),
            ),
          );
        }
        return MessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildInputArea() {
    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.red.withOpacity(0.1),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: MessageComposer(
            onSubmitted: _handleSubmitted,
            canSend: !_isWaitingForResponse,
          ),
        ),
      ],
    );
  }

  void _showCoinInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E), // Matching dark theme
        title: Row(
          children: const [
            Icon(Icons.monetization_on, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Coin Information',
              style: TextStyle(color: Colors.white), // White text
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• Each message costs 10 coins',
              style: TextStyle(color: Colors.white70), // Slightly dimmed white
            ),
            const Text(
              '• You can earn coins by:',
              style: TextStyle(color: Colors.white70),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text(
                '- Daily logins\n- Completing tasks\n- Purchasing coins',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: Future.value(GlobalState().totalCoins),
              builder: (context, snapshot) {
                return Text(
                  'Current Balance: ${snapshot.data ?? 0} coins',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                );
              },
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Rounded corners
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CoinsManagementScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Get More Coins'),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreOptionsSheet() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.white),
            title: const Text('Clear Chat' , style: TextStyle(color: Colors.white),),
            onTap: () {
              _clearChat();
              Navigator.pop(context);
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.history, color: Colors.white),
          //   title: const Text('View History', style: TextStyle(color: Colors.white),),
          //   onTap: () {
          //     Navigator.pop(context);
          //     _showHistoryDialog();
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.report_outlined, color: Colors.white),
            title: const Text('Report Issue', style: TextStyle(color: Colors.white),),
            onTap: () {
              Navigator.pop(context);
              _showReportDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat History'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _messageHistory.map((msg) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${msg["isUser"] ? "User: " : "Bot: "}${msg["content"]}',
                style: TextStyle(
                  color: msg["isUser"] ? Colors.blue : Colors.white,
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: const Text('Would you like to report an issue with this conversation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Implement report functionality
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Issue reported')),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2C2C2E),
          secondary: Color(0xFF48484A),
          surface: Color(0xFF1C1C1E),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Modern Chat'),
          leading: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1C1C1E),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => _buildMoreOptionsSheet(),
              );
            },
          ),

          actions: [
            GestureDetector(
              onTap: () => _showCoinInfoDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _coinShakeAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _coinShakeAnimation.value,
                          child: const Icon(Icons.monetization_on,
                            color: Colors.amber,
                            size: 20,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    ScaleTransition(
                      scale: _coinScaleAnimation,
                      child: FutureBuilder<int>(
                        future: Future.value(GlobalState().totalCoins),
                        builder: (context, snapshot) {
                          return Text(
                            '${snapshot.data ?? 0}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF121212),
                const Color(0xFF1C1C1E).withOpacity(0.95),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildMessageList()),
                _buildInputArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _coinShakeController.dispose();
    _coinScaleController.dispose();
    _coinUpdateTimer?.cancel();
    super.dispose();
  }
}