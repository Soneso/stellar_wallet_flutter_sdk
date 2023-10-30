import 'package:flutter/material.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'examples/sep_024.dart' as sep24Example;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Wallet Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MyHomePage(title: 'Flutter Wallet Demo'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Wallet SDK Demo'),
      ),
      body: CustomScrollView(
        slivers: [
          MultiSliver(
            pushPinnedChildren: true,
            children: [
              _SliverPinnedHeader(
                text: 'Examples:',
              ),
              _SliverListTile(
                title: Text('SEP-024'),
                onTap: () => sep24Example.runExample(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliverListTile extends StatelessWidget {
  const _SliverListTile({
    Key? key,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  final Widget title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: ListTile(
        title: title,
        onTap: onTap,
      ),
    );
  }
}

class _SliverPinnedHeader extends StatelessWidget {
  const _SliverPinnedHeader({
    Key? key,
    required this.text,
  }) : super(key: key);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SliverPinnedHeader(
      child: Container(
        color: Colors.blueGrey,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.headline6!.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
