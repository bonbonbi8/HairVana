import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const HairVanaApp());
}

// Models
class Appointment {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final DateTime dateTime;
  final String status;
  final String? notes;
  final int? reminderWeeks;
  final bool hasReminder;

  Appointment({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.dateTime,
    required this.status,
    this.notes,
    this.reminderWeeks,
    this.hasReminder = false,
  });

  factory Appointment.fromMap(Map<String, dynamic> map, String id) {
    return Appointment(
      id: id,
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      servicePrice: (map['servicePrice'] ?? 0.0).toDouble(),
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      status: map['status'] ?? 'scheduled',
      notes: map['notes'],
      reminderWeeks: map['reminderWeeks'],
      hasReminder: map['hasReminder'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'servicePrice': servicePrice,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status,
      'notes': notes,
      'reminderWeeks': reminderWeeks,
      'hasReminder': hasReminder,
    };
  }
}

class Client {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;

  Client({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
  });

  factory Client.fromMap(Map<String, dynamic> map, String id) {
    return Client(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
    };
  }
}

class Service {
  final String id;
  final String name;
  final double price;
  final int duration;
  final String? description;

  Service({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.description,
  });

  factory Service.fromMap(Map<String, dynamic> map, String id) {
    return Service(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      duration: map['duration'] ?? 30,
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'duration': duration,
      'description': description,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Service &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Services
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Appointments
  Stream<List<Appointment>> getAppointments() {
    return _firestore.collection('appointments').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Appointment.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addAppointment(Appointment appointment) async {
    await _firestore.collection('appointments').add(appointment.toMap());
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await _firestore.collection('appointments').doc(appointmentId).update({'status': status});
  }

  // Clients
  Stream<List<Client>> getClients() {
    return _firestore.collection('clients').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Client.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<DocumentReference> addClient(Client client) async {
    return await _firestore.collection('clients').add(client.toMap());
  }

  Future<void> updateClient(String clientId, Client client) async {
    await _firestore.collection('clients').doc(clientId).update(client.toMap());
  }

  Future<void> deleteClient(String clientId) async {
    await _firestore.collection('clients').doc(clientId).delete();
  }

  // Services
  Stream<List<Service>> getServices() {
    return _firestore.collection('services').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Service.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addService(Service service) async {
    await _firestore.collection('services').add(service.toMap());
  }

  Future<void> updateService(String serviceId, Service service) async {
    await _firestore.collection('services').doc(serviceId).update(service.toMap());
  }

  Future<void> deleteService(String serviceId) async {
    await _firestore.collection('services').doc(serviceId).delete();
  }

  // Reminders
  Stream<List<Appointment>> getUpcomingReminders() {
    final now = DateTime.now();
    return _firestore
        .collection('appointments')
        .where('hasReminder', isEqualTo: true)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) {
      final appointments = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data(), doc.id))
          .where((appointment) {
        if (appointment.reminderWeeks == null) return false;
        final reminderDate = appointment.dateTime
            .add(Duration(days: appointment.reminderWeeks! * 7));
        return reminderDate.isAfter(now) &&
            reminderDate.isBefore(now.add(const Duration(days: 7)));
      }).toList();
      return appointments;
    });
  }

  Future<void> sendReminder(Appointment appointment) async {
    // In a real app, you would integrate with a messaging service here
    // For now, we'll just print the reminder
    print('Sending reminder to ${appointment.clientName} (${appointment.clientPhone})');
    print('It has been ${appointment.reminderWeeks} weeks since your last appointment');
    print('Would you like to schedule another appointment?');
  }

  Future<void> checkAndSendReminders() async {
    final reminders = await getUpcomingReminders().first;
    for (final appointment in reminders) {
      await sendReminder(appointment);
    }
  }
}

// App
class HairVanaApp extends StatelessWidget {
  const HairVanaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HairVana',
      theme: ThemeData(
        primaryColor: Colors.blue.shade700,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const DashboardScreen(),
    const BookingScreen(),
    const ClientManagementScreen(),
    const ServiceManagementScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Booking'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(Icons.spa), label: 'Services'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: false,
        backgroundColor: Colors.white,
        elevation: 5,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// Dashboard Screen
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome, Stylist!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your daily overview',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                _buildOverviewCards(firebaseService),
                const SizedBox(height: 20),
                const Text(
                  'Upcoming Appointments',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: _buildAppointmentsList(firebaseService),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(FirebaseService firebaseService) {
    return LayoutBuilder(
        builder: (context, constraints) {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: constraints.maxWidth > 600 ? 2 : 1.5,
            children: [
              _buildDashboardCard(
                Icons.event_available,
                'Upcoming',
                StreamBuilder<List<Appointment>>(
                  stream: firebaseService.getAppointments(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Text('0');
                    final appointments = snapshot.data!
                        .where((a) => a.status == 'scheduled')
                        .length;
                    return Text(appointments.toString());
                  },
                ),
              ),
              _buildDashboardCard(
                Icons.people,
                'Clients',
                StreamBuilder<List<Client>>(
                  stream: firebaseService.getClients(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Text('0');
                    return Text(snapshot.data!.length.toString());
                  },
                ),
              ),
              _buildDashboardCard(
                Icons.attach_money,
                'Today',
                StreamBuilder<List<Appointment>>(
                  stream: firebaseService.getAppointments(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Text('\$0');
                    final todayEarnings = snapshot.data!
                        .where((a) => a.status == 'completed')
                        .fold(0.0, (total, a) => total + a.servicePrice);
                    return Text('\$${todayEarnings.toStringAsFixed(0)}');
                  },
                ),
              ),
              _buildDashboardCard(
                Icons.rate_review,
                'Reviews',
                const Text('0'),
              ),
            ],
          );
        }
    );
  }

  Widget _buildAppointmentsList(FirebaseService firebaseService) {
    return StreamBuilder<List<Appointment>>(
      stream: firebaseService.getAppointments(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading appointments'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data!
            .where((a) => a.status == 'scheduled')
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

        if (appointments.isEmpty) {
          return const Center(
            child: Text(
              'No upcoming appointments',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                title: Text(
                  appointment.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${DateFormat('MMM dd').format(appointment.dateTime)} at ${DateFormat('hh:mm a').format(appointment.dateTime)}\n${appointment.serviceName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '\$${appointment.servicePrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AppointmentDetailsScreen(
                        appointmentId: appointment.id,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardCard(IconData icon, String title, Widget data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.blue.shade700),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            DefaultTextStyle(
              style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600
              ),
              child: data,
            ),
          ],
        ),
      ),
    );
  }
}

// Appointment Details Screen
class AppointmentDetailsScreen extends StatefulWidget {
  final String appointmentId;

  const AppointmentDetailsScreen({Key? key, required this.appointmentId}) : super(key: key);

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}

class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  late final FirebaseService firebaseService;

  @override
  void initState() {
    super.initState();
    firebaseService = FirebaseService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
      ),
      body: StreamBuilder<List<Appointment>>(
        stream: firebaseService.getAppointments(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading appointment'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final appointment = snapshot.data!
              .firstWhere((a) => a.id == widget.appointmentId, orElse: () => throw Exception('Appointment not found'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailCard(
                  title: 'Client Information',
                  children: [
                    _buildDetailRow('Name', appointment.clientName),
                    _buildDetailRow('Phone', appointment.clientPhone),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  title: 'Appointment Details',
                  children: [
                    _buildDetailRow('Service', appointment.serviceName),
                    _buildDetailRow('Price', '\$${appointment.servicePrice.toStringAsFixed(2)}'),
                    _buildDetailRow('Date', DateFormat('MMM dd, yyyy').format(appointment.dateTime)),
                    _buildDetailRow('Time', DateFormat('hh:mm a').format(appointment.dateTime)),
                    _buildStatusRow(appointment.status),
                  ],
                ),
                if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildDetailCard(
                    title: 'Notes',
                    children: [
                      Text(appointment.notes!),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                _buildActionButtons(context, appointment),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              'Status',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: _buildStatusChip(status),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'scheduled':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  Widget _buildActionButtons(BuildContext context, Appointment appointment) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (appointment.status == 'scheduled') ...[
          ElevatedButton.icon(
            onPressed: () => _updateAppointmentStatus(context, appointment.id, 'completed'),
            icon: const Icon(Icons.check),
            label: const Text('Mark Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _updateAppointmentStatus(context, appointment.id, 'cancelled'),
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _updateAppointmentStatus(BuildContext context, String appointmentId, String status) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await firebaseService.updateAppointmentStatus(appointmentId, status);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Appointment status updated successfully')),
        );
        navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error updating appointment status: $e')),
        );
      }
    }
  }
}

// Booking Screen
class BookingScreen extends StatefulWidget {
  const BookingScreen({Key? key}) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final FirebaseService firebaseService;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Service? _selectedService;
  bool _isLoading = false;
  bool _hasReminder = false;
  int? _reminderWeeks;

  @override
  void initState() {
    super.initState();
    firebaseService = FirebaseService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      // Create a client
      final client = Client(
        id: '', // Will be set by Firestore
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Add client to Firestore
      final clientDoc = await firebaseService.addClient(client);

      // Create appointment
      final appointment = Appointment(
        id: '', // Will be set by Firestore
        clientId: clientDoc.id,
        clientName: client.name,
        clientPhone: client.phone,
        serviceId: _selectedService!.id,
        serviceName: _selectedService!.name,
        servicePrice: _selectedService!.price,
        dateTime: DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        ),
        status: 'scheduled',
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        reminderWeeks: _reminderWeeks,
        hasReminder: _hasReminder,
      );

      // Add appointment to Firestore
      await firebaseService.addAppointment(appointment);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully')),
        );

        // Clear form
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _notesController.clear();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _selectedService = null;
        });
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error booking appointment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Client Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              const Text(
                'Appointment Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Service>>(
                stream: firebaseService.getServices(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading services');
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final services = snapshot.data!;
                  if (services.isEmpty) {
                    return const Text('No services available');
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DropdownButtonFormField<Service>(
                      value: _selectedService ?? services.first,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Service *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.spa),
                      ),
                      items: services.map((Service service) {
                        return DropdownMenuItem<Service>(
                          value: service,
                          child: Text('${service.name} - \$${service.price.toStringAsFixed(2)}'),
                        );
                      }).toList(),
                      onChanged: (Service? newValue) {
                        setState(() {
                          _selectedService = newValue;
                        });
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _selectedTime == null
                              ? 'Select Time'
                              : _selectedTime!.format(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Reminder Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Set Follow-up Reminder'),
                      value: _hasReminder,
                      onChanged: (bool? value) {
                        setState(() {
                          _hasReminder = value ?? false;
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_hasReminder) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _reminderWeeks,
                  decoration: const InputDecoration(
                    labelText: 'Remind after',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alarm),
                  ),
                  items: [2, 4, 6, 8, 12].map((weeks) {
                    return DropdownMenuItem<int>(
                      value: weeks,
                      child: Text('$weeks weeks'),
                    );
                  }).toList(),
                  onChanged: (int? value) {
                    setState(() {
                      _reminderWeeks = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _confirmBooking,
                  child: const Text('Confirm Booking', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Client Management Screen
class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({Key? key}) : super(key: key);

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  late final FirebaseService firebaseService;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    firebaseService = FirebaseService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final notesController = TextEditingController();
    final dialogContext = context;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in required fields')),
                );
                return;
              }

              try {
                final client = Client(
                  id: '',
                  name: nameController.text,
                  phone: phoneController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );

                await firebaseService.addClient(client);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Client added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Error adding client: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditClientDialog(Client client) {
    final nameController = TextEditingController(text: client.name);
    final phoneController = TextEditingController(text: client.phone);
    final emailController = TextEditingController(text: client.email ?? '');
    final notesController = TextEditingController(text: client.notes ?? '');
    final dialogContext = context;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in required fields')),
                );
                return;
              }

              try {
                final updatedClient = Client(
                  id: client.id,
                  name: nameController.text,
                  phone: phoneController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );

                await firebaseService.updateClient(client.id, updatedClient);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Client updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Error updating client: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(Client client) async {
    final dialogContext = context;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Are you sure you want to delete ${client.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await firebaseService.deleteClient(client.id);
        if (mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            const SnackBar(content: Text('Client deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(content: Text('Error deleting client: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ClientSearchDelegate(firebaseService),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Clients',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Client>>(
                stream: firebaseService.getClients(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final clients = snapshot.data!;

                  if (clients.isEmpty) {
                    return const Center(
                      child: Text(
                        'No clients found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    );
                  }

                  final filteredClients = _searchQuery.isEmpty
                      ? clients
                      : clients.where((client) {
                    return client.name.toLowerCase().contains(_searchQuery) ||
                        client.phone.toLowerCase().contains(_searchQuery) ||
                        (client.email?.toLowerCase().contains(_searchQuery) ?? false);
                  }).toList();

                  if (filteredClients.isEmpty) {
                    return const Center(
                      child: Text(
                        'No matching clients found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = filteredClients[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                          title: Text(client.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(client.phone),
                              if (client.email != null) Text(client.email!),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditClientDialog(client),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteClient(client),
                              ),
                            ],
                          ),
                          onTap: () => _showEditClientDialog(client),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ClientSearchDelegate extends SearchDelegate {
  final FirebaseService firebaseService;

  ClientSearchDelegate(this.firebaseService);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<Client>>(
      stream: firebaseService.getClients(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final clients = snapshot.data!;

        if (clients.isEmpty) {
          return const Center(
            child: Text(
              'No clients found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        final filteredClients = query.isEmpty
            ? clients
            : clients.where((client) {
          return client.name.toLowerCase().contains(query.toLowerCase()) ||
              client.phone.toLowerCase().contains(query.toLowerCase()) ||
              (client.email?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();

        if (filteredClients.isEmpty) {
          return const Center(
            child: Text(
              'No matching clients found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredClients.length,
          itemBuilder: (context, index) {
            final client = filteredClients[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
              title: Text(client.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.phone),
                  if (client.email != null) Text(client.email!),
                ],
              ),
              onTap: () {
                close(context, client);
              },
            );
          },
        );
      },
    );
  }
}

// Service Management Screen
class ServiceManagementScreen extends StatefulWidget {
  const ServiceManagementScreen({Key? key}) : super(key: key);

  @override
  State<ServiceManagementScreen> createState() => _ServiceManagementScreenState();
}

class _ServiceManagementScreenState extends State<ServiceManagementScreen> {
  late final FirebaseService firebaseService;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    firebaseService = FirebaseService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a service name';
    }
    if (value.length < 3) {
      return 'Service name must be at least 3 characters';
    }
    return null;
  }

  String? _validateDuration(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a duration';
    }
    final duration = int.tryParse(value);
    if (duration == null || duration <= 0) {
      return 'Please enter a valid duration in minutes';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a price';
    }
    final price = double.tryParse(value);
    if (price == null || price <= 0) {
      return 'Please enter a valid price';
    }
    return null;
  }

  void _showAddServiceDialog() {
    _nameController.clear();
    _descriptionController.clear();
    _durationController.clear();
    _priceController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Service'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateDuration,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validatePrice,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : () async {
              if (!_formKey.currentState!.validate()) {
                return;
              }

              setState(() {
                _isLoading = true;
              });

              try {
                final service = Service(
                  id: '',
                  name: _nameController.text,
                  description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
                  duration: int.parse(_durationController.text),
                  price: double.parse(_priceController.text),
                );

                await firebaseService.addService(service);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding service: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditServiceDialog(Service service) {
    _nameController.text = service.name;
    _descriptionController.text = service.description ?? '';
    _durationController.text = service.duration.toString();
    _priceController.text = service.price.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Service'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validateDuration,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    border: OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validatePrice,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : () async {
              if (!_formKey.currentState!.validate()) {
                return;
              }

              setState(() {
                _isLoading = true;
              });

              try {
                final updatedService = Service(
                  id: service.id,
                  name: _nameController.text,
                  description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
                  duration: int.parse(_durationController.text),
                  price: double.parse(_priceController.text),
                );

                await firebaseService.updateService(service.id, updatedService);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating service: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(Service service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Are you sure you want to delete ${service.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await firebaseService.deleteService(service.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting service: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Management'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Service>>(
          stream: firebaseService.getServices(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final services = snapshot.data!;

            if (services.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.spa_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No services found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddServiceDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Service'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (service.description != null)
                          Text(service.description!),
                        const SizedBox(height: 4),
                        Text(
                          'Duration: ${service.duration} minutes • Price: \$${service.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditServiceDialog(service),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteService(service),
                        ),
                      ],
                    ),
                    onTap: () => _showEditServiceDialog(service),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddServiceDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}