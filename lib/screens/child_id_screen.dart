import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sync_service.dart';
import '../database.dart';

class ChildIdScreen extends StatefulWidget {
  const ChildIdScreen({super.key});

  @override
  State<ChildIdScreen> createState() => _ChildIdScreenState();
}

class _ChildIdScreenState extends State<ChildIdScreen> {
  String _childId = "";

  @override
  void initState() {
    super.initState();
    _loadId();
  }

  Future<void> _loadId() async {
    final id = await SyncService.instance.getChildId();
    setState(() => _childId = id);
  }

  Future<void> _regenerateId() async {
    final newId = await SyncService.instance.regenerateChildId();

    // 🔥 IMPORTANT FIX: Reset local database to avoid old data showing
    await GameDatabase.instance.clearAllEvents();

    setState(() => _childId = newId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("New Child ID created. Local data reset.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Child Device ID",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3D77FF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Use this ID to add this device to the Parent Dashboard.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 30),

            // CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Text(
                    "Child Device ID",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _childId,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text("COPY ID"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D77FF),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _childId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Copied to clipboard")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
