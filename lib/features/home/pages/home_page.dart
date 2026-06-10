import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _maxLen = 1000;
  static const List<String> _examples = [
    '我想找计算机视觉方向的导师，最好在北京。',
    '我想做 AI 和医疗结合的研究，有没有适合的老师？',
    '推荐几个 NLP 和大模型安全方向的导师。',
    '我是自动化背景，想申请机器人方向博士。',
    '我想找江浙沪地区偏应用的人工智能导师。',
  ];
  static const List<String> _tags = [
    '人工智能',
    '计算机视觉',
    '自然语言处理',
    '医学影像',
    '机器人',
    '网络安全',
    '生物信息',
    '材料计算',
    '北京',
    '上海',
    '江浙沪',
    '博士申请',
    '硕士申请',
  ];

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty;

  void _submit() {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    if (prompt.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('可补充研究方向或地区，描述更具体会更准哦')));
    }
    context.push('/recommendation?q=${Uri.encodeComponent(prompt)}');
  }

  void _appendTag(String tag) {
    final text = _controller.text;
    _controller.text = text.isEmpty ? tag : '$text $tag';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SchoNavi'),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用自然语言找到适合你的导师', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: _maxLen,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '例如：我想找医学影像和计算机视觉方向的导师，最好在上海，适合申请硕士。',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: const Text('开始推荐'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _controller.text.isEmpty
                      ? null
                      : () => _controller.clear(),
                  child: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('快捷标签', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags
                  .map(
                    (t) => ActionChip(
                      label: Text(t),
                      onPressed: () => _appendTag(t),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text('试试这些', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._examples.map(
              (e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(e),
                onTap: () => _controller.text = e,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
