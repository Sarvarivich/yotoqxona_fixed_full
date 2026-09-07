import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BildirishnomalarList extends StatelessWidget {
  final String userId;
  final String hostel;

  const BildirishnomalarList({
    super.key,
    required this.userId,
    required this.hostel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bildirishnomalar"),
        backgroundColor: Colors.blue.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bildirishnomalar')
            .where('hostel', isEqualTo: hostel)
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text("Xatolik: ${snapshot.error}"),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var notifications = snapshot.data!.docs.toList();
          notifications.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Bildirishnomalar yo'q",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Yangi bildirishnomalar kelganda bu yerda ko'rinadi",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notification =
                  notifications[index].data() as Map<String, dynamic>;
              bool isRead = notification['isRead'] == true;

              return Dismissible(
                key: Key(notifications[index].id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  await FirebaseFirestore.instance
                      .collection('bildirishnomalar')
                      .doc(notifications[index].id)
                      .delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Bildirishnoma o'chirildi")),
                  );
                },
                child: Card(
                  elevation: isRead ? 1 : 3,
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isRead ? Colors.grey.shade50 : Colors.white,
                  child: InkWell(
                    onTap: () async {
                      if (!isRead) {
                        await FirebaseFirestore.instance
                            .collection('bildirishnomalar')
                            .doc(notifications[index].id)
                            .update({'isRead': true});
                      }
                      _showNotificationDialog(context, notification);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.grey.shade200
                              : Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          notification['type'] == 'payment' ||
                                  notification['type'] == 'new_payment_check' ||
                                  notification['type'] == 'payment_check_result'
                              ? Icons.payment
                              : notification['type'] == 'complaint'
                                  ? Icons.report_problem
                                  : Icons.notifications_active,
                          color: isRead ? Colors.grey : Colors.blue.shade700,
                        ),
                      ),
                      title: Text(
                        notification['title'],
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['body'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDate(
                                ((notification['createdAt'] as Timestamp?)
                                        ?.toDate()) ??
                                    DateTime.now()),
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: !isRead
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return "${date.day}.${date.month}.${date.year}";
    } else if (difference.inDays > 0) {
      return "${difference.inDays} kun oldin";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} soat oldin";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minut oldin";
    } else {
      return "Hozirgina";
    }
  }

  void _showNotificationDialog(
      BuildContext context, Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blue.shade700),
            SizedBox(width: 8),
            Expanded(child: Text(notification['title'])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['body'],
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              _formatDate(
                  ((notification['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now())),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Yopish"),
          ),
        ],
      ),
    );
  }
}
