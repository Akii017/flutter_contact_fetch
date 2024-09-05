import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database/db_helper.dart'; // Import the DB helper

void main() {
  runApp(EmergencyContactsApp());
}

class EmergencyContactsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ContactsPage(),
    );
  }
}

class ContactsPage extends StatefulWidget {
  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, dynamic>> storedContacts =
      []; // All contacts from the database
  List<Map<String, dynamic>> emergencyContacts =
      []; // Stored emergency contacts
  DBHelper dbHelper = DBHelper();
  bool permissionGranted = false; // Permission status flag
  bool loading = true; // Loading indicator for fetching contacts

  @override
  void initState() {
    super.initState();
    _getContactsPermission();
  }

  // Request contacts permission and fetch contacts
  Future<void> _getContactsPermission() async {
    PermissionStatus permission = await Permission.contacts.status;

    if (permission == PermissionStatus.granted) {
      setState(() {
        permissionGranted = true;
      });
      await _checkAndStoreInitialContacts(); // Fetch and store initial contacts
      _loadStoredContacts(); // Load already stored contacts
      _loadEmergencyContacts(); // Load already selected emergency contacts
    } else if (permission == PermissionStatus.denied) {
      PermissionStatus newPermission = await Permission.contacts.request();
      if (newPermission == PermissionStatus.granted) {
        setState(() {
          permissionGranted = true;
        });
        await _checkAndStoreInitialContacts();
        _loadStoredContacts();
        _loadEmergencyContacts();
      } else {
        setState(() {
          permissionGranted = false;
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Contacts permission is denied."),
          ),
        );
      }
    } else if (permission == PermissionStatus.permanentlyDenied) {
      setState(() {
        permissionGranted = false;
        loading = false;
      });
      openAppSettings(); // Open settings if permission is permanently denied
    }
  }

  // Fetch contacts from the phone and store them in the database if not already stored
  Future<void> _checkAndStoreInitialContacts() async {
    var storedContacts = await dbHelper.getStoredContacts();
    if (storedContacts.isEmpty) {
      Iterable<Contact> contacts = await ContactsService.getContacts();
      await dbHelper.insertInitialContacts(contacts.toList());
    }
  }

  // Load stored contacts from the database
  Future<void> _loadStoredContacts() async {
    storedContacts = await dbHelper.getStoredContacts();
    setState(() {
      loading = false;
    });
  }

  // Load saved emergency contacts from the database
  Future<void> _loadEmergencyContacts() async {
    emergencyContacts = await dbHelper.getEmergencyContacts();
    setState(() {});
  }

  // Toggle contact selection to add/remove as emergency contact
  void toggleEmergencyContact(Map<String, dynamic> contact) async {
    bool isSelected = emergencyContacts
        .any((c) => c['phoneNumber'] == contact['phoneNumber']);

    if (isSelected) {
      await dbHelper.deleteEmergencyContact(contact['phoneNumber']);
    } else {
      Contact emergencyContact = Contact(
        displayName: contact['displayName'],
        phones: [Item(label: 'mobile', value: contact['phoneNumber'])],
      );
      await dbHelper.insertEmergencyContact(emergencyContact);
    }

    _loadEmergencyContacts();
  }

  // Show a dialog with the list of emergency contacts
  void showEmergencyContacts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Emergency Contacts"),
        content: emergencyContacts.isEmpty
            ? Text("No emergency contacts selected.")
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: emergencyContacts
                    .map(
                      (contact) => ListTile(
                        title: Text(contact['displayName']),
                        subtitle: Text(contact['phoneNumber']),
                      ),
                    )
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Emergency Contacts'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed:
                showEmergencyContacts, // Show the emergency contacts when clicked
          ),
        ],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator()) // Show loading spinner
          : permissionGranted
              ? storedContacts.isEmpty
                  ? Center(
                      child: Text("No contacts available")) // If no contacts
                  : ListView.builder(
                      itemCount: storedContacts.length,
                      itemBuilder: (context, index) {
                        var contact = storedContacts[index];
                        bool isSelected = emergencyContacts.any(
                            (c) => c['phoneNumber'] == contact['phoneNumber']);

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(contact['displayName'][0]),
                          ),
                          title: Text(contact['displayName'] ?? ""),
                          subtitle:
                              Text(contact['phoneNumber'] ?? 'No phone number'),
                          trailing: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: isSelected ? Colors.green : null,
                          ),
                          onTap: () => toggleEmergencyContact(contact),
                        );
                      },
                    )
              : Center(
                  child: Text(
                    "Contacts permission is required to fetch contacts.",
                    textAlign: TextAlign.center,
                  ),
                ),
    );
  }
}
