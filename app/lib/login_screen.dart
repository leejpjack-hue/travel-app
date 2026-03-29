import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'token_storage.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _serverBase = '';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '請填寫所有必填欄位');
      return;
    }

    if (!_isLogin && name.isEmpty) {
      setState(() => _errorMessage = '請輸入您的名稱');
      return;
    }

    if (!email.contains('@')) {
      setState(() => _errorMessage = '請輸入有效的 Email');
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = '密碼至少需要 8 個字元');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await _login(email, password);
      } else {
        await _register(email, name, password);
      }
    } catch (e) {
      setState(() => _errorMessage = '網路錯誤: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_serverBase/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await TokenStorage.saveToken(data['token']);
      widget.onLoginSuccess();
    } else {
      final data = json.decode(response.body);
      setState(() => _errorMessage = data['error'] ?? '登入失敗');
    }
  }

  Future<void> _register(String email, String name, String password) async {
    final response = await http.post(
      Uri.parse('$_serverBase/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'name': name, 'password': password}),
    );

    if (response.statusCode == 201) {
      // Auto-login after registration
      await _login(email, password);
    } else {
      final data = json.decode(response.body);
      setState(() => _errorMessage = data['error'] ?? '註冊失敗');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4ECDC4), Color(0xFF2D3436)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.flight_takeoff,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ZenVoyage',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? '登入您的帳號' : '創建新帳號',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (!_isLogin) ...[
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '名稱',
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: '密碼',
                            prefixIcon: Icon(Icons.lock),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isLogin ? '登入' : '註冊',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                            });
                          },
                          child: Text(
                            _isLogin ? '沒有帳號？點此註冊' : '已有帳號？點此登入',
                            style: const TextStyle(color: Color(0xFF4ECDC4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
