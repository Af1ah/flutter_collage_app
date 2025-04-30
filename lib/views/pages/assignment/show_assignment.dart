import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ShowAssignment extends StatefulWidget {
  final String studentName;
  final String admissionNo;
  final String filePath;
  final String fileName;

  const ShowAssignment({
    Key? key,
    required this.studentName,
    required this.admissionNo,
    required this.filePath,
    required this.fileName,
  }) : super(key: key);

  @override
  _ShowAssignmentState createState() => _ShowAssignmentState();
}

class _ShowAssignmentState extends State<ShowAssignment> {
  String? status;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkFileStatus();
  }

  Future<void> _checkFileStatus() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(widget.filePath);
      if (!uri.isAbsolute) throw Exception("Invalid file URL.");
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "File not accessible: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Assignment: ${widget.studentName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkFileStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : WebViewApp(url: widget.filePath)),
          ),
          _buildApprovalButtons(),
        ],
      ),
    );
  }

  Widget _buildApprovalButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => _updateStatus("Approved"),
            icon: const Icon(Icons.check_circle),
            label: const Text("Approve"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _updateStatus("Rejected"),
            icon: const Icon(Icons.cancel),
            label: const Text("Reject"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => status = newStatus);
    try {
      DatabaseReference ref = FirebaseDatabase.instance
          .ref()
          .child("assignments")
          .child(widget.admissionNo);

      await ref.update({
        "status": newStatus,
        "updatedAt": DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Assignment marked as $newStatus"),
            backgroundColor: newStatus == "Approved" ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating status: $e"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}

class WebViewApp extends StatefulWidget {
  final String url;

  const WebViewApp({Key? key, required this.url}) : super(key: key);

  @override
  _WebViewAppState createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  int _progress = 0;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _timedOut = false;
              });
            }

            // Set a timeout in case the page never loads
            Future.delayed(const Duration(seconds: 15), () {
              if (mounted && _isLoading) {
                setState(() {
                  _timedOut = true;
                  _isLoading = false;
                });
              }
            });
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _timedOut = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController.canGoBack()) {
          _webViewController.goBack();
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          
          if (_progress > 0 && _progress < 100)
            LinearProgressIndicator(value: _progress / 100),

          if (_isLoading)
            const Center(child: CircularProgressIndicator()),

          if (_timedOut)
            _errorScreen("Page load timed out. Check your internet connection."),

          if (_hasError)
            _errorScreen("Failed to load document."),
        ],
      ),
    );
  }

  Widget _errorScreen(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(fontSize: 18, color: Colors.red)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
                _timedOut = false;
              });
              _webViewController.reload();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
