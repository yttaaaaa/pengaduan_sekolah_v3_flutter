import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image_picker/image_picker.dart';

class LocalStorageService {
  static Future<void> initDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('users')) {
      List<Map<String, dynamic>> defaultUsers = [
        {'id': 1, 'name': 'Admin Sarpras', 'email': 'adminsarip@sekolah.com', 'password': 'sarippunyaapk', 'role': 'admin'},
        {'id': 2, 'name': 'Siswa Pelapor', 'email': 'siswa1@sekolah.com', 'password': 'siswaujicoba', 'role': 'pelapor'}
      ];
      await prefs.setString('users', jsonEncode(defaultUsers));
    }
    if (!prefs.containsKey('pengaduan')) await prefs.setString('pengaduan', jsonEncode([]));
  }

  static Future<List<Map<String, dynamic>>> getTable(String table) async {
    final prefs = await SharedPreferences.getInstance();
    await initDatabase();
    return List<Map<String, dynamic>>.from(jsonDecode(prefs.getString(table) ?? '[]'));
  }

  static Future<void> saveTable(String table, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(table, jsonEncode(data));
  }
}

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get user => _currentUser;

  Future<void> login(String email, String password) async {
    final users = await LocalStorageService.getTable('users');
    final match = users.where((u) => u['email'] == email && u['password'] == password);
    if (match.isEmpty) throw Exception('Email atau password salah!');
    _currentUser = match.first;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final users = await LocalStorageService.getTable('users');
    if (users.any((u) => u['email'] == email)) throw Exception('Email sudah ada!');
    final newUser = {'id': DateTime.now().millisecondsSinceEpoch, 'name': name, 'email': email, 'password': password, 'role': 'pelapor'};
    users.add(newUser);
    await LocalStorageService.saveTable('users', users);
    _currentUser = newUser;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.initDatabase();
  runApp(ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: const MaterialApp(debugShowCheckedModeBanner: false, home: LoginScreen()),
  ));
}

class PdfHelper {
  static Future<void> cetakNota(Map<String, dynamic> p) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      build: (pw.Context context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('NOTA PENGADUAN SARPRAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('SMK NEGERI SELARAS', style: pw.TextStyle(fontSize: 10))),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),
              pw.Text('ID Laporan: #00${p['id']}'),
              pw.Text('Tanggal: ${p['created_at'].toString().length >= 10 ? p['created_at'].toString().substring(0, 10) : p['created_at']}'),
              pw.SizedBox(height: 8),
              pw.Text('Judul: ${p['judul']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Lokasi: ${p['lokasi_sarana']}'),
              pw.Text('Deskripsi: ${p['deskripsi']}'),
              pw.Divider(),
              pw.Text('STATUS: ${p['status'].toString().toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Tanggapan Petugas: ${p['tanggapan'] ?? 'Belum ditanggapi'}'),
              pw.Text('Penilaian Pelapor: ${p['rating'] != null ? "${p['rating']} Bintang (${p['ulasan'] ?? '-'})" : 'Belum dinilai'}'),
              pw.SizedBox(height: 30),
              pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Text('Petugas Sarpras,\n\n( ___________________ )', textAlign: pw.TextAlign.center)),
            ],
          ),
        );
      },
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Nota_${p['id']}.pdf');
  }

  static Future<void> cetakRekap(List<Map<String, dynamic>> allLaporan) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      orientation: pw.PageOrientation.landscape,
      build: (pw.Context context) {
        return [
          pw.Center(child: pw.Text('REKAPITULASI LAPORAN PENGADUAN SARPRAS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text('SMK NEGERI SELARAS', style: pw.TextStyle(fontSize: 12))),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['ID', 'Tanggal', 'Judul Sarana', 'Lokasi', 'Status', 'Rating'],
            data: allLaporan.map((item) {
              return [
                '#00${item['id']}',
                item['created_at'].toString().length >= 10 ? item['created_at'].toString().substring(0, 10) : item['created_at'],
                item['judul'],
                item['lokasi_sarana'],
                item['status'],
                item['rating'] != null ? '${item['rating']} / 5' : '-'
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ];
      },
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Rekap_Pengaduan_Sarpras.pdf');
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(), _pass = TextEditingController();
  @override
  void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('PENGADUAN SARPRAS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    try {
                      await context.read<AuthProvider>().login(_email.text, _pass.text);
                      final user = context.read<AuthProvider>().user;
                      if (!mounted) return;
                      Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (_) => user!['role'] == 'admin' ? const AdminDashboard() : const PelaporDashboard()
                      ));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: const Text('Login'),
                ),
                TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('Belum punya akun? Daftar')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  @override
  void dispose() { _name.dispose(); _email.dispose(); _pass.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Siswa')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () async {
                    try {
                      await context.read<AuthProvider>().register(_name.text, _email.text, _pass.text);
                      if (!mounted) return;
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PelaporDashboard()));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: const Text('Daftar & Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PelaporDashboard extends StatefulWidget {
  const PelaporDashboard({super.key});
  @override
  State<PelaporDashboard> createState() => _PelaporDashboardState();
}
class _PelaporDashboardState extends State<PelaporDashboard> {
  List<Map<String, dynamic>> _laporan = [];
  @override
  void initState() { super.initState(); _loadData(); }
  Future<void> _loadData() async {
    final res = await LocalStorageService.getTable('pengaduan');
    final myUser = context.read<AuthProvider>().user;
    if (!mounted) return;
    setState(() { _laporan = res.where((e) => e['user_id'] == myUser!['id']).toList().reversed.toList(); });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Pelapor'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () { context.read<AuthProvider>().logout(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); })]),
      body: _laporan.isEmpty 
          ? const Center(child: Text('Belum ada laporan pengaduan.'))
          : ListView.builder(
              itemCount: _laporan.length,
              itemBuilder: (context, i) {
                final item = _laporan[i];
                return ListTile(
                  title: Text(item['judul']),
                  subtitle: Text('Lokasi: ${item['lokasi_sarana']}\nStatus: ${item['status']}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailAduanPage(aduan: item))).then((_) => _loadData()),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormLaporPage())).then((_) => _loadData()),
        label: const Text('Buat Laporan'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class FormLaporPage extends StatefulWidget {
  const FormLaporPage({super.key});
  @override
  State<FormLaporPage> createState() => _FormLaporPageState();
}
class _FormLaporPageState extends State<FormLaporPage> {
  final _judul = TextEditingController(), _lokasi = TextEditingController(), _deskripsi = TextEditingController();
  String? _base64Image;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  @override
  void dispose() { _judul.dispose(); _lokasi.dispose(); _deskripsi.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formulir Pengaduan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _judul, decoration: const InputDecoration(labelText: 'Judul Sarana Rusak', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _lokasi, decoration: const InputDecoration(labelText: 'Lokasi Ruangan/Kelas', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _deskripsi, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi Detail Kerusakan', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Text('Foto Bukti Kerusakan:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_base64Image != null)
            Container(
              height: 200,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
            )
          else
            Container(
              height: 100,
              color: Colors.grey[200],
              child: const Center(child: Text('Belum ada foto yang diunggah')),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (_judul.text.isEmpty || _lokasi.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul dan Lokasi wajib diisi!')));
                return;
              }
              final allAduan = await LocalStorageService.getTable('pengaduan');
              final myUser = context.read<AuthProvider>().user;
              final newAduan = {
                'id': DateTime.now().millisecondsSinceEpoch,
                'user_id': myUser!['id'],
                'judul': _judul.text,
                'lokasi_sarana': _lokasi.text,
                'deskripsi': _deskripsi.text,
                'foto': _base64Image,
                'status': 'Pending',
                'created_at': DateTime.now().toIso8601String(),
                'tanggapan': null,
                'rating': null,
                'ulasan': null
              };
              allAduan.add(newAduan);
              await LocalStorageService.saveTable('pengaduan', allAduan);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Kirim Pengaduan'),
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}
class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> _allLaporan = [];
  @override
  void initState() { super.initState(); _loadAllData(); }
  Future<void> _loadAllData() async {
    final res = await LocalStorageService.getTable('pengaduan');
    if (!mounted) return;
    setState(() { _allLaporan = res.reversed.toList(); });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin (Rekap)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Cetak Rekap Laporan',
            onPressed: () {
              if (_allLaporan.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk direkap!')));
                return;
              }
              PdfHelper.cetakRekap(_allLaporan);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: _allLaporan.isEmpty
          ? const Center(child: Text('Belum ada laporan dari siswa.'))
          : ListView.builder(
              itemCount: _allLaporan.length,
              itemBuilder: (context, i) {
                final item = _allLaporan[i];
                return ListTile(
                  title: Text(item['judul']),
                  subtitle: Text('Lokasi: ${item['lokasi_sarana']} | Status: ${item['status']}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailAduanPage(aduan: item))).then((_) => _loadAllData()),
                );
              },
            ),
    );
  }
}

class DetailAduanPage extends StatefulWidget {
  final Map<String, dynamic> aduan;
  const DetailAduanPage({super.key, required this.aduan});
  @override
  State<DetailAduanPage> createState() => _DetailAduanPageState();
}
class _DetailAduanPageState extends State<DetailAduanPage> {
  String? _selectedStatus;
  final _tanggapanCtrl = TextEditingController();
  int _selectedRating = 5;
  final _ulasanCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.aduan['status'];
    _tanggapanCtrl.text = widget.aduan['tanggapan'] ?? '';
    _selectedRating = widget.aduan['rating'] ?? 5;
    _ulasanCtrl.text = widget.aduan['ulasan'] ?? '';
  }

  @override
  void dispose() { _tanggapanCtrl.dispose(); _ulasanCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isAdmin = user!['role'] == 'admin';
    final isSelesai = widget.aduan['status'] == 'Selesai';

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Informasi Pengaduan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Judul Laporan: ${widget.aduan['judul']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Lokasi: ${widget.aduan['lokasi_sarana']}'),
          Text('Deskripsi Kerusakan: ${widget.aduan['deskripsi']}'),
          Text('Status Saat Ini: ${widget.aduan['status']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          Text('Tanggapan Petugas: ${widget.aduan['tanggapan'] ?? 'Belum ada tanggapan'}'),
          Text('Penilaian Pelapor: ${widget.aduan['rating'] != null ? "${widget.aduan['rating']} Bintang (${widget.aduan['ulasan'] ?? '-'})" : 'Belum dinilai'}'),
          const SizedBox(height: 12),
          if (widget.aduan['foto'] != null) ...[
            const Text('Foto Bukti:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 200,
              alignment: Alignment.centerLeft,
              child: Image.memory(base64Decode(widget.aduan['foto'])),
            ),
          ],
          const Divider(height: 40),
          if (isAdmin) ...[
            const Text('Ubah Status & Beri Tanggapan (Fitur Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              items: const [DropdownMenuItem(value: 'Pending', child: Text('Pending')), DropdownMenuItem(value: 'Proses', child: Text('Proses')), DropdownMenuItem(value: 'Selesai', child: Text('Selesai'))],
              onChanged: (val) { setState(() { _selectedStatus = val; }); },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(controller: _tanggapanCtrl, decoration: const InputDecoration(labelText: 'Isi Tanggapan Perbaikan', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final allAduan = await LocalStorageService.getTable('pengaduan');
                for (var element in allAduan) {
                  if (element['id'] == widget.aduan['id']) {
                    element['status'] = _selectedStatus;
                    element['tanggapan'] = _tanggapanCtrl.text;
                  }
                }
                await LocalStorageService.saveTable('pengaduan', allAduan);
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Simpan Perubahan Status'),
            ),
          ] else ...[
            if (isSelesai && widget.aduan['rating'] == null) ...[
              const Text('Berikan Umpan Balik / Penilaian Perbaikan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedRating,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5 - Puas Sekali')),
                  DropdownMenuItem(value: 4, child: Text('4 - Puas')),
                  DropdownMenuItem(value: 3, child: Text('3 - Cukup')),
                  DropdownMenuItem(value: 2, child: Text('2 - Kurang Puas')),
                  DropdownMenuItem(value: 1, child: Text('1 - Kecewa')),
                ],
                onChanged: (val) { if (val != null) setState(() { _selectedRating = val; }); },
                decoration: const InputDecoration(labelText: 'Rating Bintang', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(controller: _ulasanCtrl, decoration: const InputDecoration(labelText: 'Kritik / Saran / Ulasan Umpan Balik', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  final allAduan = await LocalStorageService.getTable('pengaduan');
                  for (var element in allAduan) {
                    if (element['id'] == widget.aduan['id']) {
                      element['rating'] = _selectedRating;
                      element['ulasan'] = _ulasanCtrl.text;
                    }
                  }
                  await LocalStorageService.saveTable('pengaduan', allAduan);
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Kirim Penilaian'),
              ),
            ]
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () { PdfHelper.cetakNota(widget.aduan); },
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Cetak Nota Bukti Laporan (PDF)'),
          ),
        ],
      ),
    );
  }
}
