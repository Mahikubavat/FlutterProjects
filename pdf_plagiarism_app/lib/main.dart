import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'similarity_engine.dart';

void main() => runApp(const MaterialApp(home: HomeScreen()));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _result = "Select two PDFs to compare";

  Future<void> _pickAndCompare() async {
    // Open file picker to select 2 PDFs
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.length >= 2) {
      File file1 = File(result.files[0].path!);
      File file2 = File(result.files[1].path!);

      // Run extraction
      String text1 = SimilarityEngine.extractTextFromPdf(file1);
      String text2 = SimilarityEngine.extractTextFromPdf(file2);

      // Run math calculation
      double score = SimilarityEngine.calculateCosineSimilarity(text1, text2);

      setState(() {
        _result = "Similarity Score: ${score.toStringAsFixed(2)}%";
      });
    } else {
      setState(() {
        _result = "Please select at least 2 PDF files.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Similarity Checker")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_result, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickAndCompare,
              child: const Text("Select 2 PDFs & Compare"),
            ),
          ],
        ),
      ),
    );
  }
}