import 'dart:async';
import 'dart:convert';

import 'package:bootstrap_icons/bootstrap_icons.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class LoginPage extends StatefulWidget {
  final Management management = Management();

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _selectedService = 'KuGou';
  int loginChoose = 0;

  Alignment _selectedAlignment() {
    switch (_selectedService) {
      case 'KuGou':
        return Alignment.centerLeft;
      case 'NetEaseCloud':
        return Alignment.center;
      default:
        return Alignment.centerRight;
    }
  }

  Widget _serviceButton({
    required String value,
    required String asset,
    required String tooltip,
  }) {
    final bool isSelected = _selectedService == value;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            if (isSelected) {
              return;
            }
            setState(() {
              _selectedService = value;
            });
          },
          child: SizedBox(
            width: 88,
            height: 46,
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: SvgPicture.asset(
                  asset,
                  fit: BoxFit.contain,
                  colorFilter: isSelected
                      ? null
                      : const ColorFilter.mode(
                    Color(0xFF8A8A8A),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _serviceSelector() {
    return SizedBox(
      width: 280,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(27),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: _selectedAlignment(),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: 88,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.selected,
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
              ),
              Row(
                children: [
                  _serviceButton(
                    value: 'KuGou',
                    asset: 'assets/images/KuGouConcept.svg',
                    tooltip: '酷狗概念版',
                  ),
                  _serviceButton(
                    value: 'NetEaseCloud',
                    asset: 'assets/images/NetEaseCloud.svg',
                    tooltip: '网易云音乐',
                  ),
                  _serviceButton(
                    value: 'Navidrome',
                    asset: 'assets/images/Navidrome.svg',
                    tooltip: 'Navidrome',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '登录',
            style: TextStyle(
              color: AppColors.normalText,
              fontWeight: FontWeight.bold,
              fontSize: 30,
            ),
          ),

          SizedBox(height: 10),

          _serviceSelector(),

          SizedBox(height: 10),

          Expanded(
            child: loginChoose == 0 || _selectedService == 'Navidrome'
                ? AccountLogin(service: _selectedService)
                : QrCodeLogin(service: _selectedService),
          ),

          if (_selectedService != 'Navidrome')
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      loginChoose = 0;
                    });
                  },
                  // child: Icon(BootstrapIcons.pause_circle_fill, color: Colors.black, size: 35,), // 播放图标
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60), // 圆角
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Icon(
                      BootstrapIcons.phone,
                      color: Colors.black,
                      size: 20,
                    ), // 播放图标
                  ),
                ),

                SizedBox(width: 20),

                GestureDetector(
                  onTap: () {
                    setState(() {
                      loginChoose = 1;
                    });
                  },
                  // child: Icon(BootstrapIcons.pause_circle_fill, color: Colors.black, size: 35,), // 播放图标
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60), // 圆角
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Icon(
                      BootstrapIcons.qr_code_scan,
                      color: Colors.black,
                      size: 20,
                    ), // 播放图标
                  ),
                ),
              ],
            ),

          SizedBox(height: 10),
        ],
      ),
    );
  }
}

class AccountLogin extends StatefulWidget {
  final String service;

  const AccountLogin({super.key, required this.service});

  @override
  State<AccountLogin> createState() => _AccountLoginState();
}

class _AccountLoginState extends State<AccountLogin> {
  late Management management = Management();

  final Map<String, TextEditingController> _phoneControllers =
  <String, TextEditingController>{};
  final Map<String, TextEditingController> _codeControllers =
  <String, TextEditingController>{};
  final Map<String, int> _remainingSeconds = <String, int>{};
  final TextEditingController musicSourceController = TextEditingController();
  final TextEditingController apiController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  Timer? _countdownTimer;

  TextEditingController get phoneController =>
      _phoneControllers.putIfAbsent(widget.service, TextEditingController.new);

  TextEditingController get codeController =>
      _codeControllers.putIfAbsent(widget.service, TextEditingController.new);

  int get _currentRemainingSeconds => _remainingSeconds[widget.service] ?? 0;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final TextEditingController controller in _phoneControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _codeControllers.values) {
      controller.dispose();
    }
    musicSourceController.dispose();
    apiController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _requestVerificationCode() {
    final String phone = phoneController.text.trim();
    if (phone.isEmpty || _currentRemainingSeconds > 0) {
      return;
    }

    management.getVerificationCode(phone, '', widget.service);
    setState(() {
      _remainingSeconds[widget.service] = 60;
    });
    _countdownTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      _updateCountdowns,
    );
  }

  Future<void> _loginByMobile() async {
    final String phone = phoneController.text.trim();
    final String code = codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      return;
    }

    await management.loginByMobile(phone, '', code, widget.service);
  }

  Future<void> _loginByNavidrome() async {
    final String name = musicSourceController.text.trim();
    final String url = apiController.text.trim();
    final String username = usernameController.text.trim();
    final String password = passwordController.text.trim();

    if (name.isEmpty || url.isEmpty || username.isEmpty || password.isEmpty) {
      return;
    }

    await management.loginByNavidrome(username, url, password, name);
  }

  void _updateCountdowns(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    bool hasActiveCountdown = false;
    setState(() {
      for (final String service in _remainingSeconds.keys.toList()) {
        final int remainingSeconds = _remainingSeconds[service] ?? 0;
        final int nextSeconds = remainingSeconds > 0 ? remainingSeconds - 1 : 0;
        _remainingSeconds[service] = nextSeconds;
        hasActiveCountdown = hasActiveCountdown || nextSeconds > 0;
      }
    });

    if (!hasActiveCountdown) {
      timer.cancel();
      _countdownTimer = null;
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    bool compact = false,
  }) {
    const BorderRadius borderRadius = BorderRadius.all(Radius.circular(26));
    const Color borderColor = Color(0xFFD6D6D6);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
      isDense: compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 12 : 16,
      ),
      filled: true,
      fillColor: AppColors.background,
      border: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: AppColors.selectedText, width: 2),
      ),
    );
  }

  Widget _verificationLoginForm() {
    final int remainingSeconds = _currentRemainingSeconds;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(label: '手机号', hint: '请输入手机号'),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(label: '验证码', hint: '请输入验证码')
                    .copyWith(
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: TextButton(
                      onPressed: remainingSeconds == 0
                          ? _requestVerificationCode
                          : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.selectedText,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(
                        remainingSeconds == 0
                            ? '获取验证码'
                            : '$remainingSeconds 秒后重试',
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loginByMobile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.selectedText,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.service != 'Navidrome') {
      return _verificationLoginForm();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: musicSourceController,
                decoration: _inputDecoration(
                  label: '音乐源名称',
                  hint: '请输入音乐源名称',
                  compact: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: apiController,
                decoration: _inputDecoration(
                  label: 'API 地址',
                  hint: '请输入 API 地址',
                  compact: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: usernameController,
                decoration: _inputDecoration(
                  label: '用户名',
                  hint: '请输入用户名',
                  compact: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: _inputDecoration(
                  label: '密码',
                  hint: '请输入密码',
                  compact: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _loginByNavidrome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.selectedText,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrCodeLogin extends StatefulWidget {
  final String service;

  const QrCodeLogin({super.key, required this.service});

  @override
  State<QrCodeLogin> createState() => _QrCodeLoginState();
}

class _QrCodeLoginState extends State<QrCodeLogin> {
  late Management management = Management();

  Widget _errorBox() {
    return Container(
      width: 200,
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('获取失败', style: TextStyle(color: AppColors.buttonIcon)),
    );
  }

  Widget _qrCodeImage() {
    try {
      final String value = management.qrCodes[widget.service] ?? '';
      if (value.isEmpty) {
        return _errorBox();
      }

      final String base64Data = value.contains(',')
          ? value.split(',').last
          : value;
      return Image.memory(
        base64Decode(base64.normalize(base64Data)),
        width: 200,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _errorBox(),
      );
    } catch (_) {
      return _errorBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: management,
          builder: (_, _) => _qrCodeImage(),
        ),

        SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: () {
            /* 点击逻辑 */
          },
          icon: const Icon(size: 16, BootstrapIcons.arrow_clockwise),
          label: const Text(
            '刷新二维码',
            style: TextStyle(
              fontSize: 16, // 自定义字体大小
              fontWeight: FontWeight.w500, // 顺便可以调字重
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff46a7ff),
            // 如果背景色较深，建议同时设置文字/图标颜色（前景色）
            foregroundColor: Colors.white,

            minimumSize: const Size(55, 45),

            // 可选：调整圆角
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),

        SizedBox(height: 20),
      ],
    );
  }
}
