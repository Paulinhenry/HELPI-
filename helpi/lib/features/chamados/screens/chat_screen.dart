import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chamadoId;
  final String meuId; // ID do remetente (Cliente ou Profissional)
  final String meuTipo; // 'cliente' ou 'profissional'
  final String token; // JWT token para auth
  final String apiUrl; // ex: 'http://localhost:3000/api/v1'

  const ChatScreen({
    super.key,
    required this.chamadoId,
    required this.meuId,
    required this.meuTipo,
    required this.token,
    required this.apiUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late io.Socket socket;
  List<Map<String, dynamic>> mensagens = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
    _conectarSocket();
  }

  Future<void> _carregarHistorico() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.apiUrl}/chamados/${widget.chamadoId}/mensagens'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          mensagens = List<Map<String, dynamic>>.from(data['mensagens']);
          isLoading = false;
        });
        _scrollToBottom();
      } else {
        // Tratar erro
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Erro ao carregar histórico: \$e");
    }
  }

  void _conectarSocket() {
    // Configura a conexão socket
    String serverUrl = widget.apiUrl.replaceAll('/api/v1', '').replaceAll('/api', '');
    
    socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': widget.token},
    });

    socket.connect();

    socket.onConnect((_) {
      debugPrint('Conectado ao socket de chat');
      socket.emit('join_chat', {'chamado_id': widget.chamadoId});
    });

    socket.on('nova_mensagem', (data) {
      setState(() {
        mensagens.add(Map<String, dynamic>.from(data));
      });
      _scrollToBottom();
    });

    socket.onDisconnect((_) => debugPrint('Desconectado do chat'));
  }

  void _enviarMensagem() {
    if (_textController.text.trim().isEmpty) return;

    final texto = _textController.text.trim();
    _textController.clear();

    socket.emit('enviar_mensagem', {
      'chamado_id': widget.chamadoId,
      'texto': texto,
    });
    
    // A mensagem aparecerá quando o servidor fizer o emit('nova_mensagem')
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100, // +100 to ensure it goes all the way
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    socket.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    bool isMe = msg['remetente_id'] == widget.meuId;
    
    String timeStr = "";
    if (msg['criado_em'] != null) {
      DateTime dt = DateTime.parse(msg['criado_em']).toLocal();
      timeStr = DateFormat('HH:mm').format(dt);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[800],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg['texto'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(color: Colors.white70, fontSize: 11),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fundo escuro moderno
      appBar: AppBar(
        title: const Text('Chat do Serviço'),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: mensagens.length,
                    itemBuilder: (context, index) {
                      return _buildBubble(mensagens[index]);
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Escreva uma mensagem...',
                  hintStyle: TextStyle(color: Colors.white54),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _enviarMensagem(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviarMensagem,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
